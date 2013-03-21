%%%--------------------------------------
%%% @Module  : lib_hook
%%% @Author  : dhq
%%% @Created : 2010.10.09
%%% @Description:挂机相关处理
%%%--------------------------------------

-module(lib_hook).
-export(
   	[
        is_auto_revive/1,
		is_auto_use_goods/2,
		get_scene_mon_info/1,
		init_hook_config/2,
		base_hook_time/0,
		start_hooking/2,
		end_hooking/2,
		check_max_exp_time_limit/2,
		time_limit_msg/0,
		set_hooking_time_test/2,
		get_open_time/0,
		get_end_time/0,
		opening_msg/1,
		is_open_hooking_scene/0,
		send_out_time/0,
		hook_scene_send_out/0,
		send_open_msg/1,
		send_open_msg_test/1,
		cancel_hoook_status/1,
		get_hook_config/1
	]
).
-include("common.hrl").
-include("record.hrl").

%% 判断挂机是否使用了自动复活，是则返回复活方式，否则false
%% Player 玩家状态信息
is_auto_revive(Player) ->
	%% 镇妖塔不可以自动复活
	case lib_scene:is_td_scene(Player#player.scene) of
		false ->
			case Player#player.scene =:= 780 of
				false ->
					HookConfig = get(hook_config),
		            case HookConfig#hook_config.revive of
		                1 ->
		                    GoodsTypeId = 
		                        case HookConfig#hook_config.revive_style of
		                            %% 高级稻草人
		                            1 ->
		                                28401;
		                            %% 稻草人
		                            _ ->
		                                28400
		                        end,
		                    case lib_goods:goods_find(Player#player.id, GoodsTypeId) of
		                        false ->					
		                            false;
		                        _Goods ->                    
		                            erlang:send_after(1000, Player#player.other#player_other.pid, {'HOOK_ACTION', 1, [HookConfig#hook_config.revive_style]})
		                    end;
		                _ ->
		                    false
		            end;
				true ->
					false
			end;
		true ->
			false
	end,
	Player#player{
  		status = 5
   	}.

%% 是否自动使用物品
%% Player 玩家状态信息
%% Type 自动使用类型，1气血包、2蓝包、3经验符
is_auto_use_goods(Player, Type) ->
	case Player#player.status of
		5 ->
			HookConfig = get(hook_config),
			[ColVal, GoodsTypeId] = 
				case Type of
					%% 气血包
					1 ->
						[HookConfig#hook_config.hp_pool, 23006];
					%% 蓝包
					2 ->
						[HookConfig#hook_config.mp_pool, 23106];
					_ ->
						GoodsId = 
							case HookConfig#hook_config.exp_style of
								%% 低级经验符
								1 ->
									23203;
								%% 高级经验符
								2 ->
									23205;
								_ ->
									0
							end,
						[HookConfig#hook_config.exp, GoodsId]
				end,
			case ColVal of
				1 ->
					case lib_goods:goods_find(Player#player.id, GoodsTypeId) of
                		false ->					
                    		false;
                		Goods ->
							erlang:send_after(1000, Player#player.other#player_other.pid, {'HOOK_ACTION', 2, [Goods#goods.id]}),
							true
            		end;
				_ ->
					false
			end;
		_ ->
			false
	end.

%% 获取场景怪物信息
%% SceneId 场景ID
get_scene_mon_info(SceneId) ->
	case lib_scene:is_copy_scene(SceneId) of
		false ->
			data_agent:scene_get_unique_mon(SceneId);
		true ->
			[]
	end.

%% 初始挂机打怪设置
init_hook_config(PlayerId, SceneId) ->
	%% 获取挂机设置
	{HookConfig, TimeStart, TimeLimit, Timestamp} = get_hook_config(PlayerId),
	put(hook_config, HookConfig),
	init_max_exp_time(PlayerId, TimeStart, TimeLimit, Timestamp, SceneId),
	HookConfig.


%% 获取挂机设置
get_hook_config(PlayerId) ->
	{HookConfig, TimeStart, TimeLimit, Timestamp} = 
        case db_agent:get_hook_config(PlayerId) of
            [RetHookConfig, TimeStart1, TimeLimit1, Timestamp1] ->
     			{RetHookConfig, TimeStart1, TimeLimit1, Timestamp1};						
            _ ->
          		db_agent:init_hook_config(PlayerId)
        end,
	NewHookConfig = util:string_to_term(tool:to_list(HookConfig)),
	NewHookConfig1 = 
		case is_list(NewHookConfig) andalso length(NewHookConfig) =:= 22 of
			true ->
				HK = list_to_tuple([hook_config | NewHookConfig]),
				case is_list(HK#hook_config.hp_list) orelse is_list(HK#hook_config.mp_list) of
					true ->
						HK#hook_config{
							hp_list = 0,
							mp_list = 0
						};
					false ->
						HK
				end;
			false ->
				#hook_config{}
		end,
	{NewHookConfig1, TimeStart, TimeLimit, Timestamp}.
	
	
%%检查最高挂机经验时间
init_max_exp_time(PlayerId,_TimeStart,TimeLimit,Timestamp,SceneId)->
	NowTime = util:unixtime(),
	case util:is_same_date(Timestamp, NowTime) of
		true->
			case lists:member(SceneId,data_scene:get_hook_scene_list()) of
				false->
					put(hook_time_setting,[NowTime,TimeLimit,Timestamp]);
				true->
					db_agent:update_hook_time(PlayerId,NowTime,TimeLimit,NowTime),
					put(hook_time_setting,[NowTime,TimeLimit,NowTime])
			end;
		false->
			db_agent:update_hook_time(PlayerId,NowTime,base_hook_time(),NowTime),
			put(hook_time_setting,[NowTime,base_hook_time(),NowTime])
	end.


%%开始挂机
start_hooking(PlayerStatus,SceneId)->
	case lists:member(SceneId,data_scene:get_hook_scene_list()) of
		true->
			NowTime = util:unixtime(),
			[_TimeStart,TimeLimit,Timestamp] = get(hook_time_setting),
			case util:is_same_date(Timestamp, NowTime) of
				true->
					db_agent:update_hook_time(PlayerStatus#player.id,NowTime,TimeLimit,Timestamp),
					put(hook_time_setting,[NowTime,TimeLimit,Timestamp]);
				false->
					db_agent:update_hook_time(PlayerStatus#player.id,NowTime,base_hook_time(),Timestamp),
					put(hook_time_setting,[NowTime,base_hook_time(),Timestamp])
			end;
		false->skip
	end.

%%结束挂机
end_hooking(PlayerId,SceneId)->
	case lists:member(SceneId,data_scene:get_hook_scene_list()) of
		true->
			NowTime = util:unixtime(),
			[TimeStart,TimeLimit,Timestamp] = get(hook_time_setting),
			case util:is_same_date(Timestamp, NowTime) of
				true->
					TimeHooking = NowTime-TimeStart,
					case TimeHooking > TimeLimit of
						false->
							TimeRemain = TimeLimit - TimeHooking,
							db_agent:update_hook_time(PlayerId,NowTime,TimeRemain,Timestamp),
							put(hook_time_setting,[NowTime,TimeRemain,Timestamp]);
						true->
							db_agent:update_hook_time(PlayerId,NowTime,0,Timestamp),
							put(hook_time_setting,[NowTime,0,Timestamp])
					end;
				false->
					{TotdaySeconds,_}=util:get_midnight_seconds(NowTime),
					HookingTime = NowTime -TotdaySeconds,
					case HookingTime> base_hook_time() of
						true->
							db_agent:update_hook_time(PlayerId,NowTime,0,NowTime),
							put(hook_time_setting,[NowTime,0,NowTime]);
						false->
							Remain = base_hook_time()-HookingTime,
							db_agent:update_hook_time(PlayerId,NowTime,Remain,NowTime),
							put(hook_time_setting,[NowTime,Remain,NowTime])
					end
			end;
		false->skip
	end.

%%检查最高经验剩余时间,是否获得经验加成
check_max_exp_time_limit(PlayerStatus,SceneId)->
	PlayerId = PlayerStatus#player.id,
	case lists:member(SceneId, data_scene:get_hook_scene_list()) of
		false->false;
		true->
			case is_open_hooking_scene() of
				opening->
					[TimeStart,TimeLimit,Timestamp] = get(hook_time_setting),
					NowTime = util:unixtime(),
					case util:is_same_date(Timestamp, NowTime) of
						true->
							case NowTime-TimeStart > TimeLimit of
								true-> 
									case get(activity_hook) of
										1 ->%%加过一次了
											skip;
										_ ->
											lib_activity:update_activity_data(hook, PlayerStatus#player.other#player_other.pid, PlayerId, 1),
											%%氏族祝福任务判断
											GWParam = {17, 1},
											lib_gwish_interface:check_player_gwish(PlayerStatus#player.other#player_other.pid, GWParam),
											put(activity_hook, 1)%%添加玩家活跃度统计
									end,
									if TimeLimit =:= 0->skip;
									   true->
										   db_agent:update_hook_time(PlayerId,NowTime,0,NowTime),
										   put(hook_time_setting,[NowTime,0,NowTime]),
										   {ok, BinData} = pt_26:write(26006, [0]),
										   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
									end,
									false;
								false->
									%%正常挂机中10分钟回写
									case util:floor(NowTime/60)rem 10 =:= 0 of
										true->
											TimeRemain = TimeLimit - (NowTime-TimeStart),
											db_agent:update_hook_time(PlayerId,NowTime,TimeRemain,NowTime),
											put(hook_time_setting,[NowTime,TimeRemain,NowTime]);
										false -> 
											skip
									end,
									true
							end;
						false->
							db_agent:update_hook_time(PlayerId,NowTime,base_hook_time(),NowTime),
							put(hook_time_setting,[NowTime,base_hook_time(),NowTime]),
							true	
					end;
				_->false
			end
	end.


%%推送挂机剩余
time_limit_msg()->
	[_TimeStart,TimeLimit,_Timestamp] = get(hook_time_setting),
	TimeLimit.

%%挂机时间(30分钟)
base_hook_time()->1800.

%%设置挂机时间（测试）
set_hooking_time_test(PlayerId,Seconds)->
	NowTime = util:unixtime(),
%% 	[TimeStart,TimeLimit,Timestamp] = get(hook_time_setting),
	db_agent:update_hook_time(PlayerId,NowTime,Seconds,NowTime),
	put(hook_time_setting,[NowTime,Seconds,NowTime]).

%%玩家上线，推送开放的消息
send_open_msg(PlayerStatus)->
	case is_open_hooking_scene() of
		opening->
			if PlayerStatus#player.lv>=30->
				{ok,BinData} = pt_12:write(12401,[2]),
				lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
			   true->skip
			end;
		_->skip
	end.
send_open_msg_test(Type)->
	{ok,BinData} = pt_12:write(12401,[Type]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData).
	
%%检查是否挂机区开放时间
is_open_hooking_scene()->
	Start = ?HOOKING_OPEN,
	End = ?HOOKING_CLOSE,
	NowSec = util:get_today_current_second(), 
	if NowSec < Start->early;
	   NowSec > End -> late;
	   true->opening
	end.

opening_msg(Type)->
	case Type of
		1-> Content = "<font color='#FEDB4F'>亲爱的玩家，今天的挂机区开始开放，海量经验等你拿～</font>";
		2-> 
			Content = "<font color='#FEDB4F'>今天的挂机区已经结束开放，请各位亲爱的玩家明天再来～</font>";
		_-> Content = []
	end,
	case Content of
		[]->skip;
		_->
			lib_chat:broadcast_sys_msg(1, Content)
	end.

get_open_time()->
	Start = ?HOOKING_OPEN,
	NowSec = util:get_today_current_second(),
	Sec = if NowSec >= Start-> round(24*3600-NowSec+Start)*1000;
	   true->round(Start-NowSec)*1000
	end,
	Sec.

get_end_time()->
	End = ?HOOKING_CLOSE,
	NowSec = util:get_today_current_second(),
	Sec = if NowSec >= End-> round(24*3600-NowSec+End)*1000;
	   true->round(End-NowSec)*1000
	end,
	Sec.

send_out_time()->
	End = ?HOOKING_CLOSE,
	NowSec = util:get_today_current_second(),
	round(End-NowSec)*1000.

hook_scene_send_out()->
	send_out(data_scene:get_hook_scene_list()).

send_out([])->ok;
send_out([SceneId|SceneList])->
	PlayerBag = lib_scene:get_scene_user(SceneId),
	[send_out_msg(P)||P<-PlayerBag],
	send_out(SceneList).
send_out_msg(P)->
	[_Id, _Nick, _X, _Y, _Hp, _HpLim, _Mp, _MpLim, _Lv, _Career, _Speed,
	  _EquipCurrent, _Sex, _OutPet, Pid|_] = P,
	Pid!{'HOOK_SECNE_SEND_OUT'}.

%% 取消挂机状态
cancel_hoook_status(Player) ->
	if
		Player#player.status =/= 5 ->
			Player;	
		true ->
			{ok, BinData} = pt_26:write(26003, [0, 0]),
    		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
			Player#player{
				status = 0			  
			}
	end.

