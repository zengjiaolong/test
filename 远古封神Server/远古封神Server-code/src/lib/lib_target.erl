%% Author: Administrator
%% Created: 2012-4-23
%% Description: TODO: Add description to lib_target
-module(lib_target).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%%
%% Exported Functions
%%
-compile(export_all).

%%
%% API Functions
%%

%%玩家登陆，加载目标奖励数据
init_target(Status)->
	case Status#player.target_gift of
		0->
			PlayerId = Status#player.id,
			case db_agent:select_target(PlayerId) of 
				[]->
					%插入新玩家数据
					Target_gift = #ets_target{
											  pid = PlayerId
											 },
					Id = db_agent:new_target(Target_gift),
					ets:insert(?ETS_TARGET,Target_gift#ets_target{id=Id});
				Result ->	
					EtsData = list_to_tuple([ets_target|Result]),
					ets:insert(?ETS_TARGET,EtsData)
			end;
		_->
			PlayerId = Status#player.id,
			case db_agent:select_target(PlayerId) of 
				[]->
					%插入新玩家数据
					Target_gift = #ets_target{
											  pid = PlayerId
											 },
					Id = db_agent:new_target(Target_gift),
					NewTarget=Target_gift#ets_target{id=Id},
					old_data(NewTarget);
				Result->
					EtsData = list_to_tuple([ets_target|Result]),
					ets:insert(?ETS_TARGET,EtsData)
			end
	end.

