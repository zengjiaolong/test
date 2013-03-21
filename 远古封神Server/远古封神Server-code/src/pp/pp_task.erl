%%%------------------------------------
%%% @Module     : pp_task
%%% @Author     : ygzj
%%% @Created    : 2010.10.06
%%% @Description: 任务模块
%%%------------------------------------
-module(pp_task).
-compile(export_all).
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").

%% 获取任务列表
handle(30000, PlayerStatus, []) ->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_task,{'task_list',PlayerStatus});
	
%%已接任务列表
handle(30001,PlayerStatus,[])->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_task,{'trigger_task',PlayerStatus});

%%委托任务列表
handle(30002,PlayerStatus,[])->
	ConSign_Bag = lib_task:get_consign_task(PlayerStatus#player.id),
    ConSignList = lists:map(
					fun(RT) ->
							TD = lib_task:get_data(RT#ets_task_consign.task_id),
							{TD#task.id, TD#task.name,RT#ets_task_consign.times,
							 RT#ets_task_consign.exp,RT#ets_task_consign.spt,RT#ets_task_consign.cul,
							 RT#ets_task_consign.timestamp,RT#ets_task_consign.gold,1}
					end,
					ConSign_Bag
						   ),
	{NewPlayerStatus,NewConsignTask} = lib_task:check_consign_finish(PlayerStatus,ConSignList,[]),
	{ok, BinData2} = pt_30:write(30002, NewConsignTask),
    lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData2),
	case NewPlayerStatus =/= PlayerStatus of
		true->
			lib_player:send_player_attribute(NewPlayerStatus, 1);
		false->skip
	end,
	{ok, NewPlayerStatus};

%% 接受任务
handle(30003, PlayerStatus, [TaskId,Color]) ->
	case tool:is_operate_ok(pp_30003, 1) of
		true ->
			{IsTrigger,Status} = 
				case TaskId =:=20361 of
					false-> 
						case lists:member(TaskId,lib_hero_card:get_hero_task_list()) of
							true->{skip,PlayerStatus};
							false->
								{true,PlayerStatus}
						end;
					true->
						case mod_single_dungeon:enter_single_dungeon_scene(PlayerStatus) of
							{ok,NewPlayer}->{true,NewPlayer};
							_->{false,PlayerStatus}
						end
				end,
			case IsTrigger of
				true->
					case lib_task:trigger(TaskId,Color,Status,0) of
						{true, NewPlayerStatus} ->
							{ok, BinData1} = pt_30:write(30003, [TaskId,100]),
						 	lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData1),
  				        	 lib_task:preact_finish(TaskId, NewPlayerStatus),
							 {ok, BinData} = pt_30:write(30006, [1,0]),
							 lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData),
							 next_task_cue(TaskId, NewPlayerStatus,1),    %% 显示npc的默认对话
							%%飞行坐骑老账号处理
%% 							spawn(fun()->mount_task_change(NewPlayerStatus,TaskId)end),
							%%任务自动传送
%% 							NewPlayerStatus1 = task_auto_send(NewPlayerStatus,TaskId),
							if PlayerStatus =:=NewPlayerStatus->ok;
							   true->
								    lib_player:send_player_attribute(NewPlayerStatus, 1)
							end,
							{ok, NewPlayerStatus};
						{false, Reason} ->  
%% 							lib_task:kick_out_of_single_dungeon(PlayerStatus,TaskId),
							{ok, BinData1} = pt_30:write(30003, [TaskId,Reason]),
				            lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1),
							ok;
						{'EXIT', _} -> 
%% 							lib_task:kick_out_of_single_dungeon(PlayerStatus,TaskId),
							{ok, BinData2} = pt_30:write(30003, [TaskId,113]),
  				       		lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData2),
							ok
					end;
				false->
					{ok, BinData2} = pt_30:write(30003, [TaskId,116]),
 		 		    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData2),
					ok;
				_->skip
 		   end;
		false->skip
	end;


%% 完成任务
handle(30004, PlayerStatus, [TaskId, SelectItemList])->
	case tool:is_operate_ok(pp_30004, 1) of
		true ->
%% 			case gen_server:call(PlayerStatus#player.other#player_other.pid_task,{'finish',PlayerStatus,TaskId,SelectItemList}) of
		    case lib_task:finish(TaskId, SelectItemList, PlayerStatus) of
				{true, NewPlayerStatus} ->
					case TaskId   of
						20219->
							{ok, BinData1} = pt_30:write(30006, [1,0]),
 		        			lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData1),
							SceneId = lib_task:get_sceneid_by_realm(NewPlayerStatus#player.realm),
							pp_scene:handle(12005, NewPlayerStatus, SceneId);
						20361->
							{ok, BinData1} = pt_30:write(30006, [1,0]),
							lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData1),
							pp_scene:handle(12030, NewPlayerStatus, null),
							{ok,NewPlayerStatus};
