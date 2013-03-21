%% Author: xianrongMai
%% Created: 2011-11-28
%% Description:	神魔乱斗相关逻辑处理
-module(lib_warfare).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("guild_info.hrl").
-include("battle.hrl").

%%
%% Exported Functions
%%
-export([
		 check_save_warfare_award/2,	%% 玩家下线，判断是否需要保存数据(获取的绑定铜的数据)
		 send_warfare_award_self/2,		%% 进入神魔乱斗场景时向客户端发送当前已经获取的绑定铜数值
		 get_warfare_award_self/1,		%% 获取当前已经拿到的绑定铜数量
		 update_warfare_award_self/1,	%% 更新当前拿到的绑定铜数值
		 notice_be_kill/2,				%% 通知被杀死了
		 pluto_award_mail/1,			%% 得到冥王之灵的玩家将会收到一封奖励的信件
		 check_warfare_time/1,			%% 检查是否需要启动神魔乱斗
		 get_mon_xy/1,					%% 获取怪物出生坐标
		 get_plutos_owns/1,				%% 获取 冥王之灵的图标显示
		 give_warfare_award/2,			%% 判断需要加多少的经验和灵力
		 warfare_award/1,				%% 给在神魔乱斗场景上的玩家发经验和灵力奖励
		 notice_winner_pluto/4,			%% 通知怪物控制器处理冥王之灵的交换逻辑
		 mon_loading/3,					%% 怪物空降
		 make_new_moninfo/2,			%% 神魔乱斗的怪物，需要重新计算一下血量和攻击
		 broadcast_warfare_time/1,		%% 对神魔乱斗做最后N秒钟的倒计时纠正
		 check_send_warfare_icon/2,		%% 检查是否需要向客户端推神魔乱斗的倒计时图标
		 get_warfare_time/0,			%% 神魔乱斗时间time
		 start_warfare_mon/2,			%% 检查是否需要开启神魔乱斗的怪物控制器
		 get_mon_warfare/0,				%% 获取最新的神魔乱斗中怪物的血量和攻击增量级数
		 mon_bekill_broadcast/1,		%% 怪物死亡的时候广播
		 mon_refresh_broadcast/1,		%% 怪物刷新的时候广播
		 warfare_add_expspri/3,			%% 玩家进程调用的添加经验和灵力
		 count_player_gain/6,			%% 计算在神魔乱战的时候砍怪获得的经验和灵力
		 scene_broadcast/2,				%% 神魔乱斗的场景广播
		 world_brodcast/2,				%% 神魔乱斗的世界播报
		 fight_get_expspri/2			%%   获取玩家每砍一刀怪物时，获得的经验值和灵力值
		]).

%%
%% API Functions
%%

%% ===============================================================================================================
%% ===============================================================================================================

%%检查是否需要启动神魔乱斗
check_warfare_time(NowSec) ->
	%%判断今天星期几
	Date = util:get_date(),
	IdDate = is_warfare_date(Date),
	{SWarfare, EWarfare} = get_warfare_time(),
	IdDate andalso SWarfare =< NowSec andalso NowSec =< EWarfare.%%延后300秒的时间

%%神魔乱斗时间time
get_warfare_time() ->
	{20*3600+35*60, 21*3600+35*60}.	%%正确的时间，谨慎修改，测试请用以下代码
	
%%========测试用代码=====
%% 	{19*3600+35*60, 21*3600+20*60}.

%%神魔乱斗日期date
is_warfare_date(Date) ->
	lists:member(Date, [2, 5, 7]).	%%正确的时间，谨慎修改，测试请用以下代码

%%========测试用代码=====
%% 	lists:member(Date, [1,2,3,4,5,6,7]).

%% ===============================================================================================================
%% ===============================================================================================================

%% 检查是否需要开启神魔乱斗的怪物控制器
start_warfare_mon(Warfare, NowSec) ->
	%%检查是否需要启动神魔乱斗
	%%判断今天星期几
	Date = util:get_date(),
	IdDate = is_warfare_date(Date),
	{SWarfare, EWarfare} = get_warfare_time(),
	IsTime = IdDate andalso SWarfare =< NowSec andalso NowSec =< EWarfare+ 300,%%延后300秒的时间
