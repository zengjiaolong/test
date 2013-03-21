-module(pp_mount).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").

%%从物品首次使用用16002,如果从坐骑界面切换用16018
%%坐骑状态切换
handle(16002, PlayerStatus, MountId) ->
	[Res, MountType,NewPlayerStatus] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'changeGoodsMount',PlayerStatus, MountId}),
	[Res, MountType,NewPlayerStatus];

%%从物品首次使用用16002,如果从坐骑界面切换用16018
%%坐骑状态切换
handle(16018, PlayerStatus, [MountId]) when PlayerStatus#player.status == 10 ->
	{ok, BinData} = pt_16:write(16018, [14, MountId, 0, PlayerStatus#player.speed]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
handle(16018, PlayerStatus, [MountId]) ->
	
	%% 战场不可以上坐骑
	case lib_arena:is_arena_scene(PlayerStatus#player.scene) of
		false ->
			case PlayerStatus#player.scene =:= ?SKY_RUSH_SCENE_ID andalso (PlayerStatus#player.carry_mark >= 8 andalso PlayerStatus#player.carry_mark =< 15)of
				false ->
					case lib_scene:is_fst_scene(PlayerStatus#player.scene) of
						false ->
							case lib_scene:is_td_scene(PlayerStatus#player.scene) of
								false ->
									case lib_scene:is_zxt_scene(PlayerStatus#player.scene) of
										false->
											case lib_spring:is_spring_scene(PlayerStatus#player.scene) of
												false ->
													case lib_war:is_fight_scene(PlayerStatus#player.scene)/=true andalso lib_war2:is_fight_scene(PlayerStatus#player.scene)/=true of
														true->
															case PlayerStatus#player.carry_mark =:= 27 of
																false ->
																	case lib_marry:is_wedding_scene(PlayerStatus#player.scene) of
																		false ->
																			case lib_marry:is_love_scene(PlayerStatus#player.scene) of
																				false ->
																					%% 竞技场不能骑坐骑
																					case lib_coliseum:is_coliseum_scene(PlayerStatus#player.scene) of
																						false ->
																							[Res, MountType,NewPlayerStatus] = 
																								mod_mount:change_new_mount_status(PlayerStatus,MountId),
																							%%上下坐骑，修改其自动+经验的定时器(-- by xiaomai)
																							lib_peach:cancel_auto_sit_timer(NewPlayerStatus#player.scene, 
																															NewPlayerStatus#player.x, NewPlayerStatus#player.y, 
																															NewPlayerStatus#player.mount), 
																							{ok, BinData} = pt_16:write(16018, [Res, MountId, MountType,NewPlayerStatus#player.speed]),
																							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
																							{ok, NewPlayerStatus};		
																						true ->
																							{ok, BinData} = pt_16:write(16018, [21, MountId, 0, PlayerStatus#player.speed]),
																							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
																					end;
																				
																				true ->
																					{ok, BinData} = pt_16:write(16018, [20, MountId, 0, PlayerStatus#player.speed]),
																					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
																			end;
																		true ->
																			{ok, BinData} = pt_16:write(16018, [16, MountId, 0, PlayerStatus#player.speed]),
																			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
																	end;
																true->%%您身上有冥王之灵，无法使用坐骑
																	{ok, BinData} = pt_16:write(16018, [15, MountId, 0, PlayerStatus#player.speed]),
																	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
															end;
														false ->
															{ok, BinData} = pt_16:write(16018, [13, MountId, 0, PlayerStatus#player.speed]),
															lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
													end;
												true ->%%温泉里不用使用坐骑
													{ok, BinData} = pt_16:write(16018, [11, MountId, 0, PlayerStatus#player.speed]),
													lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
											end;
										true->
											{ok, BinData} = pt_16:write(16018, [10, MountId, 0, PlayerStatus#player.speed]),
											lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
									end;
								true ->
									{ok, BinData} = pt_16:write(16018, [9, MountId, 0, PlayerStatus#player.speed]),
									lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
							end;
						true ->
							{ok, BinData} = pt_16:write(16018, [7, MountId, 0, PlayerStatus#player.speed]),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
					end;
				true ->%%空岛,不能上坐骑
					{ok, BinData} = pt_16:write(16018, [8, MountId, 0, PlayerStatus#player.speed]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
			end;
		true ->
			{ok, BinData} = pt_16:write(16018, [6, MountId, 0, PlayerStatus#player.speed]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;


%%卸下坐骑
handle(16003,PlayerStatus,_) ->
	[Res,NewPlayerStatus] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
								  {'force_off_mount',PlayerStatus}),
	{ok,BinData} = pt_16:write(16003,[Res,NewPlayerStatus#player.speed]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayerStatus};

%%购买坐骑(1购买成功，2元宝不足，3背包空间不足，4系统繁忙，稍后重试 5数据异常
handle(16010,PlayerStatus,[GoodsId])->
	{Res,NewPlayerStatus} = 
		case lists:member(GoodsId,[16010]) of
			false->{5,PlayerStatus};
			true->
				Gold = mount_price(GoodsId) ,
				case goods_util:is_enough_money(PlayerStatus,Gold,gold) of
					false->{2,PlayerStatus};
					true->
						case gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
						 {'cell_num'})< 1 of
							false->
								case ( catch gen_server:call(PlayerStatus#player.other#player_other.pid_goods, 
								 {'give_goods', PlayerStatus,GoodsId, 1,0})) of
									ok ->
										PlayerStatus1 = lib_goods:cost_money(PlayerStatus,Gold,gold,1601),
										{1,PlayerStatus1};
									_->{4,PlayerStatus}
								end;
							true->{3,PlayerStatus}
						end
				end
						
		end,
	{ok,BinData} = pt_16:write(16010,[Res]),
	lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send,BinData),
	if PlayerStatus =/= NewPlayerStatus ->
		{ok,NewPlayerStatus};
	   true->ok
	end;


%%查看新版坐骑信息
handle(16012, PlayerStatus, MountId) ->
	Mount = mod_mount:get_mount_info(MountId),
	{ok, BinData} = pt_16:write(16012, Mount),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%查看新版坐骑列表
handle(16013, PlayerStatus, _) ->
	MountList = mod_mount:get_all_mount(PlayerStatus#player.id),
	{ok, BinData} = pt_16:write(16013, MountList),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%% 出战坐骑亲密度自动增长
handle(16014, PlayerStatus, [MountId]) ->
	[Res,NewPlayerStatus] = mod_mount:auto_add_close(PlayerStatus,MountId),
	{ok, BinData} = pt_16:write(16014, [Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{ok,NewPlayerStatus};

%%坐骑出战,休息 
%% Type 0为休息 1为出  2坐骑丢弃
handle(16015, PlayerStatus, [MountId,Type]) ->
	[Res,NewPlayerStatus] = mod_mount:change_mount_status(PlayerStatus,MountId,Type),
	{ok, BinData} = pt_16:write(16015, [Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{ok,NewPlayerStatus};

%% 坐骑喂养
handle(16016, PlayerStatus, [MountId, Food_type, GoodsNum]) ->
	[Res,NewPlayerStatus] = mod_mount:feed_mount(PlayerStatus,MountId, Food_type, GoodsNum),
	{ok, BinData} = pt_16:write(16016, [Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{ok,NewPlayerStatus};

%% 坐骑改名
handle(16017, PlayerStatus, [MountId, NewName]) ->
	 [Res,MountId, NewName] = mod_mount:rename_mount(PlayerStatus,MountId, NewName),
	{ok, BinData} = pt_16:write(16017, [Res,MountId, NewName]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%% 坐骑进阶界面信息
handle(16019, PlayerStatus, MountId) ->
	[Res,MountId,MountTypeId,Name,NewStep,NewSpeed,TotalValue,Goods_id,Num,Coin,Luck_val,Max_Luck_val] = mod_mount:get_next_step_info(PlayerStatus,MountId),
	{ok, BinData} = pt_16:write(16019, [Res,MountId,MountTypeId,Name,NewStep,NewSpeed,TotalValue,Goods_id,Num,Coin,Luck_val,Max_Luck_val]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%% 坐骑进阶操作
handle(16020, PlayerStatus, [MountId,Goods_id,Auto_purch]) ->
	[Res,NewPlayer] = mod_mount:oper_step(PlayerStatus,MountId,Goods_id,Auto_purch),
	{ok, BinData} = pt_16:write(16020, [Res,NewPlayer#player.gold,NewPlayer#player.coin,NewPlayer#player.bcoin]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{ok,NewPlayer};

%% 坐骑兽魄驯化界面信息
handle(16021, PlayerStatus, MountId) ->
	[Res,Goods_id,Num,Cost] = mod_mount:get_4sp_info(PlayerStatus,MountId),
	{ok, BinData} = pt_16:write(16021, [Res,Goods_id,Num,Cost]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%坐骑兽魄驯化操作
handle(16022, PlayerStatus, [MountId, Auto_purch]) ->
	[Res,NewPlayer] = mod_mount:oper_4sp(PlayerStatus,MountId,Auto_purch),
	{ok, BinData} = pt_16:write(16022, [Res,NewPlayer#player.gold,NewPlayer#player.coin,NewPlayer#player.bcoin]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{ok,NewPlayer};

%%坐骑猎魂技能列表
handle(16023, PlayerStatus, _) ->
	ResultList = mod_mount:mount_skill_split_list(PlayerStatus#player.id),
	{ok, BinData} = pt_16:write(16023, ResultList),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%坐骑五个按钮信息
handle(16024, PlayerStatus, _) ->
	MountSkillExpInfo = mod_mount:mount_5_btn(PlayerStatus#player.id),
	{ok, BinData} = pt_16:write(16024, [MountSkillExpInfo,PlayerStatus#player.cash]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%设置自动萃取颜色
handle(16025, PlayerStatus, Auto_Color) ->
	Res = mod_mount:auto_step_set(PlayerStatus#player.id,Auto_Color),
	{ok, BinData} = pt_16:write(16025, [Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%点击按钮产生技能按钮顺序从1-5
handle(16026, PlayerStatus, Btn_Order) ->
	[Res,SkillId,Color,Pos,NewPlayer] = mod_mount:general_skill(PlayerStatus,Btn_Order),
	{ok, BinData} = pt_16:write(16026, [Res,SkillId,Color,Pos,NewPlayer#player.gold,NewPlayer#player.coin,NewPlayer#player.bcoin]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{ok,NewPlayer};

%%技能拖动类型(UpDown 1为从上面拉到下面,2从下面拉到上面,3为闲置技能左右拖动坐骑技能不能左右拖动,Type1为技能合并预览，2为正式技能合并
handle(16027, PlayerStatus, [MountId,UpDown,Type,Id1,Id2]) ->
	[Res,Content,NewPlayer] = mod_mount:mount_drag_skill(PlayerStatus,MountId,UpDown,Type,Id1,Id2),
	{ok,BinData} = pt_16:write(16027,[Res,Content]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayer};

%%用元宝激活按钮4
handle(16028, PlayerStatus, []) ->
	[Res,NewPlayer] = mod_mount:active_btn4(PlayerStatus),
	{ok, BinData} = pt_16:write(16028, [Res,NewPlayer#player.gold,NewPlayer#player.coin,NewPlayer#player.bcoin]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{ok,NewPlayer};

%%萃取
handle(16029, PlayerStatus, MountSkillSplitId) ->
	Res = mod_mount:skill_fetch(PlayerStatus,MountSkillSplitId),
	{ok, BinData} = pt_16:write(16029, [Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%一键萃取
handle(16030, PlayerStatus, []) ->
	Res = mod_mount:one_key_skill_fetch(PlayerStatus),
	{ok, BinData} = pt_16:write(16030, [Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%卖出
handle(16031, PlayerStatus, MountSkillSplitId) ->
	[Res,NewPlayer] = mod_mount:skill_sell(PlayerStatus,MountSkillSplitId),
	{ok, BinData} = pt_16:write(16031, [Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{ok,NewPlayer};

%%一键卖出
handle(16032, PlayerStatus, []) ->
	[Res,NewPlayer] = mod_mount:one_key_skill_sell(PlayerStatus),
	{ok, BinData} = pt_16:write(16032, [Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{ok,NewPlayer};

%%一键吞噬
handle(16033, PlayerStatus, []) ->
	Res = mod_mount:one_key_skill_eat(PlayerStatus#player.id),
	{ok, BinData} = pt_16:write(16033, [Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%添加技能经验 坐骑技能位置(1-8)
handle(16034, PlayerStatus, [MountId,Pos]) ->
	[Code,Desc,NewPlayer] = mod_mount:add_skill_exp(PlayerStatus,MountId,Pos),
	{ok, BinData} = pt_16:write(16034, [Code,Desc]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{ok,NewPlayer};

%%坐骑图鉴列表
handle(16035, PlayerStatus, []) ->
	ResultList = mod_mount:get_all_type(PlayerStatus#player.id),
	{ok, BinData} = pt_16:write(16035, ResultList),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%坐骑展示
handle(16037, PlayerStatus, MountId) ->
	Mount = mod_mount:get_mount_rank_info(MountId),
	{ok, BinData} = pt_16:write(16037, Mount),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%一键猎魂
handle(16038, PlayerStatus, []) ->
	[Res,SkillId,_Color,_Pos,NewPlayer] = mod_mount:auto_general_skill(PlayerStatus),
	{ok, BinData} = pt_16:write(16038, [Res,SkillId,NewPlayer#player.gold,NewPlayer#player.coin,NewPlayer#player.bcoin]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	handle(16023, NewPlayer, []),
	handle(16024, NewPlayer, []), 
	{ok,NewPlayer};

%% 坐骑图鉴切换
handle(16039, PlayerStatus, [MountId,GoodsTypeId])  ->
	[Res,GoodsTypeId,NewPlayer] = mod_mount:change_active_type(PlayerStatus,MountId,GoodsTypeId),
	{ok, BinData} = pt_16:write(16039, [Res,GoodsTypeId]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{ok,NewPlayer};

%% 坐骑闲置技能查看
handle(16040, PlayerStatus, [MountSkillSplitId])  ->
	MountSkillSplitInfo = mod_mount:get_mount_skill_split_info(MountSkillSplitId),
	{ok, BinData} = pt_16:write(16040, MountSkillSplitInfo),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%斗兽面板
handle(16042, PlayerStatus, [])  ->
	%%?DEBUG("into 16042.. begin",[]),
	if PlayerStatus#player.lv < 35 ->
		   %%?DEBUG("into 16042.. lv < 35",[]),
		   {ok,BinData} = pt_16:write(16042,[2,{},{},[]]),
		   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
	   true ->
		   case lib_mount:get_out_mount(PlayerStatus#player.id) of
			   [] ->
				   %%?DEBUG("into 16042.. get_out_mount = []",[]),
				   {ok,BinData} = pt_16:write(16042,[4,{},{},[]]),
				   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
			   Mount ->
				   %%?DEBUG("into 16042.. get_mod_mount_arena_pid = []",[]),
				   Pid = mod_mount_arena:get_mod_mount_arena_pid(),
				   gen_server:cast(Pid, {'OPEN_MOUNT_ARENA_PANEL',PlayerStatus, Mount})
		   end
	end;

%%斗兽竞技(参数：自己坐骑ID，对方坐骑ID)
handle(16044, PlayerStatus, [MyId,EnemyId])  ->
	%%要对客户端发送过来的ID做严格判断
	case ets:lookup(?ETS_MOUNT, MyId) of
		[] ->
			{ok,Bin} = pt_16:write(16044,[3,0,"","",0,0,"","",0,[],0,0]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, Bin);
		[M|_Rets]->
			case M#ets_mount.status of
				1 ->
					Pid = mod_mount_arena:get_mod_mount_arena_pid(),
					Speed = lib_mount:get_mount_speed(PlayerStatus#player.id),
					%%斗兽任务接口
					lib_task:event(mount_arena, null, PlayerStatus),
					Pid ! {'MOUNT_BATTLE',PlayerStatus#player.other#player_other.pid_send, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.nickname, PlayerStatus#player.vip, Speed, M, EnemyId};
				_ ->
					{ok,Bin} = pt_16:write(16044,[2,0,"","",0,0,"","",0,[],0,0]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, Bin)
			end
	end;
								   

%%斗兽竞技榜
handle(16045, PlayerStatus, [])  ->
	Pid = mod_mount_arena:get_mod_mount_arena_pid(),
	gen_server:cast(Pid, {'OPEN_ARENA_RANK',PlayerStatus#player.other#player_other.pid_send});

%%增加挑战次数
handle(16046, PlayerStatus, [])  ->
	Pid = mod_mount_arena:get_mod_mount_arena_pid(),
	gen_server:cast(Pid, {'ADD_CGE_TIMES',PlayerStatus});

%%请求战报
handle(16047, PlayerStatus, [BattleId]) ->
	Pid = mod_mount_arena:get_mod_mount_arena_pid(),
	%%?DEBUG("pp_mounts 16047 in,  Pid = ~p, BattleId = ~p",[Pid,BattleId]),
	Pid ! {'REQUEST_DEMO',PlayerStatus#player.other#player_other.pid_send, BattleId};

%%领取奖励
handle(16048, PlayerStatus, []) ->
	case lib_mount:get_out_mount(PlayerStatus#player.id) of
		[] ->
			%%没有出战坐骑
			{ok,BinData} = pt_16:write(16042,[4,{},{},[]]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		M ->
			Pid = mod_mount_arena:get_mod_mount_arena_pid(),
			Pid ! {'GET_AWRD',PlayerStatus,M}
	end;

handle(_Cmd, _Status, _Data) ->
    %%?DEBUG("pp_mount no match", []),
    {error, "pp_mount no match"}.

%%坐骑价格
mount_price(GoodsId)->
	case GoodsId of
		16010->688;
		_->999999999
	end.