%% 							case mod_single_dungeon:finish_single_dungeon_task(NewPlayerStatus) of
%% 								{ok,NewPlayerStatusFinal1} ->
%% 									{ok, BinData1} = pt_30:write(30006, [1,0]),
%% 									lib_send:send_to_sid(NewPlayerStatusFinal1#player.other#player_other.pid_send, BinData1),
%% 									pp_scene:handle(12030, NewPlayerStatusFinal1, null),
%% 									{ok,NewPlayerStatusFinal1};
%% 								{_,NewPlayerStatusFinal1} ->
%% 									{ok, BinData2} = pt_30:write(30004, [205]),
%% 									lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData2),
%% 									{ok,NewPlayerStatusFinal1}
%% 							end;
%% 						84010 ->%%情人节活动，表达爱意任务，2月14号 0点后可删除
%% 							case lib_activities:is_lovedays_time(util:unixtime()) of
%% 								true ->
%% 									lib_activities:send_to_task_1(PlayerStatus#player.nickname),
%% 									lib_activities:send_to_task_1(PlayerStatus#player.couple_name);
%% 								false ->
%% 									skip
%% 							end;
						_ ->
							{ok, BinData} = pt_30:write(30004, [100]),
							lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData),
%% 							lib_scene:refresh_npc_ico(NewPlayerStatus),           %% 刷新npc图标
							next_task_cue(TaskId, NewPlayerStatus,0),    %% 显示npc的默认对话
							{ok, BinData1} = pt_30:write(30006, [1,0]),
							lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData1),
							NewPlayerStatus1 = first_pet_out(NewPlayerStatus,TaskId),
							if NewPlayerStatus1=/=PlayerStatus->
						   		lib_player:send_player_attribute(NewPlayerStatus1, 1);
					   		true->skip
							end,
							{ok, NewPlayerStatus1}
					end;
				{false, Reason} ->
					{ok, BinData} = pt_30:write(30004, [Reason]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
				{'EXIT', _} ->
					{ok, BinData2} = pt_30:write(30004, [113]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData2)
			end;
		false->skip
	end;

%% 放弃任务
handle(30005, PlayerStatus, [TaskId])->
	case TaskId =:= ?GUILD_WISH_TASK_ID of
		true ->%%氏族任务不能主动放弃
			{ok, BinData} = pt_30:write(30005, [0]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			ok;
		false ->
			case lib_task:abnegate(TaskId, PlayerStatus) of
				{true,PS} -> 
					lib_task:refresh_active(PS),
					{ok, BinData} = pt_30:write(30006, [1,0]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
					{ok,PS};
				{false,_PS} ->
					{ok, BinData} = pt_30:write(30005, [0]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
					ok
			end
	end;

%% 任务对话事件
handle(30007, PlayerStatus, [TaskId, NpcUniqueId])->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_task,{'talk_npc',PlayerStatus, TaskId, NpcUniqueId});

%% 触发并完成任务
handle(30008, PlayerStatus, [TaskId, SelectItemList])->
	case tool:is_operate_ok(pp_30008, 1) of
		true ->
%% 			case gen_server:call(PlayerStatus#player.other#player_other.pid_task,{'trigger_and_finish',PlayerStatus,TaskId,SelectItemList}) of
        	case lib_task:trigger_and_finish(TaskId, SelectItemList, PlayerStatus) of	
			{true, NewRS} -> 
					{ok, BinData1} = pt_30:write(30008, [100]),
    				lib_send:send_to_sid(NewRS#player.other#player_other.pid_send, BinData1), %% 完成任务
%%             		lib_scene:refresh_npc_ico(NewRS),           %% 刷新npc图标
					{ok, BinData2} = pt_30:write(30006, [1,0]),
    				lib_send:send_to_sid(NewRS#player.other#player_other.pid_send, BinData2),  %% 发送更新命令
           		 	next_task_cue(TaskId, NewRS,0),       %% 显示npc的默认对话
					if PlayerStatus=/=NewRS->
						   lib_player:send_player_attribute(NewRS, 1);
					   true->skip
					end,
            		{ok, NewRS};
        		{false, Reason} ->
					{ok, BinData1} = pt_30:write(30008, [Reason]),
            		lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1);
				{'EXIT', _} -> 
					{ok, BinData2} = pt_30:write(30008, [113]),
           		 lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData2)
			end;
		false->skip
	end;

%% 打开窗口事件	
handle(30010, PlayerStatus, [Type]) ->
	case Type of
		1->
			%%打开商城
   			lib_task:event(open_store, null, PlayerStatus);
		2->
			%%打开法宝融合
			lib_task:event(trump,null,PlayerStatus);
		3->
			%%打开药店窗口
			lib_task:event(open_drugstore,null,PlayerStatus);
		4->
			%%收藏页面
			lib_task:event(save_html,null,PlayerStatus);
		5->
			%%打开强化页面
			lib_task:event(open_strength,null,PlayerStatus);
		6->
			%%打开仓库
			lib_task:event(open_storehouse,null,PlayerStatus);
		7->
			%%开神兽蛋
			lib_task:event(pet_eggs,null,PlayerStatus);
		8->
			%%灵兽技能融合 
			lib_task:event(pet_skill,null,PlayerStatus);
		9->
			case check_appraisal_place(PlayerStatus#player.realm,PlayerStatus#player.scene,PlayerStatus#player.x,PlayerStatus#player.y) of
				false->
					{ok, BinData} = pt_30:write(30010, [2]),
           		 	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
				true->
					{ok, BinData} = pt_30:write(30010, [1]),
           			 lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
			end;
		10->
			case check_appraisal_place(PlayerStatus#player.realm,PlayerStatus#player.scene,PlayerStatus#player.x,PlayerStatus#player.y) of
				true->
					lib_task:event(open_appraisal,null,PlayerStatus);
				false->
					{ok, BinData} = pt_30:write(30010, [2]),
           		 	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
			end;
		11->
			%%加入氏族
			lib_task:event(guild,null,PlayerStatus);
		_->
			ok
	end,
    ok;

%%接受委托任务
handle(30012,PlayerStatus,[ConsignList])->
	case tool:is_operate_ok(pp_30008, 1) of
		true ->
%% 			case gen_server:call(PlayerStatus#player.other#player_other.pid_task,{'accept_consign_task',PlayerStatus,ConsignList}) of
			case lib_task:accept_consign_task(PlayerStatus,ConsignList) of	
			{true,NewPlayerStatus,Result}->
					{ok, BinData1} = pt_30:write(30012, [Result]),
		            lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData1),
					gen_server:cast(NewPlayerStatus#player.other#player_other.pid_task,{'refresh_task',NewPlayerStatus}),
					case NewPlayerStatus =/= PlayerStatus of
						true->
							lib_player:send_player_attribute(NewPlayerStatus, 1),
							{ok,NewPlayerStatus};
						false->skip
					end;
				{false,_,Result1}->
					{ok, BinData1} = pt_30:write(30012, [Result1]),
		            lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1)
			end;
		false->skip
	end;

%%检查委托任务
handle(30013,PlayerStatus,[TaskId])->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_task,{'check_consign_task',PlayerStatus,TaskId});

%%立即完成委托任务
handle(30014,PlayerStatus,[])->
	{Res,NewPlayerStatus} = lib_task:finish_consign_task_now(PlayerStatus),
	{ok, BinData} = pt_30:write(30014, [Res]),
    lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData),
	case NewPlayerStatus =/= PlayerStatus of
		true->
			handle(30002,NewPlayerStatus,[]),
			lib_player:send_player_attribute(NewPlayerStatus, 1),
			{ok,NewPlayerStatus};
		false->skip
	end;

%%立即完成跑商任务
handle(30015,PlayerStatus,[TaskId])-> 
	{Res,NewPlayerStatus} = lib_task:finish_business_task(PlayerStatus,TaskId),
	{ok, BinData1} = pt_30:write(30015, [Res]),
    lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData1),
	{ok, BinData} = pt_30:write(30006, [1,0]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	case NewPlayerStatus =/= PlayerStatus of
		true->
			lib_player:send_player_attribute(NewPlayerStatus, 1),
			{ok,NewPlayerStatus};
		false->skip
	end;

%%打开表白面板，获取所有投票数据
handle(30024,PlayerStatus,[]) ->
	Now = util:unixtime(),
	case lib_activities:is_whiteday_time(Now) of
		false ->
			{ok,Bindata} = pt_30:write(30024,{[],0,2}),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, Bindata);
		true ->
			Wpid = mod_wedding:get_mod_wedding_pid(),
			Wpid ! {'GET_ALL_LOVER',PlayerStatus#player.id, PlayerStatus#player.other#player_other.pid_send}
	end,
	ok;

%%投票
handle(30025,PlayerStatus,[Lid]) ->
	Now = util:unixtime(),
	case lib_activities:is_whiteday_time(Now) of
		false ->
			{ok,BinData} = pt_30:write(30025,{5,0,0}),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		true ->
			case PlayerStatus#player.lv < 35 of
				true ->%%等级不足
					{ok,BinData} = pt_30:write(30025,{3,0,0}),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
				false ->
					NowSec = util:get_today_current_second(),
					case NowSec >= ?ONE_DAY_SECONDS-10 andalso NowSec =< ?ONE_DAY_SECONDS of
						false ->
							Wpid = mod_wedding:get_mod_wedding_pid(),
							Wpid ! {'VOTE_LOVER',PlayerStatus#player.id, PlayerStatus#player.other#player_other.pid_send, Lid};
						true ->	%%亲，目前已经是表白统计的时间了，您的投票是无效的哦
							{ok,BinData} = pt_30:write(30025,{7,0,0}),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
					end
			end
	end,
	ok;

%%发起表白
handle(30026,PlayerStatus,[Rname,Content]) ->
	Now = util:unixtime(),
	case lib_activities:is_whiteday_time(Now) of
		false ->
			{ok,BinData} = pt_30:write(30026,8), %% 8 现在不是表白活动开放时间
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		true ->
			if PlayerStatus#player.lv < 35 ->
				   {ok,BinData} = pt_30:write(30026,7),
				   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
			   true ->
				   case Rname =:= PlayerStatus#player.nickname of
					   true -> 
						   {ok,BinData} = pt_30:write(30026,3),
						   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);%%不能向自己表白
					   false ->
						   %%长度判断
						   case lib_guild:validata_name(Content, 2, 100) of
							   true ->
								   %%合法性判断
								   case lib_words_ver:words_ver(Content) of
									   true ->
										   NowSec = util:get_today_current_second(),
										   case NowSec >= ?ONE_DAY_SECONDS-10 andalso NowSec =< ?ONE_DAY_SECONDS of
											   false ->
												   Wpid = mod_wedding:get_mod_wedding_pid(),
												   Wpid ! {'ADD_LOVE_DATA',Rname,Content,PlayerStatus#player.id, PlayerStatus#player.nickname, PlayerStatus#player.other#player_other.pid_send};
											   true ->%%在投票统计时间段，不要投票或者表白
												   {ok,BinData} = pt_30:write(30026,9),
												   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
										   end;
									   false ->
										   {ok,BinData} = pt_30:write(30026,5),
										   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
								   end;
							   false ->
								   {ok,BinData} = pt_30:write(30026,4),
								   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
						   end
				   end
			end
	end,
	ok;

%%查询副本令任务信息
handle(30022,PlayerStatus,[TaskId])->
	Data = lib_task:check_dungeon_card_task(PlayerStatus,TaskId),
	{ok, BinData} = pt_30:write(30022, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%使用副本令完成副本/氏族任务
handle(30023,PlayerStatus,[TaskBag])->
	{Res,NewPlayerStatus} = lib_task:finish_task_by_dungeon_card(PlayerStatus,TaskBag),
	{ok, BinData} = pt_30:write(30023, [Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	case PlayerStatus /= NewPlayerStatus of
		true->
			{ok, NewPlayerStatus};
		false ->
			skip
	end;

%% 检查是否有在线奖励
handle(30070, PlayerStatus, [])->
	{_, NewPlayerStatus, Data, GoodsBag} = lib_online_gift:check_online_gift(PlayerStatus),
	{ok, BinData} = pt_30:write(30070, [Data, GoodsBag]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	case PlayerStatus /= NewPlayerStatus of
		true->
			{ok, NewPlayerStatus};
		false ->
			skip
	end;

%%获取在线物品奖励
handle(30071,PlayerStatus,[])->
	{_,NewPlayerStatus,Data,GoodsBag} = lib_online_gift:get_online_gift(PlayerStatus),
	{ok,BinData} = pt_30:write(30071,[Data,GoodsBag]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	case PlayerStatus /= NewPlayerStatus of
		true->
			{ok,NewPlayerStatus};
		false ->
			skip
	end;

%% 获取目标奖励信息
handle(30072, PlayerStatus, [])->
%% 	{_, NewPlayerStatus, Day, TargetBag} = lib_target_gift:check_target_gift(PlayerStatus),
	{_, NewPlayerStatus, Day, TargetBag} = lib_target:check_target_info(PlayerStatus),
	{ok, BinData} = pt_30:write(30072, [Day, TargetBag]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	case PlayerStatus /= NewPlayerStatus of
		true->
			{ok,NewPlayerStatus};
		false ->
			skip
	end;

%%获取目标奖励
handle(30073,PlayerStatus,[Day,Times])->
	case lib_target:get_target_award(PlayerStatus,Day,Times) of
		[NewStauts,1]->
			{ok, BinData} = pt_30:write(30073, [1,Day,Times]),
    		lib_send:send_to_sid(NewStauts#player.other#player_other.pid_send, BinData),
			{ok,NewStauts};
		[_,Err]->
			{ok, BinData} = pt_30:write(30073, [Err,Day,Times]),
    		lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;
	
%%选择国家
handle(30080,PlayerStatus,[Type,Realm]) ->
	case PlayerStatus#player.realm =:= 100 of
		true->
%% 			{PS, Data} =gen_server:call(PlayerStatus#player.other#player_other.pid_task,{'select_realm',PlayerStatus,Type,Realm}),
			{_, PS, Data} = lib_task:select_nation(PlayerStatus,Type,Realm),
			{ok,BinData} = pt_30:write(30080, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
			lib_task:event(select_nation, Realm, PS),
			next_task_cue(20219, PS,0),%% 显示npc的默认对话
			lib_player:send_player_attribute(PS, 1),
			lib_achieve:check_achieve_finish(PS#player.other#player_other.pid_send, 
											 PS#player.id, 101, [1]),
			Titles = PS#player.other#player_other.titles,
			case Titles of
				[] ->
					{_Result, NewStatus} = lib_achieve_outline:use_ach_title(PS, 101),
					%%需要即时更新玩家的属性状态
					spawn(fun()->lib_player:send_player_attribute(NewStatus, 1) end),
					{ok,NewStatus};
				_ ->
					case lib_title:check_normal_t_use(Titles) of
						{true, _Title} ->%%没用过
							{_Result, NewStatus} = lib_achieve_outline:use_ach_title(PS, 101),
							%%需要即时更新玩家的属性状态
							spawn(fun()->lib_player:send_player_attribute(NewStatus, 1) end),
							{ok,NewStatus};
						false ->
							{ok,PS}
					end
			end;
%% 			%%自动完成任务 
%% 			case gen_server:call(PS#player.other#player_other.pid_task,{'finish',PS,20219,0}) of
%% 				{true, NewPS} ->
%% 					%%通知客户端刷新任务列表
%% 					{ok, BinData1} = pt_30:write(30006, [1,0]),
%%      		       lib_send:send_to_sid(NewPS#player.other#player_other.pid_send, BinData1),
%% 					%%传送到主城
%% 					SceneId = lib_task:get_sceneid_by_realm(NewPS#player.realm),
%% 					pp_scene:handle(12005, NewPS, SceneId);
%% 				_ ->
%% 					{ok,PS}
%% 			end;
		false->
			skip
	end;

%% 筋斗云(1:Npc、2：怪物,3场景)
handle(30090,Player,[TaskId,Type,Id])->
	%% 使用小飞鞋
	case lib_task:check_shoe_use(Player, Type, TaskId) of
		{ok, _} ->
			%PlayerStatus = lib_vip:check_vip_state(Player),
			Result = 
				case Player#player.vip =:= 3 of
					false -> 
						check_vip_send_times(Player);
					true -> 
						1
				end,
			case Result of
				1 ->
					%%查找目的地的场景id和坐标
					{SceneId, _, X1, Y1} = get_secne(Player#player.realm, Id, Type, Player#player.scene, Player#player.lv),
					case SceneId of
						0->
							
							ErrorCode = 
								case Type of
									1 -> 3;
									2 -> 4;
									_ -> 5
								end,
							if 
								Player#player.vip =/= 3 ->
									gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player, 28201, 1,0});
							   	true -> skip
							end,
							{ok,BinData} = pt_30:write(30090,[ErrorCode]),
							lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
						_->
							case lib_deliver:check_scene_enter(SceneId) of
								false->
									if Player#player.vip =/= 3 ->
										gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player, 28201, 1,0});
									   	true -> skip
									end,
									{ok,BinData} = pt_30:write(30090,[7]),
									lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
								true->
									case lists:member(SceneId, data_scene:get_hook_scene_list()) of
										false->
											NewStatus = lib_deliver:deliver(Player, SceneId, X1, Y1, 3),
											notice_hooking_mon(NewStatus,Type,Id),
											{ok, NewStatus};
										true->
											case lib_hook:is_open_hooking_scene() of
												opening->
													NewStatus = lib_deliver:deliver(Player, SceneId, X1, Y1, 3),
													notice_hooking_mon(NewStatus,Type,Id),
													{ok,NewStatus};
												_->
													if 
														Player#player.vip =/= 3 ->
															gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player, 28201, 1,0});
									   					true -> skip
													end,
													{ok, BinData} = pt_30:write(30090, [8]),
													lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
											end
									end
													
							end
					end;
				_ ->
					{ok, BinData} = pt_30:write(30090,[1]),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
			end;
		{error, Result} ->
			{ok, BinData} = pt_30:write(30090, [Result]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end;

%%每日传送(Type:1:Npc、2：怪物,3场景)
handle(30091,Player,[Type,Id,MoneyType])->
	PlayerStatus = lib_vip:check_vip_state(Player),
	case lib_task:check_send(PlayerStatus, MoneyType) of
		{ok, _}->
			daily_deliver(PlayerStatus,MoneyType,Type,Id,PlayerStatus#player.scene,0,0);
		{error, Result}->
			{ok, BinData} = pt_30:write(30091, [Result]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;

%%世界地图传送(Type:1:Npc、2：怪物,3场景)
handle(30092,Player,[Type,Id,MoneyType,SceneId,X,Y])->
	PlayerStatus = lib_vip:check_vip_state(Player),
	case lib_task:check_send(PlayerStatus, MoneyType) of
		{ok, _}->
			daily_deliver(PlayerStatus,MoneyType,Type,Id,SceneId,X,Y);
		{error, Result}->
			{ok, BinData} = pt_30:write(30091, [Result]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;


%% 查询国运时间
handle(30300, Player, []) ->
	CarryData = 
		case lib_carry:check_double_time() of
			{true, Remain} ->
				[1, 1, Remain];
			{false, _} ->
				[0, 0, 0]
		end,
	{ok, BinData} = pt_30:write(30300, CarryData),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

%% 查询委托任务列表
handle(30400,PlayerStatus,[])->
	ConsignInfo = lib_consign:get_consign_times_list(PlayerStatus#player.id),
	mod_consign:check_consign_task(PlayerStatus,ConsignInfo);

%%发布委托任务
handle(30401,PlayerStatus,TaskInfo)->
%% 	case gen_server:call(PlayerStatus#player.other#player_other.pid_task,{'publish_consign_task',PlayerStatus,TaskInfo}) of
	case lib_task:publish_consign_task(PlayerStatus,TaskInfo) of
		{error,Result}->
			{ok,BinData} = pt_30:write(30401,[Result]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		{ok,NewPlayerStatus}->
			{ok,BinData} = pt_30:write(30401,[1]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			{ok,NewPlayerStatus}
	end;


%%接受委托任务
handle(30402,PlayerStatus,[Id,TaskId])->
%% 	case gen_server:call(PlayerStatus#player.other#player_other.pid_task,{'accept_task_consign',PlayerStatus,Id,TaskId})of
	case lib_task:accept_task_consign(PlayerStatus,[Id,TaskId]) of	
		{error,Result}->
			{ok,BinData} = pt_30:write(30402,[Result]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		{ok,NewPlayerStatus}->{ok,NewPlayerStatus}
	end;


%%取消委托任务
handle(30403,PlayerStatus,[Id])->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_task,{'cancel_task_consign',PlayerStatus,Id});

%% 	mod_consign:accept_consign_task(PlayerStatus,Id,TaskId);

%%答题
%% handle(30500,PlayerStatus,[TaskId,QuestionId])->
%% 	lib_task:event(question, {QuestionId}, PlayerStatus),
%% 	case gen_server:call(PlayerStatus#player.other#player_other.pid_task,{'finish',PlayerStatus,TaskId,0}) of
%% 		{true, NewPlayerStatus} ->
%% 			%%通知客户端刷新任务列表
%% 			{ok, BinData1} = pt_30:write(30006, [1,0]),
%%      		lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData1),
%% 			{ok,NewPlayerStatus};
%% 		_ ->skip
%% 	end;

%%每日任务累积
handle(30600,_PlayerStatus,[])->ok;
%% 	gen_server:cast(PlayerStatus#player.other#player_other.pid_task,{'daily_task',PlayerStatus});

%%查询商车信息
handle(30700,PlayerStatus,[])->
	BusinessInfo = lib_business:check_car_info(PlayerStatus),
	{ok, BinData1} = pt_30:write(30700, BusinessInfo),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1);

%%选择商车索引时返回结果
 handle(30701, PlayerStatus, [Color])->
	 case lib_business:check_business(PlayerStatus,Color)of
		 {false,FailNum} ->
			 {ok, BinData1} = pt_30:write(30701,[FailNum,0]);
		 {true,RColor,_Other} ->
			 {ok, BinData1} = pt_30:write(30701,[1,RColor])
	 end,
     lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1);

%% handle(30702, PlayerStatus, [])->
	%% {Stime,Etime,_Btime} = lib_business:get_double_time(),
	 %% Now = util:unixtime(),
	 %% if Now >= Stime andalso Now < Etime ->
			%%%%io:format("pp_task 558 line Stime = ~p, Etime = ~p , Now = ~p, ~n", [Stime,Etime,Now]),
			%% {ok,BinData} = pt_30:write(30702,[1,Etime-Now]);
		%% true ->
		%% 	{ok,BinData} = pt_30:write(30702,[0,0])
	%%  end,
	%%  lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%% 查询跑商双倍倒计时
handle(30702, Player, []) ->
	NowSec = util:get_today_current_second(),
	[Result, Remain] =
		if 
			NowSec > ?BUSINESS_DOUBLE_START_TIME andalso NowSec < ?BUSINESS_DOUBLE_END_TIME ->
				case util:get_date() of
					?BUSINESS_DOUBLE_DAY ->
						Dist = ?BUSINESS_DOUBLE_END_TIME - NowSec,
						[1, Dist];
					_ ->
						[0, 0]
				end;
	   		true ->
				[0, 0]
		end,
	{ok, BinData} = pt_30:write(30702, [Result, Remain]),		
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

%%跑商购买元宝
handle(30703, PlayerStatus, [Color])->
	if 
		Color =:= 7 orelse Color =:= 6 ->
			case lib_business:check_bag_enough(PlayerStatus) of
				true ->{_Type,GoodsId} = lists:keyfind(Color,1,?GOODSTYPE),
					   [Info] = ets:lookup(?ETS_BASE_GOODS, GoodsId),
					   Price =Info#ets_base_goods.price,
					   [Gold,_A,_B,_C] = db_agent:get_player_money(PlayerStatus#player.id),
					   case Gold < Price of
						   true -> {ok,BinData} = pt_30:write(30703,[0]),
								   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
								   {ok,PlayerStatus};
						   false ->
							   case catch(gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
														  {'give_goods',PlayerStatus,GoodsId,1,0})) of
								   ok->
									   TaskId = lib_business:get_level_tid(PlayerStatus#player.lv),
									   db_agent:cost_money(PlayerStatus, Price, gold, 1706),
									   NewStatus = PlayerStatus#player{gold = Gold - Price},
									   {ok,BinData} = pt_30:write(30703,[1]),
									   lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData),
									   %%io:format("pp_task 591 line PlayerStatus carry_mark = ~p~n",[PlayerStatus#player.carry_mark]),
									   case handle(30003, NewStatus, [TaskId,Color]) of
										   {ok,NewStatus1} ->
											   %%io:format("pp_task 591 line NewStatus carry_mark = ~p~n",[NewStatus#player.carry_mark]),
											   {ok,NewStatus1};
										   _ ->
											   %%io:format("pp_task 600 line result = 3~n"),
											   {ok,BinData1} = pt_30:write(30703,[3]),
											   lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData1),
											   ok
									   end;
								   _Other->
									   %%io:format("pp_task 600 line result = 4~n"),
									   {ok,BinData} = pt_30:write(30703,[4]),
									   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
							   		   ok
							   end
					   end;
				false ->
					%%io:format("pp_task 600 line result = 2~n"),
					{ok,BinData} = pt_30:write(30703,[2]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
					ok
			end;
		true -> skip
	end;
			

%%刷新商车
%%handle(30701,PlayerStatus,[Times,Color])->
%%	case lib_business:refresh_car(PlayerStatus,Times,Color) of
	%%	{fail,Error}->
		%%	{ok, BinData1} = pt_30:write(30701, [Error,0,0,0,0,0]),
			%%lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1);
		%%{ok,NewPlayerStatus,[Res,Total,NewColor,Free,MaxFree,FreeTime]}->
			%%{ok, BinData1} = pt_30:write(30701, [Res,Total,NewColor,Free,MaxFree,FreeTime]),
			%%lib_player:send_player_attribute(NewPlayerStatus, 1),
			%%lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData1),
			%%{ok,NewPlayerStatus}
	%%end;

%%请求刷新有缘人时间CD
handle(30800,PlayerStatus,[])->
	{ok,Timestamp,Invitee}= lib_love:check_refresh(PlayerStatus#player.id),
	{ok, BinData} = pt_30:write(30800, [Timestamp,Invitee]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%%%刷新有缘人
handle(30801,PlayerStatus,[Type])->
	case lib_love:refresh(PlayerStatus,Type) of
		{error,Error}->
			{ok, BinData} = pt_30:write(30801, [Error,0,[]]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		{ok,NewPlayer,PlayerList,Timestamp}->
			{ok, BinData} = pt_30:write(30801, [1,Timestamp,PlayerList]),
			lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData),
			if PlayerStatus=/=NewPlayer ->
				   lib_player:send_player_attribute(NewPlayer, 1),
				   {ok,NewPlayer};
			   true->skip
			end
	end;

%%查看玩家当前状态
handle(30802,PlayerStatus,[PlayerId])->
	{_,Res}= lib_love:check_invite(PlayerId),
	{ok, BinData} = pt_30:write(30802, [Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%邀请有缘人
handle(30803,PlayerStatus,[Type,Name])->
	{_,Res}=lib_love:invite(PlayerStatus,Name,Type),
%% 	if Type=:=1 andalso Res=:=1->
%% 		   {ok,NewPlayerStatus} = lib_love:del_invite_gold(PlayerStatus,30),
%% 		   lib_love:invite_msg_gold(NewPlayerStatus,30);
%% 	   true->NewPlayerStatus = PlayerStatus
%% 	end,
	{ok, BinData} = pt_30:write(30803, [Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	ok;
%% 	if PlayerStatus=/=NewPlayerStatus ->
%% 		   lib_player:send_player_attribute(NewPlayerStatus, 1),
%% 		   {ok,NewPlayerStatus} ;
%% 	   true->skip
%% 	end;
	

%%收到邀请
handle(30804,PlayerStatus,[PlayerId,Name,Career,Sex,Type])->
    lib_love:accept_invite_msg(PlayerStatus),
	{ok, BinData} = pt_30:write(30804, [PlayerId,Name,Career,Sex,Type]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%接受、拒绝邀请
handle(30805,PlayerStatus,[Res,PlayerId,Type])->
	case lib_love:accept_invite(PlayerStatus,PlayerId,Res,Type) of
		{ok,Player}->
			{ok, BinData} = pt_30:write(30805, [Res,PlayerStatus#player.id,
												PlayerStatus#player.nickname,
												PlayerStatus#player.career,
												PlayerStatus#player.sex]),
			case Res of
				1->
					if Type =/= 3->
						lib_relationship:send_friend_request(PlayerStatus, 1, Player#player.id, Player#player.nickname);
					   true->skip
					end;
				_->skip
			end,
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		_->skip
	end;

%%取消邀请
handle(30808,PlayerStatus,[PlayerId])->
	case lib_love:cancel_invite(PlayerId,PlayerStatus#player.nickname) of
		{ok,Player}->
			{ok, BinData} = pt_30:write(30808,[PlayerStatus#player.nickname]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		_->skip
	end;

%%赠送礼物
handle(30806,PlayerStatus,[InviteId,Mult])->
%% 	?DEBUG("____________________FLOWER___30806______________",[]),
	case lib_love:present_gift(PlayerStatus,InviteId,Mult) of
		{error,Error}->
			{ok, BinData} = pt_30:write(30806,[Error]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		{ok,NewPlayerStatus}->
			{ok, BinData} = pt_30:write(30806,[1]),
			lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData),
%% 			lib_player:send_player_attribute(NewPlayerStatus, 1),
			{ok,NewPlayerStatus}
	end;

%%评价以及赠送鲜花
handle(30810,PlayerStatus,[PlayerId,App,Flower])->
%% 	?DEBUG("____________________FLOWER___30810_____",[]),
	{_,Res}=lib_love:evaluate(PlayerStatus,PlayerId,App,Flower),
	{ok, BinData} = pt_30:write(30810,[Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%推送评价
handle(30811,PlayerStatus,[PlayerId,Name,Career,Sex,App,Flower,_Charm])->
%% 	NewPlayerStatus = lib_love:get_evaluate(PlayerStatus,Charm),
	{ok, BinData} = pt_30:write(30811,[PlayerId,Name,Career,Sex,App,Flower]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
%% 	{ok,NewPlayerStatus};

%%默契度测试
handle(30813,PlayerStatus,[Answer])->
	NewPlayer = lib_love:answer(PlayerStatus,Answer),
	{ok,NewPlayer};

%% 查询登陆抽奖信息
handle(30075,PlayerStatus,[]) ->
	[GoodsId,Days,Times,GoodsList]=lib_lucky_draw:get_luckydraw_info(PlayerStatus#player.id),
	{ok, BinData} = pt_30:write(30075,[GoodsId,Days,Times,GoodsList]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%登陆抽奖
handle(30076,PlayerStatus,[])->
	case lib_lucky_draw:lucky_draw(PlayerStatus) of
		{error,Error}->
			{ok, BinData} = pt_30:write(30076,[Error,0]);
		{ok,GoodsId} ->
			{ok, BinData} = pt_30:write(30076,[1,GoodsId])
	end,
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%领取物品
handle(30077,PlayerStatus,[])->
	case lib_lucky_draw:get_goods(PlayerStatus) of
		{ok,GoodsId,LD}->
			{ok, BinData} = pt_30:write(30077,[1,GoodsId,LD#ets_luckydraw.days,LD#ets_luckydraw.times,LD#ets_luckydraw.goodslist]);
		{error,Error}->
			{ok, BinData} = pt_30:write(30077,[Error,0,0,0,[0,0,0,0,0,0,0,0,0,0,0,0]])
	end,
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%% 查询目标引导
handle(30078, PlayerStatus, []) ->
	TargetList =  lib_target_lead:target_lead_info(PlayerStatus#player.id),
	{ok, BinData} = pt_30:write(30078,TargetList),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%更新目标引导
handle(30079,PlayerStatus,[Lv])->
	{NewPlayerStatus,Res,Rank} = lib_target_lead:update_targetlead(PlayerStatus,Lv),
	{ok, BinData} = pt_30:write(30079,[Res,Rank]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	if PlayerStatus =/= NewPlayerStatus ->
		   lib_player:send_player_attribute(NewPlayerStatus, 1),
		   {ok,NewPlayerStatus};
	   true->ok
	end;

%% 查询登陆奖励（新）
handle(30081, PlayerStatus, []) ->
	{IsCharge, Days, UnChargeGoods, ChargeGoods} = lib_login_award:check_award_info(PlayerStatus#player.id),
	{ok, BinData} = pt_30:write(30081, [IsCharge, Days, UnChargeGoods, ChargeGoods]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%清除登陆天数
handle(30082,PlayerStatus,[])->
	{_,Res} = lib_login_award:clear_login_days(PlayerStatus#player.id),
	{ok, BinData} = pt_30:write(30082,[Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%领取物品奖励
handle(30083,PlayerStatus,[Type,Day])->
	{_,Res} =  lib_login_award:get_award(PlayerStatus,Type,Day) ,
	{ok, BinData} = pt_30:write(30083,[Res,Type,Day]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	ok;

%% 查询是否可以领取每日在线奖励
handle(30900, PlayerStatus, []) ->
	Result =  lib_daily_award:check_today_times(PlayerStatus),
	{ok, BinData} = pt_30:write(30900,[Result]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%领奖返回的结果
handle(30901,PlayerStatus,[])->
	{Result, TimeStamp, GoodsId, IsEnd} =  lib_daily_award:get_single_gift(PlayerStatus),
	{ok, BinData} = pt_30:write(30901,[Result, TimeStamp, GoodsId, IsEnd]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%获取BOSS重生倒计时
handle(30902,PlayerStatus,[])->
	gen_server:cast(mod_rank:get_mod_rank_pid(), {boss_refresh_time,PlayerStatus#player.other#player_other.pid_send});

%%查询循环任务奖励倍数
handle(30101,PlayerStatus,[])->
	Mult = lib_cycle_flush:check_mult(PlayerStatus#player.id),
	{ok, BinData} = pt_30:write(30101,[Mult]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%刷新循环任务奖励倍数
handle(30102,PlayerStatus,[GoodsTypeId,Num,GoodsId])->
	{Res,Mult} = case lib_cycle_flush:flush_mult(PlayerStatus,GoodsTypeId,Num,GoodsId) of
					 {error,Error}->{Error,10};
					 {ok,Res1,M}->{Res1,M}
				 end,
	{ok, BinData} = pt_30:write(30102,[Res,Mult]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);


%%查询刷镖信息
handle(30103,PlayerStatus,[])->
	Data = lib_carry:check_flush_info(PlayerStatus#player.id),
	{ok, BinData} = pt_30:write(30103,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%刷镖
handle(30104,PlayerStatus,[NpcId])->
	{_,NewPlayer,Res} = lib_carry:flush_qc(PlayerStatus,NpcId),
	{ok, BinData} = pt_30:write(30104,[Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	if NewPlayer=/=PlayerStatus ->
		   {ok,NewPlayer};
	   true->ok
	end;

%%查询新手礼包信息
handle(30084,PlayerStatus,[])->
	Data =lib_novice_gift:check_novice_gift(PlayerStatus#player.id,PlayerStatus#player.lv,PlayerStatus#player.career),
%% 	io:format("Data>>>>>>~p~n",[Data]),
	{ok, BinData} = pt_30:write(30084,Data),	
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%领取新手礼包信息
handle(30085,PlayerStatus,[Lv])->
	{_,Res,EList} = lib_novice_gift:get_novice_gift(PlayerStatus,Lv),
	{ok, BinData} = pt_30:write(30085,[Res,EList]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	if Res =:= 1->
		   handle(30084,PlayerStatus,[]);
	   true->skip
	end;

%%拜师，收徒引导
handle(30086,PlayerStatus,[Type])->
	{ok, BinData} = pt_30:write(30086,[Type]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%开服活动信息
handle(30087,Player,[])->
	case check_holiday_time() of
		[]->
			skip;
		Activities ->
			{ok, BinData} = pt_30:write(30087,Activities),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
			ok
	end,
	ok;

%%查询活动物品领取记录
handle(30088,Player,[Type])->
	NowTime = util:unixtime(),
	{Res,G} =
		if Type =:=1 orelse Type=:=2->
			   case config:get_opening_time() of
				   0->{1,0};
					Timestamp->
						if NowTime - 7*86400 > Timestamp ->{1,0};
						   true->
							   case db_agent:check_vip_experience(Player#player.id,Type) of
								   []->
									   Gold = lib_player:calc_player_pay(Player#player.id,Type,Timestamp),
									   {0,Gold};
								   _->{1,0}
							   end
						end
			   end;
		   Type=:=3->
			   if ?HOLIDAY_START =< NowTime andalso NowTime =< ?HOLIDAY_END->
					  case db_agent:check_vip_experience(Player#player.id,Type) of
						  []->{0,0};
						  _->{1,0}
					  end;
				  true->{1,0}
			   end;
		   true->{1,0}
		end,
	{ok, BinData} = pt_30:write(30088, [Type,Res,G]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	ok;

%%领取VIP体验卡（1领取成功，2累计充值金额不足100元宝，3背包空间不足，4已经领取过了，5系统繁忙，稍后重试,6活动已经过去,7累计充值金额不足1000元宝,8数据异常）
handle(30089,Player,[Type])->
	NowTime = util:unixtime(),
	Res  = 
		if Type=:=1 orelse Type=:=2->
			   case config:get_opening_time() of
					0->6;
					Timestamp->
						if NowTime - 7*86400 > Timestamp ->6;
						   true->
							    case db_agent:check_vip_experience(Player#player.id,Type) of
								   []->
									   case Type of
										   1->
											   case lib_player:calc_player_pay(Player#player.id,Type,Timestamp) < 100 of
												   true->2;
												   false->
													   case gen_server:call(Player#player.other#player_other.pid_goods,{'cell_num'})< 1 of
														   false->
															   case ( catch gen_server:call(Player#player.other#player_other.pid_goods,
																							{'give_goods', Player,28604, 1,2})) of
																   ok ->
																	   db_agent:insert_vip_experience(Player#player.id,28604,util:unixtime(),Type),
																	   1;
																   _->5
															   end;
														   _true->3
													   end
											   end;
										   2->
											   case lib_player:calc_player_pay(Player#player.id,Type,Timestamp) < 1000 of
												   true->7;
												   false->
													   case lib_activities:give_stren5_hw(Player) of
														   [1]->
															   GoodsId = 
																   case Player#player.career of
																	   1 -> 11203;%%玄武
																	   2 -> 12203;%%白虎
																	   3 -> 13203;%%青龙
																	   4 -> 14203;%%朱雀
																	   5 -> 15023%%麒麟
																   end,
															   db_agent:insert_vip_experience(Player#player.id,GoodsId,util:unixtime(),Type),
															   1;
														   _->5
													   end
											   end;
										   _->5
									   end;
								   _->4
							   end
						end
			   	end;
		   Type=:=3->
			    if ?HOLIDAY_START =< NowTime andalso NowTime =< ?HOLIDAY_END->
					    case db_agent:check_vip_experience(Player#player.id,Type) of
							[]->
								case gen_server:call(Player#player.other#player_other.pid_goods,{'cell_num'})< 1 of
									false->
										case ( catch gen_server:call(Player#player.other#player_other.pid_goods,
																	 {'give_goods', Player,28126, 2,2})) of
											ok ->
												db_agent:insert_vip_experience(Player#player.id,28126,util:unixtime(),Type),
												1;
											_->5
										end;
									_true->3
								end;
							_->4
						end;
				   true->6
				end;
		   true->5
		end,
	{ok, BinData} = pt_30:write(30089, [Res]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	if Res =:=1->
		   handle(30088,Player,[Type]);
	   true->skip
	end,
	ok;

%%光棍节活动
handle(30093,PlayerStatus,[Type])->
	{NewPlayerStatus,Res} = lib_love:convert_goods(PlayerStatus,Type),
	{ok, BinData} = pt_30:write(30093, [Res]),
	lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData),
	if NewPlayerStatus =/= PlayerStatus ->
		    lib_player:send_player_attribute(NewPlayerStatus, 1),
		   {ok,NewPlayerStatus};
	   true->ok
	end;

%%购买魅力礼包(1购买成功，2元宝不足，3背包空间不足，4系统繁忙，稍后重试)
handle(30094,PlayerStatus,[])->
	Gold = 100,
	{Res,NewPlayerStatus} = 
		case goods_util:is_enough_money(PlayerStatus,Gold,gold) of
			false->{2,PlayerStatus};
			true->
				case gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
									 {'cell_num'})< 1 of
					false->
						case ( catch gen_server:call(PlayerStatus#player.other#player_other.pid_goods, 
													 {'give_goods', PlayerStatus,31046, 1,0})) of
							ok ->
								PlayerStatus1 = lib_goods:cost_money(PlayerStatus,Gold,gold,1601),
								{1,PlayerStatus1};
							_->{4,PlayerStatus}
						end;
					true->{3,PlayerStatus}
				end
		end,
	{ok,BinData} = pt_30:write(30094,[Res]),
	lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send,BinData),
	if PlayerStatus =/= NewPlayerStatus ->
		lib_player:send_player_attribute(NewPlayerStatus, 1),
		{ok,NewPlayerStatus};
	   true->ok
	end;
		
%% 测试接口，清除某个任务	
handle(30100, PlayerStatus, [TaskId]) ->
    case lib_task:abnegate(TaskId, PlayerStatus) of
        true -> 
%%             lib_scene:refresh_npc_ico(PlayerStatus),
			{ok, BinData} = pt_30:write(30006, [1,0]),		
    		lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
        false -> false
    end,
    ok;

%% 测试接口，清除所有任务
handle(30200, PlayerStatus, []) ->
    lists:map(
        fun(RT) ->
            lib_task:del_trigger(PlayerStatus#player.id, RT#role_task.task_id),
            lib_task:del_log(PlayerStatus#player.id, RT#role_task.task_id)
        end,
        lib_task:get_trigger(PlayerStatus)
    ),
	lib_task:delete_role_task(PlayerStatus#player.id),
    lib_task:flush_role_task(PlayerStatus),
%%     lib_scene:refresh_npc_ico(PlayerStatus),
	{ok, BinData} = pt_30:write(30006, [1,0]),
%% io:format("30006_9_ ~n"),	
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
    ok;

%% -----------------------------------------------------------------
%% 30016 周年庆活动祈愿信息
%% -----------------------------------------------------------------
handle(30016, PlayerStatus, []) ->
	case tool:is_operate_ok(pp_30016, 2) of
		true ->
			NowTime = util:unixtime(),
			%%周年活动时间
			{ST, ET} = lib_activities:anniversary_time(),
			case ST =< NowTime andalso NowTime =< ET of
				true ->
					mod_anniversary:get_wish_tree(PlayerStatus),
					ok;
				false ->%%已经不是该时间段了
					ok
			end;
		false ->%%频率过快，直接扔消息啦
			ok
	end;

%% -----------------------------------------------------------------
%% 30017 周年庆活动发送祈愿
%% -----------------------------------------------------------------
handle(30017, PlayerStatus, [Gid, Content]) ->
	Result = 
		case tool:is_operate_ok(pp_30017, 2) of
			true ->
				case PlayerStatus#player.lv < 35 of
					false ->
				NowTime = util:unixtime(),
				%%周年活动时间
				{ST, ET} = lib_activities:anniversary_time(),
				case ST =< NowTime andalso NowTime =< ET of
					true ->
						case lib_guild:validata_name(Content, 0, 200) of
							true ->%%中文字符少于100个（包括标点符号）
								case lib_words_ver:words_ver(Content) of
									true ->%%没非法字符，ok
										NowSec = util:get_today_current_second(),
										case lib_anniversary:check_wish_time(NowSec, NowTime) of
											false ->
												2;
											true ->%%是在许愿时间，可以许愿
												MarkTime = lib_anniversary:get_wish_mark(),
												Diff = NowTime - MarkTime,
												case Diff =< 1800 of
													true ->
														3;
													false ->
														case lib_anniversary:check_wish_goods(Gid) of
															true ->%%物品合法哦
																case mod_anniversary:make_wish(PlayerStatus, Gid, Content, NowTime) of
																	1 ->
																		lib_anniversary:put_wish_mark(NowTime),
																		1;
																	OtherResult ->
																		OtherResult
																end;
															false ->%%物品不合法
																8
														end
												end
										end;
									false ->%%有非法字符
										6
								end;
							false ->%%字数太多了
								7
						end;
					false ->%%不是活动时间
						9
				end;
					true ->
						10
				end;
			false ->%%点太快了
				4
		end,
	{ok, BinData30017} = pt_30:write(30017, [Result]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30017),
	%%主动推一次信息
	case Result of
		1 ->
			handle(30016, PlayerStatus, []);
		_ ->
			skip
	end,
	ok;
	
%% -----------------------------------------------------------------
%% 30018 获取幸运转盘数据
%% -----------------------------------------------------------------
handle(30018, PlayerStatus, [Gid,GoodsType]) ->
	case tool:is_operate_ok(pp_30018, 1) of
		true ->
			GoodsInfo = goods_util:get_goods(Gid),
			case is_record(GoodsInfo, goods) of
				false -> %%物品不存在
					{ok, BinData30018} = pt_30:write(30018, [Gid,GoodsType,2, 0]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30018),
					ok;
				true ->%%居然有这个物品
					case lib_anniversary:check_bigwheel(PlayerStatus#player.id,GoodsType) of
					{on, GoodsId} when GoodsType == 31229 ->%%转过了
						{ok, BinData30018} = pt_30:write(30018, [Gid,GoodsType,3, GoodsId]),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30018),
							ok;
					{on,GoodsId} when GoodsType == 28750 ->
							{ok, BinData30018} = pt_30:write(30018, [Gid,GoodsType,1, GoodsId]),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30018),
							ok;
					{off, _} ->%%没转过
							if
								%%普通转盘触发时即给出物品
								GoodsType == 28750 ->
									GoodsId = lib_anniversary:roll_big_wheel(PlayerStatus#player.id,GoodsType,0,GoodsInfo),
									Code = 
										case GoodsId > 0 of
											   true -> 1;
											   false -> 3
									end;
								true ->
									GoodsId = 0,
									Code = 1
							end,
							{ok, BinData30018} = pt_30:write(30018, [Gid,GoodsType,Code, GoodsId]),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30018),
							ok
					end
			end;
		false ->
			{ok, BinData30018} = pt_30:write(30018, [Gid,GoodsType,4, 0]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30018),
			ok
	end;

%% -----------------------------------------------------------------
%% 30019 幸运大转盘转动
%% -----------------------------------------------------------------
handle(30019, PlayerStatus, [Gid,GoodsType,Type]) ->
	case tool:is_operate_ok(pp_30019, 1) of
		true ->
			if
				%%幸运大转盘
				GoodsType == 31229 -> 
					case lists:member(Type, [1,2,3,4]) of
						true ->
							case lib_goods:goods_find(PlayerStatus#player.id, GoodsType) of
								[] -> %%物品不存在
									{ok, BinData30019} = pt_30:write(30019, [Gid,GoodsType,Type, 2, 0]),
									lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30019),
									ok;
								GoodsInfo ->%%居然有这个物品
									case lib_anniversary:check_bigwheel(PlayerStatus#player.id,GoodsType) of
										{on, GoodsId} ->%%转过了
											{ok, BinData30019} = pt_30:write(30019, [Gid,GoodsType,Type, 3, GoodsId]),
											lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30019),
											ok;
										{off, _} ->%%没转过
											%%计算转动得出的物品Id
											GoodsId = lib_anniversary:roll_big_wheel(PlayerStatus#player.id,GoodsType,Type,GoodsInfo),
											{ok, BinData30019} = pt_30:write(30019, [Gid,GoodsType,Type, 1, GoodsId]),
											lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30019),
											ok
									end
							end;
						false ->%%发送的数据有误了，出错
							{ok, BinData30019} = pt_30:write(30019, [Gid,GoodsType,Type, 4, 0]),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30019),
							ok
					end;
				%%幸运盘
				GoodsType == 28750 ->
					GoodsInfo = goods_util:get_goods(Gid),
					case is_record(GoodsInfo, goods) of
						false ->
							{ok, BinData30019} = pt_30:write(30019, [Gid,GoodsType,Type, 2, 0]),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30019),
							ok;
						true ->
							case lib_anniversary:check_bigwheel(PlayerStatus#player.id,GoodsType) of
								{on, GoodsId} ->%%转过了
									{ok, BinData30019} = pt_30:write(30019, [Gid,GoodsType,Type, 1, GoodsId]),
									lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30019),
									ok;
								{off, _} ->%%没转过
									%%计算转动得出的物品Id
									GoodsId = lib_anniversary:roll_big_wheel(PlayerStatus#player.id,GoodsType,Type,GoodsInfo),
									Code = case GoodsId > 0 of
											   true -> 1;
											   false -> 4
										   end,
									{ok, BinData30019} = pt_30:write(30019, [Gid,GoodsType,Type, Code, GoodsId]),
									lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30019),
									ok
							end
					end;
				true ->
					{ok, BinData30019} = pt_30:write(30019, [Gid,GoodsType,Type, 4, 0]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30019),
					ok
			end;
		false ->
			{ok, BinData30019} = pt_30:write(30019, [Gid,GoodsType,Type, 4, 0]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30019),
			ok
	end;

%% -----------------------------------------------------------------
%% 30020 猜灯谜请求
%% -----------------------------------------------------------------
handle(30020, Status, []) ->
	{Result, Lid, ENum, No} = 
		case tool:is_operate_ok(pp_30020, 1) of
			true ->
				NowTime = util:unixtime(),
				%%判断是否 是 元宵节活动时间
				case lib_activities:is_lantern_festival_time(NowTime) of
					false ->%%不是元宵活动时间，直接免了
						{2, 0, 0, 0};
					true ->
						NSec = util:get_today_current_second(),
						%%获取猜灯谜的时间
						{LSTime, SETime} = lib_activities:get_lantern_riddles_time(),
						case LSTime =< NSec andalso NSec =< SETime of
							false ->%%不是猜灯谜的时间，也直接跳过
								{2, 0, 0, 0};
							true ->
								lib_activities:check_lantern_riddles(NowTime, Status#player.id)
						end
				end;
			false ->%%发包的频率太快了
				{4, 0, 0, 0}
		end,
	{ok, BinData30020} = pt_30:write(30020, [Result,Lid, ENum, No]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData30020),
	ok;
		
%% -----------------------------------------------------------------
%% 30021 猜灯谜结果发送
%% -----------------------------------------------------------------
handle(30021, Status, [Answer]) ->
	Result = 
		case tool:is_operate_ok(pp_30021, 1) of
			true ->
				case Answer>= 1 andalso Answer =< 4 of
					true ->
						NowTime = util:unixtime(),
							%%判断是否 是 元宵节活动时间
						case lib_activities:is_lantern_festival_time(NowTime) of
							false ->%%不是元宵活动时间，直接免了
								6;
							true ->
								NSec = util:get_today_current_second(),
								%%获取猜灯谜的时间
								{LSTime, SETime} = lib_activities:get_lantern_riddles_time(),
								case LSTime =< NSec andalso NSec =< SETime of
									false ->%%不是猜灯谜的时间，也直接跳过
										6;
									true ->
										lib_activities:answer_lantern_riddles(Answer, NowTime, Status)
								end
						end;
					false ->%%乱发数据嫌疑
						5
				end;
			false ->%%太快了
				4
		end,
	{ok, BinData30020} = pt_30:write(30021, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData30020),
	ok;

%%爱的宣言
handle(30028,PlayerStatus,[Talk])->
	case PlayerStatus#player.couple_name of
		[]->skip;
		Name->
			case lib_task:get_one_trigger(84010, PlayerStatus#player.id) of
				false->skip;
				_->
					Data_filtered = lib_words_ver:words_filter([Talk]),
					Msg = io_lib:format("<font color='#FEDB4F'>~s</font>对<font color='#FEDB4F'>~s</font>说：~s", [PlayerStatus#player.nickname,Name,Data_filtered]),
					lib_chat:broadcast_sys_msg(6,Msg),
					%% 			lib_chat:chat_world(PlayerStatus, [Data_filtered]),
					lib_task:event(love_show,null,PlayerStatus),
					ok
			end
	end,
	ok;

%%点名
handle(30029,Status,[Name])->
	case lib_task:appoint(Status,Name) of
		[1]->skip;
		Res->
			{ok,Bindata} = pt_30:write(30030, Res),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bindata)
	end;

%%应答点名
handle(30030,Status,[Res,Name])->
	case lib_task:appoint_result(Status,Res,Name) of
		[2]->skip;
		[1] ->
			{ok, BinData} = pt_30:write(30006, [1,0]),
		    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		Error ->
			{ok,Bindata} = pt_30:write(30030, Error),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bindata)
	end,
	ok;

%% -----------------------------------------------------------------
%% 30031 竞猜面板请求
%% -----------------------------------------------------------------
handle(30031, PlayerStatus, []) ->
	case tool:is_operate_ok(pp_30031, 1) of
		true ->
			lib_quizzes:handle_30031(PlayerStatus);
		false ->
			skip
	end,
	ok;

%% -----------------------------------------------------------------
%% 30032 开始竞猜
%% -----------------------------------------------------------------
handle(30032, PlayerStatus, []) ->
	case tool:is_operate_ok(pp_30032, 1) of
		true ->
			lib_quizzes:handle_30032(PlayerStatus);
		false ->
			skip
	end,
	ok;

%% -----------------------------------------------------------------
%% 30034 领取奖励
%% -----------------------------------------------------------------
handle(30034, PlayerStatus, []) ->
	case tool:is_operate_ok(pp_30034, 1) of
		true ->
			lib_quizzes:handle_30034(PlayerStatus);
		false ->
			{ok, BinData30034} = pt_30:write(30034, [3]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData30034)
	end,
	ok;
handle(_Cmd, _PlayerStatus, _Data) ->
    {error, bad_request}.

%% 完成任务后是否弹结束npc的默认对话
next_task_cue(TaskId, PlayerStatus,Type) ->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_task,{'next_task_cue',PlayerStatus,TaskId,Type}).


%%任务自动传送
task_auto_send(Status,TaskId)->
	if TaskId =:= 20419->
		   NpcId = 20118,
		   case get_secne(Status#player.realm,NpcId,1,Status#player.scene,Status#player.lv) of
			   {0,0,0,0}->Status;
			   {SceneId, _, X1, Y1} ->
				   lib_deliver:deliver(Status,SceneId,X1,Y1,0)
		   end;
	   true->Status
	end.
	   
%%%%查找目的地的场景id和坐标
get_secne(Realm,Id,Type,SceneId,Lv)->
	case Type of
		1->lib_task:get_npc_def_scene_info(Id,Realm,SceneId,Lv);
		2->lib_task:get_mon_def_scene_info(Id,Realm,SceneId);
		_->{0,0,0,0}
	end.

%%查询VIP传送次数
check_vip_send_times(PlayerStatus)->
	case lib_vip:check_send_times(PlayerStatus#player.id,PlayerStatus#player.vip) of
		true->1;
		false->
			gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', 28201, 1})
	end.
			
%%%%%%每日活动面板传送(Type:1:Npc、2：怪物,3场景)
%% SendType 1元宝，2铜钱，3筋斗云
daily_deliver(PlayerStatus,SendType,Type,Id,SceneId,X,Y)->
	case Type of
		3->deliver_scene(PlayerStatus,SendType,Id);
		4->deliver_xy(PlayerStatus,SendType,SceneId,X,Y);
		_->deliver_mon_npc(PlayerStatus,SendType,Type,Id,SceneId)
	end.
%%场景传送
deliver_scene(PlayerStatus,SendType,Id)->
	%%检查是否副本类地图
	case lib_deliver:check_scene_enter(Id) of
		false->
			{ok,BinData} = pt_30:write(30091,[8]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		true->
			%%VIP半年卡用户无限飞
			Result = case PlayerStatus#player.vip =:= 3 of
						 false->check_vip_send_times(PlayerStatus);
						 true->1
					 end,
			case Result of
				1->
					%%获取场景数据
					case data_scene:get(Id) of
						[]->
							{ok,BinData} = pt_30:write(30091,[6]),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
						SceneInfo->
							%%检查是否挂机区场景
							case lists:member(Id,data_scene:get_hook_scene_list()) of
								false->
									NewStatus=lib_deliver:deliver(PlayerStatus,Id,SceneInfo#ets_scene.x,SceneInfo#ets_scene.y,SendType),
									{ok,NewStatus};
								true->
									%%检查挂机区是否开放
									case lib_hook:is_open_hooking_scene() of
										opening->
											NewStatus=lib_deliver:deliver(PlayerStatus,Id,SceneInfo#ets_scene.x,SceneInfo#ets_scene.y,SendType),
											{ok,NewStatus};
										_->
											%%传送失败，返还筋斗云
											if PlayerStatus#player.vip =/= 3->
												   gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'give_goods', PlayerStatus,28201, 1,0});
											   true->skip
											end,
											{ok,BinData} = pt_30:write(30091,[9]),
											lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
									end
							end
					end;
				_->
					{ok,BinData} = pt_30:write(30091,[7]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
			end
	end.

%%指定的XY坐标传送
deliver_xy(PlayerStatus,SendType,SceneId,X,Y)->
	%%检查是否副本类地图
	case lib_deliver:check_scene_enter(SceneId) of
		false->
			{ok,BinData} = pt_30:write(30091,[8]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		true->
			%%VIP半年卡用户无限飞
			Result = case PlayerStatus#player.vip =:= 3 of
						 false->check_vip_send_times(PlayerStatus);
						 true->1
					 end,
			case Result of
				1->
					%%获取场景数据
					case data_scene:get(SceneId) of
						[]->
							{ok,BinData} = pt_30:write(30091,[6]),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
						_SceneInfo->
							
							%%检查是否挂机区场景
							case lists:member(SceneId,data_scene:get_hook_scene_list()) of
								false->
									NewStatus=lib_deliver:deliver(PlayerStatus,SceneId,X,Y,SendType),
									{ok,NewStatus};
								true->
									%%检查挂机区是否开放
									case lib_hook:is_open_hooking_scene() of
										opening->
											NewStatus=lib_deliver:deliver(PlayerStatus,SceneId,X,Y,SendType),
											{ok,NewStatus};
										_->
											%%传送失败，返还筋斗云
											if PlayerStatus#player.vip =/= 3->
												   gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'give_goods', PlayerStatus,28201, 1,0});
											   true->skip
											end,
											{ok,BinData} = pt_30:write(30091,[9]),
											lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
									end
							end
					end;
				_->
					{ok,BinData} = pt_30:write(30091,[7]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
			end
	end.


deliver_mon_npc(PlayerStatus,SendType,Type,Id,SceneIdCheck)->%%查找目的地的场景id和坐标
	%%获取传送面板的场景坐标
	{SceneId,_,X1,Y1} = get_secne(PlayerStatus#player.realm,Id,Type,SceneIdCheck,PlayerStatus#player.lv),
	case SceneId of
		0->
			ErrorCode = 
				case Type of
					1->4;
					2->5;
					_->6
				end,
			{ok,BinData} = pt_30:write(30091,[ErrorCode]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		_->
			%%检查是否副本类地图
			case lib_deliver:check_scene_enter(SceneId) of
				false->
					{ok,BinData} = pt_30:write(30091,[8]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
				true->
					%%3为筋斗云传送
					case  SendType =:= 3 of
						true->
							%%VIP半年卡用户无限飞
							Result = case PlayerStatus#player.vip =:= 3 of
										 false->check_vip_send_times(PlayerStatus);
										 true->1
									 end,
							case Result of
								1->
									case lists:member(Id,data_scene:get_hook_scene_list()) of
										false->
											NewStatus=lib_deliver:deliver(PlayerStatus,SceneId,X1,Y1,SendType),
											notice_hooking_mon(NewStatus,Type,Id),
											{ok,NewStatus};
										true->
											case lib_hook:is_open_hooking_scene() of
												opening->
													NewStatus=lib_deliver:deliver(PlayerStatus,SceneId,X1,Y1,SendType),
													notice_hooking_mon(NewStatus,Type,Id),
													{ok,NewStatus};
												_->
													if PlayerStatus#player.vip =/= 3->
														   gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'give_goods', PlayerStatus,28201, 1,0});
													   true->skip
													end,
													{ok,BinData} = pt_30:write(30091,[9]),
													lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
											end
									end;
								_->
									{ok,BinData} = pt_30:write(30091,[7]),
									lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
							end;
						false->
							case lists:member(Id,data_scene:get_hook_scene_list()) of
								false->
									NewStatus=lib_deliver:deliver(PlayerStatus,SceneId,X1,Y1,SendType),
									notice_hooking_mon(NewStatus,Type,Id),
									NewPlayerStatus = case SendType of
														  1->lib_goods:cost_money(NewStatus,3,gold,3004);
														  _->lib_goods:cost_money(NewStatus,5000,coin,3004)
													  end,
									lib_player:send_player_attribute(NewPlayerStatus, 1),
									{ok,NewPlayerStatus};
								true->
									case lib_hook:is_open_hooking_scene() of
										opening->
											NewStatus=lib_deliver:deliver(PlayerStatus,SceneId,X1,Y1,SendType),
											notice_hooking_mon(NewStatus,Type,Id),
											NewPlayerStatus = case SendType of
																  1->lib_goods:cost_money(NewStatus,3,gold,3004);
																  _->lib_goods:cost_money(NewStatus,5000,coin,3004)
															  end,
											lib_player:send_player_attribute(NewPlayerStatus, 1),
											{ok,NewPlayerStatus};
										_->
											{ok,BinData} = pt_30:write(30091,[9]),
											lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
									end
							end
					end
			end
	end.
				
%%检查是否开放活动或者特殊活动期间
%%数组形式返回[type,state,stime,etime],不作活动关闭推送，前端定时消失
check_holiday_time()->
	Act0 = [],
	NowTime = util:unixtime(),
	%% 开服活动
	case config:get_opening_time() of
		0 ->
			Act1 = Act0;
		Opentime ->
			case util:get_diff_days(NowTime, Opentime)  > 7 of
				true ->
					Act1 = Act0;
				false ->
					Act1 = [[1,1,Opentime,NowTime]|Act0]
			end
	end,
	%% 普通活动
	case lib_activities:all_may_day_time() of
		{S1,S2} when S1 =< NowTime andalso S2 > NowTime ->
			Act2 = [[13,1,S1,S2]|Act1];
		{S1,_S2} when NowTime < S1 ->
			check_before_holiday_time(S1,NowTime),
			Act2 = Act1;
		_ ->
			Act2 = Act1
	end,
	%% 充值祈福活动
	case lib_pay_pray:get_pay_pray_time() of
		{PS1,PS2} when PS1 =< NowTime andalso PS2 > NowTime ->
			Act3 = [[11,1,PS1,PS2]|Act2];
		{PS1,_PS2} when NowTime < PS1 ->
			check_before_holiday_time(PS1,NowTime),
			Act3 = Act2;
		_ ->
			Act3 = Act2
	end,
	Act3.

%%在活动之前登陆的，就要判断是否需要在特定的时间内推一个活动发起的通知
check_before_holiday_time(EventStart, NowTime) ->
	case NowTime < EventStart andalso (EventStart - NowTime) < ?ONE_DAY_SECONDS of
		true ->
			Diff = trunc(EventStart - NowTime + 2)*1000,%%多加2秒的延时
			erlang:send_after(Diff, self(), {'CHECK_HOLIDAY_TIME'});
		false ->
			skip
	end.
%%活动结束发送消息
holiday_end_send(Days) ->
	misc:cancel_timer(holiday_end),
	TimeRef = erlang:send_after(Days*1000, self(), {'OPENING_AWARD_END'}),
	put(holiday_end, TimeRef).

%%检查藏宝图地点
check_appraisal_place(Realm,Scene,X,Y)->
	SceneMain = case Realm of 
					1->201;
					2->281;
					_->251
				end,
	if SceneMain =:= Scene->
		   {[Xd1,Yd1],[Xu1,Yu1]} = {[63,73],[67,77]},
%% 		   {[Xd2,Yd2],[Xu2,Yu2]} = {[41,76],[45,80]},
%% 		   {[Xd3,Yd3],[Xu3,Yu3]} = {[8,109],[12,113]},
		   if (X >= Xd1 andalso X =< Xu1 andalso Y >= Yd1 andalso Y =< Yu1)-> 
%% 				orelse (X >= Xd2 andalso X =< Xu2 andalso Y >= Yd2 andalso Y =< Yu2) 
%% 				orelse (X >= Xd3 andalso X =< Xu3 andalso Y >= Yd3 andalso Y =< Yu3) ->
				  true;
			  true->false
		   end;
	   true->false
	end.

%%出来飞行坐骑任务接口
%% mount_task_change(Player,TaskId)->
%% 	if TaskId == 40173->
%% 		   if Player#player.reg_time < 1326499200 ->
%% 				  lib_mount:add_active_type(Player,[16010]),
%% 				  ok;
%% 			  true->skip
%% 		   end;
%% 	   true->skip
%% 	end.

%%第一个灵兽任务接口
first_pet_out(Status,TaskId)->
	if TaskId =:= 20213->
		   case lib_pet:get_out_pet_id(Status#player.id) of
			   error->
				   Status;
			   PetId->
				   {ok,NewStatus} = pp_pet:handle(41004, Status, [PetId,1]),
				   pp_pet:handle(41008, Status, [Status#player.id]),
				   NewStatus
		   end;
	   true->Status
	end.

%%通知客户端挂机
notice_hooking_mon(Status,Type,MonId)->
	spawn(fun()->
				  case Type of
					  2->
						  case data_agent:mon_get(MonId) of
							  []->skip;
							  Mon->
								  case lists:member(Mon#ets_mon.type, [1,2,6,7]) of
									  true->
										  {ok,BinData} = pt_30:write(30027, [Type,MonId]),
										  lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
									  false->skip
								  end
						  end;
					  1->
						  case lists:member(MonId, [10309,20106,20229,20249,21012]) of
							  true->
								  {ok,BinData} = pt_30:write(30027, [Type,MonId]),
								  lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
							  false->skip
						  end;
					  _->skip
				  end
		  end).

%%test
scene_test(SceneId)->
	case ets:lookup(?ETS_BASE_SCENE, SceneId) of
		[]->null;
		[Scene]->
			Scene#ets_scene.mask
	end.