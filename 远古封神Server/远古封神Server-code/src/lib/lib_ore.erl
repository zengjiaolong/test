%% Author: zj
%% Created: 2011-3-1
%% Description: ore lib
-module(lib_ore).
-include("common.hrl").
-include("record.hrl").
-define(LEVEL_LIMIT,30).
%%
%% Include files
%%

%%
%% Exported Functions
%%
-export([
		 check_ore_dig_request/0,
		 check_ore_dig_limit/1,
		 check_ratio/1,
		 broadcast_msg/2,
		 make_ore_id/3,
		 enter_scene_ore_display/1,
		 is_ore_time/0,
		 in_ore_area/3,
		 do_logout/1,
		 cancel_ore_status/1,
		 get_ore_scene/0,
		 get_scene_name/1,
		 cancel_timer/0,
		 get_limit/0,
		 broadcast_goods_info/3
		 ]).

%%
%% API Functions
%%
%%验证请求条件
check_ore_dig_request() ->
	Now = util:unixtime(),
	case get(ore_dig_request) of
		undefined ->
			put(ore_dig_request,Now),
			true;
		Time ->
			put(ore_dig_request,Now),
			case Now - Time >= 30  of
				true ->
					true;
				false ->
					false
			end
	end.

%%验证状态改变条件
check_ore_dig_limit(Player) ->
	%%NowSec = util:get_today_current_second(),
	IsOreTime = is_ore_time(),
	InOreArea = in_ore_area(Player#player.scene,Player#player.x,Player#player.y),
	if
		Player#player.lv < ?ORE_LEVEL_LIMIT ->
			2 ;%%等级不够
		IsOreTime == false ->
			3;%%不在活动时间
		InOreArea == false ->
			4;%%位置错误
		Player#player.status == 2 ->
			5;%%战斗状态不能参加此活动
		Player#player.status == 5 ->
			6;%%挂机状态不能参加此活动
		Player#player.status == 7 ->
			7;%%凝神状态不能参加此活动
		Player#player.status == 4 ->
			8;%%蓝名状态不能参加此活动
		true ->
			true
	end.

%%挖矿是否成功
check_ratio(Player) ->
	RAND = util:rand(1,10000),
	case get(ore_first_time) of
		true ->
			true;
		undefined ->			
			%%?DEBUG("_____________________Rand:~p",[RAND]),
			if
				Player#player.lv < 35 ->
					if
						?ORE_RATIO_35_DOWN * 100 > RAND  ->
							true;
						true ->
							false
					end;
				Player#player.lv >= 35 ->
					if
						?ORE_RATIO_35_UP * 100 > RAND  ->
							true;
						true ->
							false
					end
			end
	end.

%%广播
broadcast_goods_info(Nickname,Goods_id,Pidsend) ->
	Is_member = lists:member(Goods_id, [26000,26001,26002,26003,26004]),
	GoodsInfo = goods_util:get_goods_type(Goods_id),
	GoodsName = GoodsInfo#ets_base_goods.goods_name,
	Color = goods_util:get_color_hex_value(GoodsInfo#ets_base_goods.color),
	if
		Is_member ->
			lib_ore:broadcast_msg(5,[GoodsName,Pidsend]);
		true ->			
			lib_ore:broadcast_msg(3,[Nickname,Goods_id,GoodsName,Color])
	end.
		
%%天降彩石活动相关广播			
broadcast_msg(Type,Value) ->
	case Type of
		1 ->
			Msg = io_lib:format("各位玩家注意 <font color='#FEDB4F'>天降彩石</font>活动将于<font color='#FEDB4F'> ~p </font>分钟后开始，请注意参加。",[Value]),
			lib_chat:broadcast_sys_msg(2, Msg);
		2 ->
			Msg = io_lib:format("天降彩石活动开始了！赶快寻找降落地点，为了宝石奋斗吧！",[]),
			lib_chat:broadcast_sys_msg(2, Msg);
		3 ->
			[Nickname,Goods_id,GoodsName,Color] = Value,
			Realm = 
				case db_agent:get_realm_by_nick(Nickname) of
					null ->
						100;
					R -> 
						R   %%未离婚
				end,
			NameColor = data_agent:get_realm_color(Realm),
			Msg = io_lib:format("玩家<font color='~s'>~s</font>在天降彩石活动中人品大爆发，采到了  <a href='event:2,~p,0,1'><font color='~s'><u>~s</u></font></a> 矿石",[NameColor,Nickname,Goods_id,Color,GoodsName]),
			lib_chat:broadcast_sys_msg(2, Msg);
		4 ->
			Msg = io_lib:format("天降彩石活动已结束。",[]),
			lib_chat:broadcast_sys_msg(2, Msg);
		5 ->
			[GoodsName,Pidsend] = Value ,
			Msg= io_lib:format("您获得<font color='#FEDB4F'>~s</font>",[GoodsName]),
			{ok,Bin} = pt_15:write(15055,[Msg]),
			lib_send:send_to_sid(Pidsend,Bin);
		6 ->[SceneID] = Value,
			SceneName = get_scene_name(SceneID),
			Msg = io_lib:format("彩石降落在<font color='#FEDB4F'>~s</font>地区，大家快去寻找彩石踪迹吧！",[SceneName]),
			lib_chat:broadcast_sys_msg(2, Msg);
		_ ->
			skip
	end.

%%获取场景名称
get_scene_name(SceneID) ->
	BaseSceneInfo = data_scene:get(SceneID),
	BaseSceneInfo#ets_scene.name.

%%进入场景
enter_scene_ore_display(Player) ->
	Is_ore_time = is_ore_time(),
	if
		Is_ore_time == true ->
			case mod_ore_sup:get_mod_ore_pid() of
				Pid when is_pid(Pid) ->
					gen_server:cast(Pid,{'enter_scene_ore_display',Player#player.scene,Player#player.other#player_other.pid_send});
				true ->
					skip
			end;
		true ->
			skip
	end.
%%
%%生成矿点ID
make_ore_id(Scene,X,Y) ->
	list_to_integer(lists:concat([Scene,X,Y])).


%%是否采矿时间 [标准时间]return true /false
is_ore_time() ->
	NowSec = util:get_today_current_second(),
	NowSec >= ?ORE_START_TIME andalso NowSec =< ?ORE_END_TIME .


%%是否在采矿点附近
in_ore_area(Scene,X,Y) ->
	OreScene = get_ore_scene(),
	near_ore_area(OreScene,Scene,X,Y).

near_ore_area([],_Scene,_X,_Y) ->
	false;
near_ore_area([{_s,_x,_y}|Lscene],Scene,X,Y) ->
	if
		_s == Scene andalso abs(X - _x) =< ?ORE_AREA andalso abs(Y - _y) =< ?ORE_AREA ->
			true;
		true ->
			near_ore_area(Lscene,Scene,X,Y)
	end.

%%退出处理 
do_logout(Player)->
	IsOreTime = is_ore_time(),
	InOreArea = in_ore_area(Player#player.scene,Player#player.x,Player#player.y),
	if
		IsOreTime andalso InOreArea ->
			case mod_ore_sup:get_mod_ore_pid() of
				Pid when is_pid(Pid) ->
					gen_server:cast(Pid,{'do_logout_clean',Player#player.id});
				true ->
					skip
			end;
		true ->
			skip
	end.

%% 强制退出挖矿状态 return {ok,Player}
cancel_ore_status(Player) ->
	{ok, BinData} = pt_36:write(36001,[1,0,Player#player.id]),
	mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData),
	OreSup = mod_ore_sup:get_mod_ore_pid(),
	gen_server:cast(OreSup, {'out_ore_dig', Player#player.id}).

%%根据在线人数设置矿石上限
get_limit()->
	Online =  mod_online_count:get_online_num(),
%%	?DEBUG("_______________________ONLINE_NUM:~p",[Online]),
	if
		Online < 200 -> 30;
		Online < 300 -> 45;
		Online < 500 -> 60;
		Online < 600 -> 75;
		Online < 700 -> 90;
		Online < 900 -> 120;
		true -> 135
	end.
%%天降彩石出现点
%%天降彩石出现点
get_ore_scene() ->
[
{201,75,78},
{201,59,116},
{201,75,53},
{201,33,101},
{201,13,128},
{201,11,97},
{201,23,66},
{201,29,71},
{201,32,37},
{201,25,28},
{201,37,124},
{201,58,75},
{201,76,132},
{201,71,157},
{201,50,155},
{251,75,78},
{251,59,116},
{251,75,53},
{251,33,101},
{251,13,128},
{251,11,97},
{251,23,66},
{251,29,71},
{251,32,37},
{251,25,28},
{251,37,124},
{251,58,75},
{251,76,132},
{251,71,157},
{251,50,155},
{281,75,78},
{281,59,116},
{281,75,53},
{281,33,101},
{281,13,128},
{281,11,97},
{281,23,66},
{281,29,71},
{281,32,37},
{281,25,28},
{281,37,124},
{281,58,75},
{281,76,132},
{281,71,157},
{281,50,155}
].


%%取消进程所用到的timer
cancel_timer() ->
	case get(diff_10) of
		undefined ->
			skip;
		Timer_dif_10  ->
			erlang:cancel_timer(Timer_dif_10),
			put(diff_10,undefined)
	end,
	case get(diff_5) of
		undefined ->
			skip;
		Timer_diff_5 ->	
			erlang:cancel_timer(Timer_diff_5),
			put(diff_10,undefined)
	end,
	case get(diff_3) of
		undefined ->
			skip;
		Timer_diff_3 ->
			erlang:cancel_timer(Timer_diff_3),
			put(diff_3,undefined)
	end,
	case get(diff_beg) of
		undefined ->
			skip;
		Timer_diff_beg ->
			erlang:cancel_timer(Timer_diff_beg),
			put(diff_beg,undefined)
	end,
	case get(diff_re_10) of
		undefined ->
			skip;
		Timer_diff_re_10 ->
			erlang:cancel_timer(Timer_diff_re_10),
			put(diff_re_10,undefined)
	end,
	case get(diff_re_20) of
		undefined ->
			skip;
		Timer_diff_re_20 ->
			erlang:cancel_timer(Timer_diff_re_20),
			put(diff_re_20,undefined)
	end,
	case get(diff_end) of
		undefined ->
			skip;
		Timer_diff_end ->
			erlang:cancel_timer(Timer_diff_end),
			put(diff_end,undefined)
	end.



%%
%% Local Functions
%%