%% 	?DEBUG("IsTime:~p", [IsTime]),
	case Warfare of
		0 ->%%目前没开进程
			case IsTime of
				true ->%%是时间要开啰喔
					ScenePid = mod_scene:get_scene_pid(?WARFARE_SCENE_ID, undefined, undefined),
					%%启动控制器
%% 					?DEBUG("start the warfare mon", []),
					gen_server:cast(ScenePid, {apply_cast, mod_warfare_mon, init_warfare_mon, []}),
%% 					gen_server:cast(ScenePid, {'INIT_WARFARE_MON'}),
					1;
				false ->
					Warfare
			end;
		_ ->
			case IsTime of
				true ->%%当前已经开了耶
					Warfare;
				false ->%%过时间了，结束吧，恢复原来的状态
					0
			end
	end.

%%检查是否需要向客户端推神魔乱斗的倒计时图标
check_send_warfare_icon(Lv, PidSend) ->
	case Lv >= 37 of
		true ->
	NowSec = util:get_today_current_second(),
	%%检查是否需要启动神魔乱斗
	IsTime = check_warfare_time(NowSec),
%% 	?DEBUG("IsTime:~p", [IsTime]),
	case IsTime of
		true ->
			%%神魔乱斗时间time
			{_Start, End} = lib_warfare:get_warfare_time(),
			Diff = End - NowSec-10,%%多减去10秒
%% 			?DEBUG("Diff:~p", [Diff]),
			case Diff > 0 of
				false ->
					skip;
				true ->
					{ok, BinData39101} = pt_39:write(39101, [Diff]),
					lib_send:send_to_sid(PidSend, BinData39101)
			end;
		false ->
			skip
	end;
		false ->
			skip
	end.
%%对神魔乱斗做最后N秒钟的倒计时纠正
broadcast_warfare_time(Time) ->
%% 	?DEBUG("broadcast_warfare_time", []),
	{ok, BinData39101} = pt_39:write(39101, [Time]),
	lib_send:send_to_all(BinData39101).

%%神魔乱斗的怪物，需要重新计算一下血量和攻击
make_new_moninfo(MinfoBase, OtherBase) ->
	[Add, Lv] = OtherBase,
	MonId = MinfoBase#ets_mon.mid,
	if
		%%如果所有地穴编织者被击杀完毕，时间不超过3分钟，则下次怪物刷新时，血量上限增加20000，攻击增加200
		MonId =:= 43101 orelse MonId =:= 43102 orelse MonId =:= 43103 ->
			AddHp = erlang:trunc(10000 * Add),
			AddAtt = erlang:trunc(50 * Add),