%%处理旧的数据
old_data(Target)->
	NewTarget = Target#ets_target{
								  a_pet=1,
								  out_mount=1,
								  meridian_uplv=1,
								  master=1,
								  lv_20=1,
								  friend=1,
								  lv_30=1,
								  dungeon_25=1,
								  pet_lv_5=1,
								  battle_value_850=1,
								  arena=1,
								  mount_step_2=1,
								  dungeon_35=1,
								  mount_3=1,
								  lg20_one=1,
								  pet_lv_15=1,
								  fst_6=1,
								  td_20=1,
								  deputy_klj=1,
								  mount_gold=1,
								  pet_a35_g30=1,
								  dungeon_45=1
								 },
	ets:insert(?ETS_TARGET, NewTarget),
	Value = [{a_pet,1},{out_mount,1},{master,1},{lv_20,1},{meridian_uplv,1},
			 {friend,1},{lv_30,1},{dungeon_25,1},{pet_lv_5,1},{battle_value_850,1},
			 {arena,1},{mount_step_2,1},{dungeon_35,1},{mount_3,1},{lg20_one,1},{pet_lv_15,1},
			 {fst_6,1},{td_20,1},{deputy_klj,1},{mount_gold,1},{pet_a35_g30,1},{dungeon_45,1}],
	db_agent:update_target_old(Value,[{id,Target#ets_target.id}]),
	ok.

%%玩家下线
offline(PlayerId)->
	ets:delete(?ETS_TARGET, PlayerId).

check_target_state(PlayerStatus)->
	Date =[[1,1],[1,2],[1,3],[1,4],[1,5],
		   [21,1],[21,2],[21,3],[21,4],[21,5],
		   [31,1],[31,2],[31,3],[31,3],[31,5],[31,6],
		   [41,1],[41,2],[41,3],[41,4],[41,5],[41,6],
		   [51,1],[51,2],[51,3],[51,4],[51,5],[51,6],
		   [61,1],[61,2],[61,3],[61,4],[61,5],[61,6],
		   [71,1],[41,2],[71,3],[71,4],[71,5],[71,6]
		  ],
	case lib_target:check_target_state(PlayerStatus, Date,finish) of	
		{true,Lv,Rank} ->
			{ok,BinData} = pt_30:write(30074, [Lv,Rank]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			ok;
		Other -> Other
	end.

%%检查目标是否可领取
check_target_state(_PlayerStatus,[],State)->
	State;
check_target_state(PlayerStatus,[[Lv,Rank]|Date],_State)->
%% 	case PlayerStatus#player.target_gift of
%% 		0-> 
			case check_lv(PlayerStatus#player.lv,Lv) of
				true->
					Type = id_to_type(Lv,Rank),
					%%检查是否已经领取
					[Target] = select_target(PlayerStatus#player.id),
					case check_target_finish(Target,Type) of
						false ->
							%%检查目标是否达到
							case target(Type,PlayerStatus) of
								ok ->
									{true,Lv,Rank};
								_->
									check_target_state(PlayerStatus,Date,ok)
							end;
						true->
							check_target_state(PlayerStatus,Date,ok)
					end;
				false->
					%%等级不足
					check_target_state(PlayerStatus,[],ok)
%% 			end;
%% 		_->
%% 			check_target_state(PlayerStatus,[],finish)
	end.

%%获取玩家目标奖励信息
check_target_info(Status)->
	case select_target(Status#player.id) of
		[]->
			{ok,Status,lv_to_rank(Status#player.lv),[[1,1,1,1,1],
													 [1,1,1,1,1],
													 [1,1,1,1,1,1],
													 [1,1,1,1,1,1],
													 [1,1,1,1,1,1],
													 [1,1,1,1,1,1],
													 [1,1,1,1,1,1]]};
		[Traget]->
			{ok,Status,lv_to_rank(Status#player.lv),[[Traget#ets_target.a_pet,Traget#ets_target.out_mount,Traget#ets_target.meridian_uplv,Traget#ets_target.master,Traget#ets_target.lv_20],
													 [Traget#ets_target.friend,Traget#ets_target.lv_30,Traget#ets_target.dungeon_25,Traget#ets_target.pet_lv_5,Traget#ets_target.battle_value_850],
													 [Traget#ets_target.arena,Traget#ets_target.mount_step_2,Traget#ets_target.dungeon_35,Traget#ets_target.mount_3,Traget#ets_target.lg20_one,Traget#ets_target.pet_lv_15],
													 [Traget#ets_target.fst_6,Traget#ets_target.td_20,Traget#ets_target.deputy_klj,Traget#ets_target.mount_gold,Traget#ets_target.pet_a35_g30,Traget#ets_target.dungeon_45],
													 [Traget#ets_target.fst_14,Traget#ets_target.deputy_green,Traget#ets_target.step_5,Traget#ets_target.qi_lv4_lg40,Traget#ets_target.weapon_7,Traget#ets_target.dungeon_55],
													 [Traget#ets_target.zxt_14,Traget#ets_target.td_70,Traget#ets_target.pet_a45_g40,Traget#ets_target.mount_step_3,Traget#ets_target.deputy_nws,Traget#ets_target.lg_50_all],
													 [Traget#ets_target.step_7,Traget#ets_target.deputy_snd,Traget#ets_target.pet_a55_g50,Traget#ets_target.zxt_20,Traget#ets_target.battle_value_15000,Traget#ets_target.mount_step_4]]}
	end.

%%领取目标奖励(1领取成功，2没有目标奖励可领取，3等级不足，不能领取,4数据异常,5背包空间不足，不能领取,6系统繁忙，稍后领取)
%% 通关雷公殿dungeon_25
%% 通关狐狸洞dungeon_35
%% 通关封神台6层fst_6
%% 击退镇妖台20波怪物td_20
%% 通关河神殿dungeon_45
%% 通关封神台14层fst_14
%% 通关蚩尤墓dungeon_55
%% 通关诛仙台14层zxt_14
%% 击退单人镇妖第70波怪物td_70
%% 通关诛仙台zxt_20
get_target_award(Status,Lv1,Rank)->
	Lv= rank_to_lv(Lv1),
%% 	case Status#player.target_gift /=0 of
%% 		true->[Status,2];
%% 		false->
			case select_target(Status#player.id) of
				[]->[Status,4];
				[Target]->
					Type = id_to_type(Lv,Rank),
					case check_target_finish(Target,Type) of
						true->[Status,2];
						false->
							case check_lv(Status#player.lv,Lv) of
								false->[Status,3];
								true->
									case target(Type,Status) of
										ok->
											{Goods,Cash} = goods_award(Lv,Rank),
											case gen_server:call(Status#player.other#player_other.pid_goods,
																 {'cell_num'})<length(Goods) of
												false->
													case add_target_award(Status,Goods) of
														{ok,NewStatus}->
															NewStatus1 = add_cash(NewStatus,Cash),
															update_target_state(Target,Type),
															spawn(fun()->catch(db_agent:log_target_gift(NewStatus1#player.id,Lv,Rank,Cash,
																										util:term_to_string(Goods),util:unixtime()))end),
															spawn(fun()->check_target_state(NewStatus)end),
															[NewStatus1,1];
														_->
															[Status,6]
													end;
												true->[Status,5]
											end;
										Error->
											[Status,Error]
									end
							end
					end
%% 			end
	end.
%%
%% Local Functions
%%
%%选择目标
select_target(PlayerId)->
	ets:lookup(?ETS_TARGET, PlayerId).
%%更新目标
update_target(Target)->
	ets:insert(?ETS_TARGET, Target).

%%检查目标是否能完成
check_target_finish(Target,Type)->
	case Type of
		a_pet->Target#ets_target.a_pet==1;
		out_mount->Target#ets_target.out_mount==1;
		meridian_uplv->Target#ets_target.meridian_uplv==1;
		master -> Target#ets_target.master==1;
		lv_20->Target#ets_target.lv_20==1;
		friend->Target#ets_target.friend==1;
		lv_30->Target#ets_target.lv_30==1;
		dungeon_25->Target#ets_target.dungeon_25==1;
		pet_lv_5->Target#ets_target.pet_lv_5==1;
		battle_value_850->Target#ets_target.battle_value_850==1;
		arena->Target#ets_target.arena==1;
		mount_step_2->Target#ets_target.mount_step_2==1;
		dungeon_35->Target#ets_target.dungeon_35==1;
		mount_3->Target#ets_target.mount_3==1;
		lg20_one->Target#ets_target.lg20_one==1;
		pet_lv_15->Target#ets_target.pet_lv_15==1;
		fst_6->Target#ets_target.fst_6==1;
		td_20->Target#ets_target.td_20==1;
		deputy_klj->Target#ets_target.deputy_klj==1;
		mount_gold->Target#ets_target.mount_gold==1;
		pet_a35_g30->Target#ets_target.pet_a35_g30==1;
		dungeon_45->Target#ets_target.dungeon_45==1;
		fst_14->Target#ets_target.fst_14==1;
		deputy_green->Target#ets_target.deputy_green==1;
		step_5->Target#ets_target.step_5==1;
		qi_lv4_lg40->Target#ets_target.qi_lv4_lg40==1;
		weapon_7->Target#ets_target.weapon_7==1;
		dungeon_55 ->Target#ets_target.dungeon_55==1;
		zxt_14->Target#ets_target.zxt_14==1;
		td_70->Target#ets_target.td_70==1;
		pet_a45_g40->Target#ets_target.pet_a45_g40==1;
		mount_step_3->Target#ets_target.mount_step_3==1;
		deputy_nws->Target#ets_target.deputy_nws==1;
		lg_50_all->Target#ets_target.lg_50_all==1;
		step_7->Target#ets_target.step_7==1;
		deputy_snd->Target#ets_target.deputy_snd==1;
		pet_a55_g50->Target#ets_target.pet_a55_g50==1;
		zxt_20->Target#ets_target.zxt_20==1;
		battle_value_15000->Target#ets_target.battle_value_15000==1;
		_->Target#ets_target.mount_step_4==1
	end.

%%检查可领取等级
check_lv(Lv,LvNeed)->
	Lv>=LvNeed.

%%目标检查

%%10没有灵兽，不能领取
target(a_pet,Status)->
	case lib_pet:get_all_pet(Status#player.id) of
		[]->10;
		_->ok
	end;
%%11坐骑没有出战，不能领取
target(out_mount,Status)->
	case lib_mount:get_out_mount(Status#player.id) of
		[]->11; 
		_->ok
	end;
%%12没有修炼过经脉，不能领取
target(meridian_uplv,Status)->
	case lib_meridian:get_player_meridian_info(Status#player.id) of
		[]->4;
		[Mer]->
			if Mer#ets_meridian.meridian_uplevel_typeId /=0 ->ok;
			   true->
				   {ok,LvBag,_,_} = lib_meridian:check_meridian_info_all(null,0,Mer),
				   case lists:all(fun(M)-> M>=0 end,LvBag) of
					   true->12;
					   false->ok
				   end
			end
	end;
%%13没有拜师或者收徒，不能领取
target(master,Status)->
	case mod_master_apprentice:get_own_master_id(Status#player.id)=:=0 of
		false->
			ok;
		true->
			case mod_master_apprentice:get_my_apprentice_info_page(Status#player.id) of
				[]->
					13;
				_->
					ok
			end
	end;

%%14等级不足20，不能领取
target(lv_20,Status)->
	case Status#player.lv>=20 of 
		true->ok;
		false->14
	end;

%%15你没有任何的好友，不能领取
target(friend,Status)->
	[NumA, NumB] = db_agent:relationship_get_fri_count(Status#player.id),
	Na = 
		case NumA of
			[] -> 0;
			[N] -> N
		end,
	Nb = 
		case NumB of
			[] -> 0;
			[N1] -> N1
		end,
	case Na + Nb>0 of
		true->ok;
		false->15
	end;

%%16等级不足30，不能领取
target(lv_30,Status)->
	case Status#player.lv >= 30 of 
		true->ok;
		false->16
	end;

%%17没有通关雷公殿，不能领取
target(dungeon_25,Status)->
	case lib_achieve:check_ach_foryg_target(Status#player.id, dungeon_25) of
		true->ok;
		false->
			17
	end;

%%18灵兽等级不足5级，不能领取
target(pet_lv_5,Status)->
	case lib_target_gift:get_pet_max_lv(Status#player.id)>=5 of
		true->ok;
		false->18
	end;

%%19您当前的战斗力不足850，不能领取
target(battle_value_850,Status)->
	case lib_player:count_value(Status#player.other#player_other.batt_value) >= 850 of
		true->ok;
		false-> 19
	end;

%%20你还没有参加过远古战场，不能领取
target(arena,Status)->
	case db_agent:check_task_by_id(Status#player.id,[80002,80003,80004,80005,80006]) of
		[]->20;
		null->20;
		_->ok
	end;

%%21你还没有拥有2介以上的坐骑，不能领取
target(mount_step_2,Status)->
	case lib_mount:get_all_mount(Status#player.id) of
		[]->21;
		MountInfo->
			case lists:max([M#ets_mount.step||M<-MountInfo])>= 2 of
				true->ok;
				false->21
			end
	end;

%%22您还没有通关狐狸洞，不能领取
target(dungeon_35,Status)->
	case lib_achieve:check_ach_foryg_target(Status#player.id, dungeon_35) of
		true->ok;
		false->
			22
	end;

%%23坐骑+3
target(mount_3,Status)->
	case lib_mount:get_all_mount(Status#player.id) of
		[]->23;
		MountInfo->
			case lists:max([M#ets_mount.stren||M<-MountInfo])>= 3 of
				true->ok;
				false->23
			end
	end;

%%24您当前经脉灵根没有达到20以上的，不能领取
target(lg20_one,Status)->
	case lib_meridian:get_player_meridian_info(Status#player.id) of
		[]->4;
		[Mer]->
			{ok,_,LG,_} = lib_meridian:check_meridian_info_all(null,0,Mer),
			case length([Lg||Lg<-LG,Lg>=20])>=1 of
				true->ok;
				false->24
			end
	end;

%%25您还没拥有等级15以上的灵兽，不能领取
target(pet_lv_15,Status)->
	case lib_target_gift:get_pet_max_lv(Status#player.id)>=15 of
		true->ok;
		false->25
	end;

%%26您还没有通关封神台6层，不能领取
target(fst_6,Status)->
	case lib_achieve:check_ach_foryg_target(Status#player.id, fst_6) of
		true->ok;
		false->
			26
	end;

%%27您还没有击退镇妖台20波怪物，不能领取
target(td_20,Status)->
	case lib_achieve:check_ach_foryg_target(Status#player.id, td_20) of
		true->ok;
		false->
			27
	end;

%%28您还没拥有昆仑镜以上的神器，不能领取
target(deputy_klj,Status)->
	Pattern = #ets_deputy_equip{pid = Status#player.id , _='_'},
	case goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern) of
		[]-> 28;
		DeputyInfo->
			case is_record(DeputyInfo,ets_deputy_equip) of
				true->
					case DeputyInfo#ets_deputy_equip.prof_lv >= 2 of 
						true->ok;
						false->28
					end;
				false->28
			end
	end;

%%29你还没有拥有优秀品质的坐骑，不能领取
target(mount_gold,Status)->
	case lib_mount:get_all_mount(Status#player.id) of
		[]->23;
		MountInfo->
			case lists:max([M#ets_mount.color||M<-MountInfo])>= 2 of
				true->ok;
				false->29
			end
	end;

%%30您还没拥有资质35以上的灵兽；31您还没拥有成长30以上的灵兽
target(pet_a35_g30,Status)->
	case lib_pet:get_all_pet(Status#player.id) of
		[]->30;
		Pet->
			case lists:max([P#ets_pet.aptitude||P<-Pet]) >= 35 of
				false->30;
				true->
					case lists:max([P#ets_pet.grow||P<-Pet]) >= 30 of
						true->ok;
						false->31
					end
			end
	end;

%%32您还没有通关河神殿，不能领取
target(dungeon_45,Status)->
	case lib_achieve:check_ach_foryg_target(Status#player.id, dungeon_45) of
		true->ok;
		false->
			32
	end;


%%33您还没有通关封神台14层，不能领取
target(fst_14,Status)->
	case lib_achieve:check_ach_foryg_target(Status#player.id, fst_14) of
		true->ok;
		false->
			33
	end;


%%34您还没有拥有绿色以上的神器，不能领取
target(deputy_green,Status)->
	Pattern = #ets_deputy_equip{pid = Status#player.id , _='_'},
	case goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern) of
		[]-> 34;
		D->
			case is_record(D,ets_deputy_equip) of
				true->
					case D#ets_deputy_equip.color >=1 of
						true->ok;
						false->34
					end;
				false->34
			end
	end;

%%35您的全身装备没有强化+5以上，不能领取
target(step_5,Status)->
	case Status#player.other#player_other.stren >= 5 of
		true->ok;
		false->35
	end;

%%36您的奇脉修炼等级未达4级以上，不能领取； 37您的奇脉灵根未达40以上，不能领取
target(qi_lv4_lg40,Status)->
	case lib_meridian:get_player_meridian_info(Status#player.id) of
		[]->4;
		[Mer]->
			case Mer#ets_meridian.mer_qi>=4 of
				false->36;
				true->
					case Mer#ets_meridian.mer_qi_linggen >= 50 of
						true-> ok;
						false->37
					end
			end
	end;

%%38您身上的法宝强化等级未达+7以上，不能领取
target(weapon_7,Status)->
	case lib_target_gift:get_equipment_stren_info(Status#player.id, Status#player.career, weapon) >= 7 of
		true->ok;
		false->38
	end;

%%39您还没有通关蚩尤墓，不能领取
target(dungeon_55,Status)->
	case lib_achieve:check_ach_foryg_target(Status#player.id, dungeon_55) of
		true->ok;
		false->
			39
	end;


%%40您还没有通关诛仙台14层，不能领取
target(zxt_14,Status)->
	case lib_achieve:check_ach_foryg_target(Status#player.id, zxt_14) of
		true->ok;
		false->
			40
	end;


%%41您还没有击退单人镇妖第70波怪物，不能领取
target(td_70,Status)->
	case lib_achieve:check_ach_foryg_target(Status#player.id, td_70) of
		true->ok;
		false->
			41
	end;

%%42您还没拥有资质45以上的灵兽；43您还没拥有成长40以上的灵兽
target(pet_a45_g40,Status)->
	case lib_pet:get_all_pet(Status#player.id) of
		[]->42;
		Pet->
			case lists:max([P#ets_pet.aptitude||P<-Pet]) >= 55 of
				false->42;
				true->
					case lists:max([P#ets_pet.grow||P<-Pet]) >= 50 of
						true->ok;
						false->43
					end
			end
	end;

%%44您还没有拥有3介以上的坐骑，不能领取,54您当前没有坐骑的品质是出众以上的，不能领取
target(mount_step_3,Status)->
	case lib_mount:get_all_mount(Status#player.id) of
		[]->21;
		MountInfo->
			case lists:max([M#ets_mount.step||M<-MountInfo])>= 3 of
				true->
					case lists:max([M#ets_mount.color||M<-MountInfo])>= 3 of
						true->ok;
						false->54
					end;
				false->44
			end
	end;

%%45您还没拥有女娲石以上的神器，不能领取
target(deputy_nws,Status)->
	Pattern = #ets_deputy_equip{pid = Status#player.id , _='_'},
	case goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern) of
		[]-> 45;
		D->
			case is_record(D,ets_deputy_equip) of
				true->
					case D#ets_deputy_equip.prof_lv >= 3 of 
						true->ok;
						false->45
					end;
				false->45
			end
	end;

%%46您全身的经脉灵根未达50以上，不能领取
target(lg_50_all,Status)->
	case lib_meridian:get_player_meridian_info(Status#player.id) of
		[]->4;
		[Mer]->
			{ok,_,LG,_} = lib_meridian:check_meridian_info_all(null,0,Mer),
			case length([Lg||Lg<-LG,Lg>=50])>=8 of
				true->ok;
				false->46
			end
	end;

%%47您的全身装备没有强化+7以上，不能领取
target(step_7,Status)->
	case Status#player.other#player_other.stren >= 7 of
		true->ok;
		false->47
	end;


%%48您还没拥有神农鼎以上的神器，不能领取
target(deputy_snd,Status)->
	Pattern = #ets_deputy_equip{pid = Status#player.id , _='_'},
	case goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern) of
		[]-> 48;
		D->
			case is_record(D,ets_deputy_equip) of
				true->
					case D#ets_deputy_equip.prof_lv >= 4 of 
						true->ok;
						false->48
					end;
				false->48
			end
	end;

%%49您还没拥有资质55以上的灵兽；50您还没拥有成长50以上的灵兽
target(pet_a55_g50,Status)->
	case lib_pet:get_all_pet(Status#player.id) of
		[]->49;
		Pet->
			case lists:max([P#ets_pet.aptitude||P<-Pet]) >= 65 of
				false->49;
				true->
					case lists:max([P#ets_pet.grow||P<-Pet]) >= 60 of
						true->ok;
						false->50
					end
			end
	end;

%%51您还没有通关诛仙台，不能领取
target(zxt_20,Status)->
	case lib_achieve:check_ach_foryg_target(Status#player.id, zxt_20) of
		true->ok;
		false->
			51
	end;

%%52您当前的战斗力未到15000以上，不能领取
target(battle_value_15000,Status)->
	case lib_player:count_value(Status#player.other#player_other.batt_value) >= 15000 of
		true->ok;
		false-> 52
	end;

%%53您当前没有4介以上的坐骑，不能领取,;55您当前没有坐骑的品质是脱俗以上的，不能领取
target(mount_step_4,Status)->
	case lib_mount:get_all_mount(Status#player.id) of
		[]->53;
		MountInfo->
			case lists:max([M#ets_mount.step||M<-MountInfo])>= 4 of
				true->
					case lists:max([M#ets_mount.color||M<-MountInfo])>= 4 of
						true->ok;
						false->55
					end;
				false->53
			end
	end;

target(_,_)->
	4.

%%添加奖励物品
add_target_award(Status,[])->
	{ok,Status};
add_target_award(Status,[Gift|T])->
	{GoodsId,GoodsNum} = Gift,
	case (catch gen_server:call(Status#player.other#player_other.pid_goods, {'give_goods', Status, GoodsId, GoodsNum,2}))of
		ok->add_target_award(Status,T);
		_->{error,Status}
	end.

%%增加礼券
add_cash(Status,0)->
	Status;
add_cash(Status,Cash)->
	db_agent:add_money(Status,Cash,cash,3001),
	NewCash = Status#player.cash+Cash,
	Status#player{cash=NewCash}.

update_target_state(Target,Type)->
	db_agent:update_target(Target#ets_target.pid,Type),
	NewTarget = 
		case Type of
			a_pet->Target#ets_target{a_pet=1};
			out_mount->Target#ets_target{out_mount=1};
			meridian_uplv->Target#ets_target{meridian_uplv=1};
			lv_20->Target#ets_target{lv_20=1};
			friend->Target#ets_target{friend=1};
			master -> Target#ets_target{master=1};
			lv_30->Target#ets_target{lv_30=1};
			dungeon_25->Target#ets_target{dungeon_25=1};
			pet_lv_5->Target#ets_target{pet_lv_5=1};
			battle_value_850->Target#ets_target{battle_value_850=1};
			arena->Target#ets_target{arena=1};
			mount_step_2->Target#ets_target{mount_step_2=1};
			dungeon_35->Target#ets_target{dungeon_35=1};
			mount_3->Target#ets_target{mount_3=1};
			lg20_one->Target#ets_target{lg20_one=1};
			pet_lv_15->Target#ets_target{pet_lv_15=1};
			fst_6->Target#ets_target{fst_6=1};
			td_20->Target#ets_target{td_20=1};
			deputy_klj->Target#ets_target{deputy_klj=1};
			mount_gold->Target#ets_target{mount_gold=1};
			pet_a35_g30->Target#ets_target{pet_a35_g30=1};
			dungeon_45->Target#ets_target{dungeon_45=1};
			fst_14->Target#ets_target{fst_14=1};
			deputy_green->Target#ets_target{deputy_green=1};
			step_5->Target#ets_target{step_5=1};
			qi_lv4_lg40->Target#ets_target{qi_lv4_lg40=1};
			weapon_7->Target#ets_target{weapon_7=1};
			dungeon_55 ->Target#ets_target{dungeon_55=1};
			zxt_14->Target#ets_target{zxt_14=1};
			td_70->Target#ets_target{td_70=1};
			pet_a45_g40->Target#ets_target{pet_a45_g40=1};
			mount_step_3->Target#ets_target{mount_step_3=1};
			deputy_nws->Target#ets_target{deputy_nws=1};
			lg_50_all->Target#ets_target{lg_50_all=1};
			step_7->Target#ets_target{step_7=1};
			deputy_snd->Target#ets_target{deputy_snd=1};
			pet_a55_g50->Target#ets_target{pet_a55_g50=1};
			zxt_20->Target#ets_target{zxt_20=1};
			battle_value_15000->Target#ets_target{battle_value_15000=1};
			_->Target#ets_target{mount_step_4=1}
		end,
	update_target(NewTarget),
	ok.

lv_to_rank(Lv)->
	if Lv=< 20-> 1;
	   Lv =< 30-> 2;
	   Lv =< 40-> 3;
	   Lv =< 50-> 4;
	   Lv =< 60-> 5;
	   Lv =< 70-> 6;
	   true->71
	end.

rank_to_lv(Rank)->
	case Rank of
		1->1;
		2->21;
		3->31;
		4->41;
		5->51;
		6->61;
		_->71
	end.

%%类型转换
id_to_type(Lv,Id)->
	case  Lv of
		1->
			case Id of
				1->a_pet;
				2->out_mount;
				3->meridian_uplv;
				4->master;
				_5->lv_20
			end;
		21 ->
			case Id of
				1->friend;
				2->lv_30;
				3->dungeon_25;
				4->pet_lv_5;
				_5->battle_value_850
			end;
		31 ->
			case Id of
				1->arena;
				2->mount_step_2;
				3->dungeon_35;
				4->mount_3;
				5->lg20_one;
				_->pet_lv_15
			end;
		41 ->
			case Id of
				1->fst_6;
				2->td_20;
				3->deputy_klj;
				4->mount_gold;
				5->pet_a35_g30;
				_->dungeon_45
			end;
		51 -> case Id of
				  1->fst_14;
				  2->deputy_green;
				  3->step_5;
				  4->qi_lv4_lg40;
				  5->weapon_7;
				  _->dungeon_55
			  end;
		61 ->
			case Id of
				1->zxt_14;
				2->td_70;
				3->pet_a45_g40;
				4->mount_step_3;
				5->deputy_nws;
				_->lg_50_all
			end;
		_->
			case Id of
				1->step_7;
				2->deputy_snd;
				3->pet_a55_g50;
				4->zxt_20;
				5->battle_value_15000;
				_->mount_step_4
			end
	end.


%%物品奖励
goods_award(Lv,Rank)->
	case Lv of
		1->
			case Rank of
				1->{[{24000,5}],10};
				2->{[{28201,5}],10};
				3->{[{22000,1}],10};
				4->{[{28201,5}],10};
				_5->{[{24000,5}],10}
			end;
		21->
			case Rank of
				1->{[{21100,3}],15};
				2->{[{21200,3}],15};
				3->{[{23403,3}],15};
				4->{[{24400,1}],15};
				_5->{[{23006,2},{23107,1}],15}
			end;
		31->
			case Rank of
				1->{[{21100,3},{21200,3}],20};
				2->{[{24822,10},{24823,10}],20};
				3->{[{21320,1}],20};
				4->{[{21200,3}],20};
				5->{[{22000,2}],20};
				_6->{[{24100,1},{24000,10}],20}
			end;
		41->
			case Rank of
				1->{[{21500,2}],30};
				2->{[{21700,1}],30};
				3->{[{32027,10},{32028,10}],30};
				4->{[{24820,1},{24821,1}],30};
				5->{[{24400,2},{24104,1}],30};
				_6->{[{21360,1}],30}
			end;
		51->
			case Rank of
				1->{[{21501,1}],50};
				2->{[{32021,10},{32022,10}],50};
				3->{[{20300,5},{20301,1}],50};
				4->{[{22000,1},{22007,1}],50};
				5->{[{21320,1},{21201,3}],50};
				_6->{[{21330,1},{21002,1}],50}
			end;
		61->
			case Rank of
				1->{[{21501,2}],70};
				2->{[{21701,2}],70};
				3->{[{24400,4},{24104,2}],70};
				4->{[{24823,20}],70};
				5->{[{32028,20}],70};
				_6->{[{22000,3},{22007,1}],70}
			end;
		_->
			case Rank of
				1->{[{20300,10},{20302,1}],100};
				2->{[{32028,30}],100};
				3->{[{24401,2},{24105,1}],100};
				4->{[{21502,1}],100};
				5->{[{24400,3},{24821,1},{22000,3}],100};
				_6->{[{24823,30}],100}
			end
	end.

cmd_finish_target(Status)->
	case select_target(Status#player.id) of 
		[]->skip;
		[_Target]->
			ets:delete(?ETS_TARGET, Status#player.id),
			?DB_MODULE:delete(target,[{pid,Status#player.id}]),
			ValueList = [{target_gift,1}],
			WhereList = [{id, Status#player.id}],
    		db_agent:mm_update_player_info(ValueList, WhereList),
			gen_server:cast(Status#player.other#player_other.pid, 
							{'SET_PLAYER', [{target_gift,1}
										   ]}),
			ok
	end.