%% 			?DEBUG("MonHp:~p, hp_lim:~p, AddHp:~p, AddAtt:~p, Add:~p", [MinfoBase#ets_mon.hp_lim+AddHp, MinfoBase#ets_mon.hp_lim, AddHp, AddAtt, Add]),
			MinfoBase#ets_mon{lv = Lv,
							  hp_lim = MinfoBase#ets_mon.hp_lim+AddHp-30000,
							  hp = MinfoBase#ets_mon.hp_lim + AddHp-30000,
							  max_attack = MinfoBase#ets_mon.max_attack+AddAtt-100,
							  min_attack = MinfoBase#ets_mon.min_attack+AddAtt-50};
		%%如果路西法被击杀，时间不超过5分钟，则下次怪物刷新时，血量上限增加50000，攻击增加500
		MonId =:= 43104 orelse MonId =:= 43105 ->
			AddHp = erlang:trunc(?BOSS_ADD_HP * Add),
			AddAtt = erlang:trunc(?BOSS_ADD_ATT * Add),
%% 			?DEBUG("MonHp:~p, hp_lim:~p, AddHp:~p, AddAtt:~p, Add:~p", [MinfoBase#ets_mon.hp_lim+AddHp, MinfoBase#ets_mon.hp_lim, AddHp, AddAtt, Add]),
			MinfoBase#ets_mon{lv = Lv,
							  hp_lim = MinfoBase#ets_mon.hp_lim+AddHp,
							  hp = MinfoBase#ets_mon.hp_lim + AddHp,
							  max_attack = MinfoBase#ets_mon.max_attack+AddAtt-800,
							  min_attack = MinfoBase#ets_mon.min_attack+AddAtt-500};
		true ->
			MinfoBase
	end.

%%怪物空降
mon_loading({MonId, RNum}, MonAdd, MaxLv) ->
	ScenePid = mod_scene:get_scene_pid(?WARFARE_SCENE_ID, undefined, undefined),
	Lv = get_monlv(MonId, MaxLv),%%获取怪物的等级
	gen_server:cast(ScenePid, {apply_cast, 
							   lib_scene, 
							   loading_warfare_mon, 
							   [RNum, MonId, MonAdd, Lv, ?WARFARE_SCENE_ID]}).
%% 	lib_scene:loading_warfare_mon(RNum, MonId, ?WARFARE_SCENE_ID, MonAdd).
	
%%获取怪物的等级
get_monlv(MonId, MaxLv) ->
	if
		MonId =:= 43101  ->
			MaxLv + 2;
		MonId =:= 43102 ->
			MaxLv + 4;
		MonId =:= 43103 ->
			MaxLv + 6;
		MonId =:= 43104 ->
			MaxLv + 8;
		MonId =:= 43105 ->
			MaxLv + 10;
		true ->
			MaxLv
	end.
			
%% 获取玩家每砍一刀怪物时，获得的经验值和灵力值
%% return -> {Exp, Spri}
fight_get_expspri(Type, FightNum) ->
	{ExpBase, SpriBase} =
		case Type of
			38 ->%%小怪
				{0.5, 1};
			39 ->%%boss
				{0.5, 1}
		end,
	Exp = erlang:trunc(ExpBase * FightNum),
	Spri = erlang:trunc(SpriBase * FightNum),
	{Exp, Spri}.

%%怪物刷新的时候广播
mon_refresh_broadcast(MonId) ->
	if
		MonId =:= 43101 orelse MonId =:= 43102 orelse MonId =:= 43103 ->
			Param = {MonId},
			scene_broadcast(2, Param);
		MonId =:= 43104 ->
			world_brodcast(1, undefined);
		MonId =:= 43105 ->
			world_brodcast(2, undefined);
		true ->
			skip
	end.
%%怪物死亡的时候广播
mon_bekill_broadcast(MonId) ->
	if
		MonId =:= 43101 orelse MonId =:= 43102 orelse MonId =:= 43103 ->
			Param = {MonId},
			scene_broadcast(1, Param);
		MonId =:= 43104 ->
			scene_broadcast(3, undefined);
		MonId =:= 43105 ->
			scene_broadcast(6, undefined);
		true ->
			skip
	end.
	

%% 神魔乱斗的世界播报
world_brodcast(Type, Param) ->
	Content = 
		case Type of
			1 -> %% 路西法刷新时播报
				spawn(fun()->timer:apply_after(5000, lib_warfare, scene_broadcast,[10, undefined]) end),%%5秒之后，做一次场景的广播
				"魔物统领 <font color='#FFFFFF'>路西法</font> 已经降临，请前往剿杀！";
			2 -> %% 哈迪斯刷新时播报
				spawn(fun()->timer:apply_after(5000, lib_warfare, scene_broadcast,[5, undefined]) end),%%5秒之后，做一次场景的广播
				"大魔王  <font color='#FFFFFF'>哈迪斯</font> 出现了！英雄们，拿起你们的武器，把它赶出远古大陆！";
			3 -> %% 冥王之灵 丢落 播报
				Members = control_members("", Param),
				io_lib:format("~s获得了冥王之灵，死亡后转移，5分钟后持有冥王之灵的角色将获得 等级×50000 的灵力、高额经验及神魔乱斗礼包等巨量奖励，角色所在氏族也能获得高额奖励。",[Members]);
			4 -> %% 冥王之灵 分配 播报
				case Param of
					[] ->
						"很遗憾，本次无人能掌控冥王之灵，请下次再接再厉！";
					_ ->
						Members = control_members("", Param),
						io_lib:format("恭喜~s，获得了冥王之灵的最终掌控权！获得巨量奖励！", [Members])
				end;
			7 ->%%持有冥王之灵的角色被击杀后，冥王之灵转移到击杀者身上，并播报：xx氏族的xxx 击败了 xx氏族的xxx ，获得了冥王之灵的掌控权！
				{KGid, KGName, KPName, BKGid, BKGName, BKPName} = Param,
				One = 
					case KGid of
						0 ->
							io_lib:format("<font color='#FEDB4F'>~s</font>击败了", [KPName]);
						_ ->
							io_lib:format("<font color='#FFFFFF'>~s</font>氏族的<font color='#FEDB4F'>~s</font>击败了", [KGName, KPName])
					end,
				case BKGid of
					0 ->
						io_lib:format("~s<font color='#FFFFFF'>~s</font>，获得了冥王之灵的掌控权！", [One, BKPName]);
					_ ->
						io_lib:format("~s<font color='#FFFFFF'>~s</font>氏族的<font color='#FEDB4F'>~s</font>，获得了冥王之灵的掌控权！", [One, BKGName, BKPName])
					end;
			8 ->%%持有冥王之灵的玩家掉线或者刷新时，冥王之灵随机转移到场景内参与了BOSS击杀的玩家身上，并播报：xx氏族的xxx获得了冥王之灵的掌控权！
				{Gid, GName, PName} = Param,
				case Gid of
					0 ->
						io_lib:format("<font color='#FEDB4F'>~s</font>获得了冥王之灵的掌控权！", [PName]);
					_ ->
						io_lib:format("<font color='#FFFFFF'>~s</font>氏族的<font color='#FEDB4F'>~s</font>获得了冥王之灵的掌控权！", [GName, PName])
				end;
			9 ->%%持有冥王之灵的角色被击杀后，冥王之灵转移到击杀者身上，并播报：xx氏族的xxx 击败了 xx氏族的xxx ，xxx丢失了冥王之灵的掌控权！
				{KGid, KGName, KPName, BKGid, BKGName, BKPName} = Param,
				One = 
					case KGid of
						0 ->
							io_lib:format("<font color='#FEDB4F'>~s</font>击败了", [KPName]);
						_ ->
							io_lib:format("<font color='#FFFFFF'>~s</font>氏族的<font color='#FEDB4F'>~s</font>击败了", [KGName, KPName])
					end,
				case BKGid of
					0 ->
						io_lib:format("~s<font color='#FEDB4F'>~s</font>，<font color='#FEDB4F'>~s</font>丢失了冥王之灵的掌控权！", [One, BKPName, BKPName]);
					_ ->
						io_lib:format("~s<font color='#FFFFFF'>~s</font>氏族的<font color='#FEDB4F'>~s</font>，<font color='#FFFFFF'>~s</font>丢失了冥王之灵的掌控权！", 
									  [One, BKGName, BKPName, BKPName])
				end
		end,
	lib_chat:broadcast_sys_msg(2, Content).

%% 神魔乱斗的场景广播
scene_broadcast(Type, Param) ->
	Content = 
		case Type of
			1 ->%%当该次刷新的怪物全部被击杀完毕时将播报：当前 xxxxx（怪物名用白色字体） 已全部清除，60秒后下一波魔物即将入侵！
				{MonId} = Param,
				MonName = get_mon_name(MonId),
				io_lib:format("当前<font color='#FFFFFF'>~s</font>已全部清除，大量的财宝被发现！！60秒后下一波魔物即将入侵！", [MonName]);
			2 ->%%当刷新怪物时，播报：xxxxx（怪物名用白色字体）已浸入远古大陆，请前往剿杀！
				{MonId} = Param,
				MonName = get_mon_name(MonId),
				io_lib:format("<font color='#FFFFFF'>~s</font>已侵入远古大陆，请前往剿杀！", [MonName]);
			3 ->%%路西法死亡时喊话及屏幕显示：我居然输了。。。不过别高兴得太早，冥王会将你们通通杀掉的。。。
				spawn(fun()->timer:apply_after(10000, lib_warfare, scene_broadcast,[4, undefined]) end),%%5秒之后，做一次场景的广播
				"我居然输了...不过别高兴得太早,冥王会将你们通通杀掉的...";
			4 ->%%路西法死亡后10秒显示播报：冥王将在50秒后出现，请做好准备！
				"冥王将在50秒后出现,请做好准备！";
			5 ->%%哈迪斯出现5秒后喊话及屏幕显示：蝼蚁也敢忤逆冥王之威！你们这是自寻死路！
				"蝼蚁也敢忤逆冥王之威!你们这是自寻死路！";
			6 ->%%哈迪斯死亡时喊话及屏幕显示：我是不会放过你们这群蝼蚁的。。。等着我怒火再次降临吧。。。
				"我是不会放过你们这群蝼蚁的...等着我怒火再次降临吧...";
			10 ->%%路西法出现5秒后，头顶冒泡显示，并在屏幕中间显示（字体大小最好调整为1-2行可以显示完），显示5秒（下面无特殊说明，则显示时间默认为5秒）：卑微的爬虫们，我，魔神路西法，必将尔等斩尽杀绝！
				"卑微的爬虫们，我，魔神路西法，必将尔等斩尽杀绝！";
			_ ->
				""
		end,
	{ok, BinData39100} = pt_39:write(39100, [Type, Content]),
	spawn(fun() -> mod_scene_agent:send_to_scene(?WARFARE_SCENE_ID, BinData39100) end).



%% 计算在神魔乱战的时候砍怪获得的经验和灵力
count_player_gain(MonScene, MonType, PPid, PlayerId, PName, Hurt) ->
	case MonScene =:= ?WARFARE_SCENE_ID of
		false ->
			skip;
		true ->
			gen_server:cast(PPid, {'WARFARE_ADD_EXPSPRI', MonType, Hurt}),
			case mod_warfare_mon:get_warfare_mon() of
				{error} ->%%这次糟糕了，连进程都没了..
					skip;
				{ok, Warfare} ->%%发送伤害值统计
					Warfare ! {'UPDATE_PLAYER_ATTACK', PlayerId, PName, Hurt}
			end
	end.
%% 玩家进程调用的添加经验和灵力
warfare_add_expspri(Player, MonType, Hurt) ->
	%%获取经验和灵力数据
	{Exp, Spri} = fight_get_expspri(MonType, Hurt),
	%%加经验和灵力
	lib_player:add_exp(Player, Exp, Spri, 21).
		
%% 获取最新的神魔乱斗中怪物的血量和攻击增量级数
get_mon_warfare() ->
	case db_agent:get_mon_warfare() of
		[] ->
			[];
		List ->
			lists:foldl(fun(Elem, AccIn) ->
								[EMonId, EAdd] = Elem,
								case lists:keyfind(EMonId, 1, AccIn) of
									false ->
										[{EMonId, EAdd}|AccIn];
									{_FMonId, _FAdd} ->
										AccIn
								end
						end, [], List)
	end.

%%通知怪物控制器处理冥王之灵的交换逻辑
notice_winner_pluto(Player, Pid, AerId, AerName) ->
	case mod_warfare_mon:get_warfare_mon() of
		{error} ->%%这次糟糕了，连进程都没了..
			?WARNING_MSG("OMG!can not find the warfare mon process,DId:~p, AerId:~p, time:~p",[Player#player.id, AerId, util:unixtime()]),
			skip;
		{ok, Warfare} ->
			case AerId of
				0 ->
					?WARNING_MSG("OMG!the player id is zero when pluto changed, DId:~p, AerId:~p, time:~p",[Player#player.id, AerId, util:unixtime()]);
				_ ->
					%%通知怪物控制器，处理冥王之灵的交接
					gen_server:cast(Warfare, {'PLUTO_ADMIN_CHANGED', Player#player.id, Player#player.nickname, 
											  Player#player.guild_name, Player#player.guild_id, Pid, AerId, AerName})
			end
	end.
%%
%% Local Functions
%%
control_members(Content, []) ->
	Content;
control_members(Content, [{Gid, GName, PlayerId, PlayerName, Career, Sex}|Rest]) ->
	case Gid of
		0 ->
			case Rest of
				[] ->
					Text = io_lib:format("[<a href='event:1,~p,~p,~p,~p'><font color='#FEDB4F'>~s</font></a>]", [PlayerId, PlayerName, Career, Sex, PlayerName]),
					Elem = Content ++ Text;
				_R ->
					Text = io_lib:format("[<a href='event:1,~p,~p,~p,~p'><font color='#FEDB4F'>~s</font></a>]、", [PlayerId, PlayerName, Career, Sex, PlayerName]),
					Elem = Content ++ Text
			end;
		_ ->
			case Rest of
				[] ->
					Text = io_lib:format("<font color='#FFFFFF'>~s</font>氏族的[<a href='event:1,~p,~s,~p,~p'><font color='#FEDB4F'>~s</font></a>]", 
										 [GName, PlayerId, PlayerName, Career, Sex, PlayerName]),
					Elem = Content ++ Text;
				_R ->
					Text = io_lib:format("<font color='#FFFFFF'>~s</font>氏族的[<a href='event:1,~p,~s,~p,~p'><font color='#FEDB4F'>~s</font></a>]、", 
					[GName, PlayerId, PlayerName, Career, Sex, PlayerName]),
					Elem = Content ++ Text
			end
	end,
	control_members(Elem, Rest).
	
%%获取怪物的名字
get_mon_name(MonId) ->
	case MonId of
		43101 ->
			"地穴编织者";
		43102 ->
			"吸血女妖";
		43103 ->
			"冥巫";
		43104 ->
			"路西法";
		43105 ->
			"哈迪斯"
	end.


%%给在神魔乱斗场景上的玩家发经验和灵力奖励	
warfare_award(SGInfo) ->
	mod_scene_agent:send_to_scene_for_event(?WARFARE_SCENE_ID, {'WARFARE_AWARD', SGInfo}).

%%判断需要加多少的经验和灵力
give_warfare_award(SGInfo, Player) ->
	#player{id = PlayerId, 
			guild_id = Gid,
			lv = Lv} = Player,
	%%计算经验和灵力
	{AddExp, AddSpri} = get_add_award(SGInfo, PlayerId, Gid, Lv, {0, 0}),
	%%加经验和灵力
	case AddExp of
		0 ->
			NewPlayer = Player;
		_ ->
			NewPlayer = lib_player:add_exp(Player, AddExp, AddSpri, 21)
	end,
	case Player#player.carry_mark of
		27 ->
			NewPlayer1 = NewPlayer#player{carry_mark = 0},
			%% 通知客户端更新玩家属性
			{ok, BinData12041} = pt_12:write(12041, [Player#player.id, 0]),
			mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData12041),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12041),
			NPlayer = lib_player:count_player_attribute(NewPlayer1),
			mod_player:save_online_diff(Player,NPlayer),
			NPlayer;
		_ ->
			mod_player:save_online_diff(Player,NewPlayer),
			NewPlayer
	end.
	
%%计算经验和灵力
get_add_award([], _PlayerId, _Gid, _Lv, Result) ->
	Result;
get_add_award([Elem|SGInfo], PlayerId, Gid, Lv, Result) ->
	{EGid, EPList, {EAddExp, EAddSpri}} = Elem,
	case EGid =/= 0 of
		false ->%%这个没氏族的玩家
			case lists:member(PlayerId, EPList) of
				true ->%%有冥王之灵
					{AddExp, AddSpri} = {erlang:trunc(Lv * ?ADD_EXP), erlang:trunc(Lv * ?ADD_SPRI)},
					get_add_award([], PlayerId, Gid, Lv, {AddExp, AddSpri});
				false ->%%什么都没，继续遍历
					get_add_award(SGInfo, PlayerId, Gid, Lv, Result)
			end;
		true ->%%有氏族
			case EGid =:= Gid of
				true ->%%同一个氏族的
					case lists:member(PlayerId, EPList) of
						true ->%%有冥王之灵的，两个加成奖励
							{AddExp, AddSpri} = {erlang:trunc(Lv * ?ADD_EXP + EAddExp), erlang:trunc(Lv * ?ADD_SPRI + EAddSpri)},
							get_add_award([], PlayerId, Gid, Lv, {AddExp, AddSpri});
						false ->%%没有冥王之灵的，只有一个加成奖励
							get_add_award([], PlayerId, Gid, Lv, {EAddExp, EAddSpri})
					end;
				false ->%%不是同一个氏族，继续遍历
					get_add_award(SGInfo, PlayerId, Gid, Lv, Result)
			end
	end.

%%获取 冥王之灵的图标显示
get_plutos_owns(PidSend) ->
	NowSec = util:get_today_current_second(),
	%%检查是否需要启动神魔乱斗
	case check_warfare_time(NowSec) of
		true ->
			case mod_warfare_mon:get_warfare_mon() of
				{ok, Warfare} ->
					gen_server:cast(Warfare, {'PLAYER_ENTER_WARFARE', PidSend});
				_ ->
					skip
			end;
		false ->
			skip
	end.

%%获取怪物出生坐标
get_mon_xy(MonId) ->
	if
		MonId =:= 43101 orelse MonId =:= 43102 orelse MonId =:= 43103 ->%%小怪
			X = util:rand(2, 35),
			Y = util:rand(15, 66),
			[X,Y];
		true ->%%boss
			[20, 34]
	end.

%%得到冥王之灵的玩家将会收到一封奖励的信件
pluto_award_mail(PName) ->
	NameList = [PName],
	Title = "冥王之灵奖励",
	Content = "您抢夺到了冥王之灵，获得最终奖励！",
	GoodsTypeId = 31051,
	mod_mail:send_sys_mail(NameList, Title, Content, 0, GoodsTypeId, 1, 0, 0).
	
	
%%通知被杀死了
notice_be_kill(Player, NickName) ->
	%% 通知玩家
	{ok, BinData39106} = pt_39:write(39106, [NickName]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData39106).

%% 进入神魔乱斗场景时向客户端发送当前已经获取的绑定铜数值
send_warfare_award_self(Pid, PidSend) ->
	Award = get_warfare_award_self(Pid),
	%% 通知玩家
	{ok, BinData39111} = pt_39:write(39111, [1, Award]),
	lib_send:send_to_sid(PidSend, BinData39111).

%% 获取当前已经拿到的绑定铜数量
get_warfare_award_self(Pid) ->
	Now = util:unixtime(),
	case get(bcoin_award) of
		undefined ->
%% 			?DEBUG("get bcoin award undefined", []),
			case db_agent:get_warfare_award(Pid) of
%% case 1234 of
				[LTime, Award] ->
					{SWarfare, EWarfare} = get_warfare_time(),
					Diff = abs(Now - LTime) =< abs(EWarfare - SWarfare)+120,
%% 					?DEBUG("get old bcoin award LTime:~p, Now:~p, Diff:~p, Num:~p", [LTime, Now, Diff, Award]),
					case Diff of
						true ->
							put(bcoin_award, {LTime, Award}),
							Award;
						false ->
							put(bcoin_award, {Now, 0}),
							0
					end;
				_ ->
					put(bcoin_award, {Now, 0}),
					0
			end;
		{LTime, Num} ->
			{SWarfare, EWarfare} = get_warfare_time(),
			Diff = abs(Now - LTime) =< abs(EWarfare - SWarfare)+120,
%% 			?DEBUG("get bcoin award LTime:~p, Now:~p, Diff:~p, Num:~p", [LTime, Now, Diff, Num]),
			case Diff of
				true ->
					Num;
				false ->%%这里是当天的第一次进入神魔乱斗场景,做一次标注
					put(bcoin_award, {Now, 0}),
					0
			end;
		_E ->
%% 			?DEBUG("get Other Error :~p", [_E]),
			put(bcoin_award, {Now, 0}),
			0
	end.

%% 更新当前拿到的绑定铜数值
update_warfare_award_self(Add) ->
	Now = util:unixtime(),
	case get(bcoin_award) of
		undefined ->
%% 			?DEBUG("put bcoin award undefined,Add:~p", [Add]),
			put(bcoin_award, {Now, Add});
		{LTime, Num} ->
			{SWarfare, EWarfare} = get_warfare_time(),
			Diff = abs(Now - LTime) =< abs(EWarfare - SWarfare),
%% 			?DEBUG("put bcoin award LTime:~p, Now:~p, Diff:~p,Add:~p", [LTime, Now, Diff, Add]),
			case Diff of
				true ->
					NNum = Num + Add,
					put(bcoin_award, {Now, NNum});
				false ->
					put(bcoin_award, {Now, Add})
			end;
		_E ->
%% 			?DEBUG("put Other Error :~p,Add:~p", [_E, Add]),
			put(bcoin_award, {Now, Add})
	end.

%%玩家下线，判断是否需要保存数据
check_save_warfare_award(Pid, NowTime) ->
	%%检查是否需要启动神魔乱斗
	%%判断今天星期几
	Date = util:get_date(),
	IdDate = is_warfare_date(Date),
	{SWarfare, EWarfare} = get_warfare_time(),
	NowSec = util:get_today_current_second(),
	case IdDate andalso SWarfare < NowSec andalso NowSec =< EWarfare of
		true ->%%居然是这个时间
			case get(bcoin_award) of
				undefined ->
					skip;
				{LTime, Num} ->
					case Num =< 0 of
						true ->
							skip;
						false ->
							case util:is_same_date(LTime, NowTime) of
								true ->
									case db_agent:get_warfare_award(Pid) of
										[_LTime, _Award] ->
											db_agent:update_warfare_award(Pid, LTime, Num);
										[] ->
											db_agent:insert_warfare_award(Pid, LTime, Num)
									end;
								false ->
									skip
							end
					end;
				_ ->
					skip
			end;
		false ->
			skip
	end.


			