%%%--------------------------------------
%%% @Module  : lib_mount
%%% @Author  : ygzj
%%% @Created : 2011.12.23
%%% @Description : 坐骑信息
%%%--------------------------------------
-module(lib_mount).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-compile(export_all).

%%坐骑最大数
-define(MAX_MOUNT,10).
%%闲置技能最大数
-define(MAX_MOUNT_SKILL_SPLIT,16).

%%查询玩家拥有最多的坐骑数
get_max_count() ->
	?MAX_MOUNT.

%%最多的闲置技能数
get_max_mount_skill_split() ->
	?MAX_MOUNT_SKILL_SPLIT.

init_mount(PlayerId) ->
	load_all_mount(PlayerId),
	load_mount_skill_exp(PlayerId),
	load_all_mount_skill_split(PlayerId).

role_logout(PlayerId) ->
    %% 删除所有缓存宠物
	%%保存数据库
	Mount = get_out_mount(PlayerId),
	if Mount =/= [] ->
		   spawn(fun()->db_agent:update_mount([{close,Mount#ets_mount.close},{level,Mount#ets_mount.level},{exp,Mount#ets_mount.exp}], [{id,Mount#ets_mount.id}])end);
	   true ->
		   skip
	end,	
    delete_all_mount(PlayerId),
	delete_all_mount_skill_split(PlayerId),
	delete_mount_skill_exp(PlayerId).
	
load_all_mount(PlayerId) ->
	MountList = db_agent:select_all_mount(PlayerId),
	lists:map(fun(MountInfo)-> load_mount_into_ets(MountInfo) end,MountList).

load_mount_skill_exp(PlayerId) ->
	MountSkillExpList = db_agent:select_mount_skill_exp(PlayerId),
	if 
		%%如果没有数据就新增一条
		MountSkillExpList == [] ->
			 Id = db_agent:save_mount_skill_exp(PlayerId,0,0,1,0,0,0,0,0,0,"[]"),
			 NewMountSkillExp = #ets_mount_skill_exp{
							  id = Id,
							  player_id = PlayerId,
							  total_exp = 0,
							  auto_step = 1,
							  btn_1 = 1,
							  btn_2 = 0,
							  btn_3 = 0,
							  btn_4 = 0,
							  btn_5 = 0,
							  btn4_type = 0,
							  btn5_type = 0,
							  active_type = "[]"								  
													
			};
		true ->
			NewMountSkillExp1 =  list_to_tuple([ets_mount_skill_exp]++MountSkillExpList),
			if NewMountSkillExp1#ets_mount_skill_exp.auto_step < 1 ->
				   NewMountSkillExp = NewMountSkillExp1#ets_mount_skill_exp{auto_step=1};
			   true ->
				   NewMountSkillExp = NewMountSkillExp1
			end
	end,
	load_mount_skill_exp_into_ets(NewMountSkillExp),
	ok.

load_all_mount_skill_split(PlayerId) ->
	MountSkillSplitList = db_agent:select_all_mount_skill_split(PlayerId),
	lists:map(fun(MountSkillSplitInfo)-> load_mount_skill_split_into_ets(MountSkillSplitInfo) end,MountSkillSplitList).

load_mount_into_ets(MountInfo) ->
	Mount = list_to_tuple([ets_mount]++MountInfo),
	GoodsInfo = goods_util:get_goods(Mount#ets_mount.id),
	%%添加坐骑前判断物品是否存在
	if is_record(GoodsInfo,goods) ->
		   %%防止因断线后原ets信息仍在，导致重复问题
		    ets:delete(?ETS_MOUNT,Mount#ets_mount.id),
		    update_mount(Mount);
	   true ->
		  skip
	end.

load_mount_skill_exp_into_ets(MountSkillExpInfo) ->
    update_mount_skill_exp(MountSkillExpInfo).

load_mount_skill_split_into_ets(MountSkillSplitInfo) ->
	MountSkillSplit = list_to_tuple([ets_mount_skill_split]++MountSkillSplitInfo),
    update_mount_skill_split(MountSkillSplit).

update_mount(Mount) ->
    ets:insert(?ETS_MOUNT, Mount).

update_mount_skill_exp(MountSkillExp) ->
    ets:insert(?ETS_MOUNT_SKILL_EXP, MountSkillExp).

update_mount_skill_split(MountSkillSplit) ->
    ets:insert(?ETS_MOUNT_SKILL_SPLIT, MountSkillSplit).

give_mount(Id,PlayerId,GoodsId,Name,Speed,Stren,Step,Level,Exp,Luck_val,Close,Color,Lp,Xp,Tp,Qp,Skill_1,Skill_2,Skill_3,Skill_4,Skill_5,Skill_6,Skill_7,Skill_8,Status,Icon,Title,Mount_val,Last_time) ->
	Ct = util:unixtime(),
	db_agent:give_mount(Id,PlayerId,GoodsId,Name,Speed,Stren,Step,Level,Exp,Luck_val,Close,Color,Lp,Xp,Tp,Qp,Skill_1,Skill_2,Skill_3,Skill_4,Skill_5,Skill_6,Skill_7,Skill_8,Status,Icon,Title,Mount_val,Last_time,Ct).

update_mount_skill_exp(ValueList, WhereList) ->
	db_agent:update_mount_skill_exp(ValueList, WhereList).

save_mount_skill_split(PlayerId,Skill_id,Exp,Color,Level,Type) ->
	db_agent:save_mount_skill_split(PlayerId,Skill_id,Exp,Color,Level,Type).

update_mount_skill_split(ValueList, WhereList) ->
	db_agent:update_mount_skill_split(ValueList, WhereList).

delete_mount_skill_split_db(MountSkillSplitId) ->
    db_agent:delete_mount_skill_split(MountSkillSplitId).

delete_all_mount_skill_split_db(PlayerId) ->
    db_agent:delete_all_mount_skill_split(PlayerId).

save_mount(Mount) ->
    db_agent:save_mount(Mount#ets_mount.id,
					  Mount#ets_mount.goods_id,
					  Mount#ets_mount.level,
					  Mount#ets_mount.exp,
					  Mount#ets_mount.luck_val,
					  Mount#ets_mount.close,
					  Mount#ets_mount.speed,
					  Mount#ets_mount.color,
					  Mount#ets_mount.stren,
					  Mount#ets_mount.step,
					  Mount#ets_mount.lp,
					  Mount#ets_mount.xp,
					  Mount#ets_mount.tp,
					  Mount#ets_mount.qp,
					  Mount#ets_mount.skill_1,
					  Mount#ets_mount.skill_2,
					  Mount#ets_mount.skill_3,
					  Mount#ets_mount.skill_4,
					  Mount#ets_mount.skill_5,
					  Mount#ets_mount.skill_6,
					  Mount#ets_mount.skill_7,
					  Mount#ets_mount.skill_8,
					  Mount#ets_mount.status,
					  Mount#ets_mount.icon,
					  Mount#ets_mount.last_time
						
					 ).

%%查询角色的所有坐骑
get_all_mount(PlayerId) ->
	MountList = match_all(?ETS_MOUNT, #ets_mount{player_id=PlayerId, _='_'}),
	Now = util:unixtime(),
	%%清0时间
	DefineTime = 3600*0+0*60,
	TodaySecond = util:get_today_current_second(),
	{TodayTime, _NextDayYime} = util:get_midnight_seconds(Now), 
	if MountList =/= [] ->
		   F = fun(Mount) ->
					   %%添加坐骑前判断物品是否存在
					   LastTime = Mount#ets_mount.last_time,
					   %%零晨0点幸运值小于100则清0
					   case util:is_same_date(Now,LastTime) of
						   true -> %%时间是同一天，不需要处理
							   if LastTime < TodayTime+DefineTime andalso Now >= TodayTime+DefineTime ->
									  Reset = true;
								  true ->
									  Reset = false
							   end;
						   false ->
							   if
								   TodaySecond >= DefineTime ->
									   Reset = true;
								   true ->
									   Reset = false
							   end
					   end,
					   case Reset of
						   true ->
							   Luck_val = Mount#ets_mount.luck_val,
							   if Luck_val < 100 ->
									  Reset1 = true;
								  true ->
									  Reset1 = false
							   end;
						   false ->
							   Reset1 = false
					   end,
					   case Reset1 of
						   true ->
							   Mount1 = Mount#ets_mount{luck_val = 0,last_time = Now},
							   update_mount(Mount1),
							   spawn(fun()-> db_agent:update_mount([{luck_val, 0},{last_time, Now}], [{id,Mount1#ets_mount.id}]) end),
							   Mount1;
						   false ->
							   Mount
					   end
			   end,
		   NewMountList = [F(Mount) || Mount <- MountList],
		   NewMountList;
	   true ->
		   MountList
	end.

%%查询角色的坐骑配置信息
get_mount_skill_exp(PlayerId) ->
	match_one(?ETS_MOUNT_SKILL_EXP, #ets_mount_skill_exp{player_id=PlayerId, _='_'}).

%%查询角色的所有猎魂技能空闲列表
get_all_mount_skill_split(PlayerId) ->
	match_all(?ETS_MOUNT_SKILL_SPLIT, #ets_mount_skill_split{player_id=PlayerId, _='_'}).

%%查询角色的猎魂技能空闲
get_mount_skill_split(MountSkillSplitId) ->
	match_one(?ETS_MOUNT_SKILL_SPLIT, #ets_mount_skill_split{id=MountSkillSplitId, _='_'}).

%%查询角色的所有猎魂技能空闲列表
delete_all_mount_skill_split(PlayerId) ->
	 ets:match_delete(?ETS_MOUNT_SKILL_SPLIT, #ets_mount_skill_split{player_id=PlayerId, _='_'}).

%%查询角色的所有猎魂技能空闲列表
delete_mount_skill_split(MountSkillSplitId) ->
	 ets:match_delete(?ETS_MOUNT_SKILL_SPLIT, #ets_mount_skill_split{id=MountSkillSplitId, _='_'}).

%%查找角色所有休息状态的坐骑
get_all_rest_mount(PlayerId) ->
   match_all(?ETS_MOUNT, #ets_mount{player_id=PlayerId,status=0, _='_'}).

%%查看出战坐骑
get_out_mount(PlayerId) ->
	match_one(?ETS_MOUNT,#ets_mount{player_id = PlayerId,status = 1,_='_'}).

get_mount(PlayerId, MountId) ->
    match_one(?ETS_MOUNT, #ets_mount{id=MountId, player_id=PlayerId, _='_'}).

get_mount(MountId) ->
    lookup_one(?ETS_MOUNT, MountId).

delete_mount(MountId) ->
    ets:delete(?ETS_MOUNT, MountId).

delete_all_mount(PlayerId) ->
    ets:match_delete(?ETS_MOUNT, #ets_mount{player_id=PlayerId, _='_'}).

delete_mount_skill_exp(PlayerId) ->
    ets:match_delete(?ETS_MOUNT_SKILL_EXP, #ets_mount_skill_exp{player_id=PlayerId, _='_'}).

	
%%坐骑从物品转换成坐骑信息
change_mount(PlayerStatus,MountGoodsInfo) ->
	Now = util:unixtime(),
	OldMountInfo = lib_mount:get_mount(MountGoodsInfo#goods.id), 
	%%如果对应的新坐骑已经存在，则跳过
	if is_record(OldMountInfo,ets_mount)  ->
		   skip;
	   true ->
		   GoodsTypeInfo = goods_util:get_goods_type(MountGoodsInfo#goods.goods_id),
		   Step = data_mount:get_transfer_step(MountGoodsInfo#goods.goods_id),
		   Level = 1,
		   [TotalValue,_Average,_MaxVlaue] = data_mount:get_4sp_val(Step),
		   %%查找物品名字
		   Mount = #ets_mount{
							  id = MountGoodsInfo#goods.id,
							  player_id = MountGoodsInfo#goods.player_id,
							  goods_id = MountGoodsInfo#goods.goods_id,
							  name = GoodsTypeInfo#ets_base_goods.goods_name,
							  speed = MountGoodsInfo#goods.speed,
							  stren = MountGoodsInfo#goods.stren,
							  step = Step,
							  level = Level,
							  lp = round(TotalValue/4),
							  xp = round(TotalValue/4),
							  tp = round(TotalValue/4),
							  qp = round(TotalValue/4),
							  last_time = Now
							  							  
			},
		   update_mount(Mount),
		   lib_mount:give_mount(MountGoodsInfo#goods.id,MountGoodsInfo#goods.player_id,MountGoodsInfo#goods.goods_id,GoodsTypeInfo#ets_base_goods.goods_name,MountGoodsInfo#goods.speed,MountGoodsInfo#goods.stren,Step,Level,
			   Mount#ets_mount.exp,Mount#ets_mount.luck_val,Mount#ets_mount.close,Mount#ets_mount.color,round(TotalValue/4),round(TotalValue/4),round(TotalValue/4),round(TotalValue/4),
			   Mount#ets_mount.skill_1,Mount#ets_mount.skill_2,Mount#ets_mount.skill_3,Mount#ets_mount.skill_4,Mount#ets_mount.skill_5,Mount#ets_mount.skill_6,Mount#ets_mount.skill_7,Mount#ets_mount.skill_8,
			   Mount#ets_mount.status,Mount#ets_mount.icon,Mount#ets_mount.title,0,Now),
		   %%添加转换日志
		   spawn(fun()->db_agent:log_mount_change([MountGoodsInfo#goods.id,MountGoodsInfo#goods.player_id,PlayerStatus#player.nickname,MountGoodsInfo#goods.goods_id,GoodsTypeInfo#ets_base_goods.goods_name,MountGoodsInfo#goods.speed,MountGoodsInfo#goods.stren,Step,Level,
			   round(TotalValue/4),round(TotalValue/4),round(TotalValue/4),round(TotalValue/4)])end),
		   
		   %%添加坐骑图鉴
		   if MountGoodsInfo#goods.goods_id =/= 16000 ->
				  add_active_type(PlayerStatus,[MountGoodsInfo#goods.goods_id,16013]);
			  true ->
				  add_active_type(PlayerStatus,[MountGoodsInfo#goods.goods_id])
		   end,		   
		   %%拥有第一只坐骑成就
		   lib_achieve:check_achieve_finish_cast(PlayerStatus#player.other#player_other.pid, 538, [1]),
		   %%刷新新坐骑列表
		   pp_mount:handle(16013, PlayerStatus, []),
		   %%刷新新坐骑图鉴列表
		   pp_mount:handle(16035, PlayerStatus, [])
	end.

update_goods_mount_stren(MountId,NewStrengthen) ->
	MountInfo = lib_mount:get_mount(MountId), 
	if MountInfo == [] ->
		   skip;
	   true ->
		   NewMountInfo = MountInfo#ets_mount{stren=NewStrengthen},
		   KeyValueList = [{stren,NewStrengthen}],
		   update_mount(NewMountInfo),
		   db_agent:update_mount(KeyValueList,[{id,MountInfo#ets_mount.id}]),
		   %%同步到斗兽
		   spawn(fun()->
						 Speed = lib_mount_arena:count_speed(NewMountInfo),
						 lib_mount_arena:sync_mount_data(NewMountInfo#ets_mount{speed = Speed})
				 end)
	end.


%%添加新图鉴[16004,16005]
add_active_type(Status,GoodTypeIds) ->
	 %%添加坐骑图鉴
	MountSkillExpInfo = lib_mount:mount_5_btn(Status#player.id),
	if is_record(MountSkillExpInfo,ets_mount_skill_exp) ->
		   MountTypeIdList = util:string_to_term(tool:to_list(MountSkillExpInfo#ets_mount_skill_exp.active_type)),
		   NewActiveType = util:term_to_string(lists:usort(GoodTypeIds++MountTypeIdList)),
		   NewMountSkillExpInfo = MountSkillExpInfo#ets_mount_skill_exp{active_type = NewActiveType},
		   KeyValueList = [{active_type,NewActiveType}],
		   update_mount_skill_exp(NewMountSkillExpInfo),
		   update_mount_skill_exp(KeyValueList, [{id,NewMountSkillExpInfo#ets_mount_skill_exp.id}]),
		   %%添加坐骑图鉴日志
		   F = fun(GoodTypeId) ->
					   case lists:member(GoodTypeId, MountTypeIdList) of
						   true ->
							   skip;
						   false ->
							   Name = data_mount:get_name_by_goodsid(GoodTypeId),
							   Msg = io_lib:format("坐骑[~s]图鉴已激活",[Name]),
							   {ok,MyBin} = pt_16:write(16041,[Msg]),
							   lib_send:send_to_sid(Status#player.other#player_other.pid_send,MyBin),
							   spawn(fun()->db_agent:log_mount_active_type([Status#player.id,Status#player.nickname,GoodTypeId,Name])end)
					   end
			   end,
		   [F(GoodTypeId) || GoodTypeId<- GoodTypeIds];
	   true ->
		   skip
	end,	
	ok.
	

%% -----------------------------------------------------------------
%% 出战坐骑亲密度自动增长
%% -----------------------------------------------------------------
auto_add_close(Status,MountId) ->
	Mount = get_out_mount(Status#player.id),
	if is_record(Mount,ets_mount) andalso Mount#ets_mount.id == MountId->
		   NewMount = Mount#ets_mount{close = Mount#ets_mount.close + 1},
		   %%保存内存
		   update_mount(Mount),
		   %%保存数据库
		   spawn(fun()->db_agent:update_mount([{close,NewMount#ets_mount.close},{level,NewMount#ets_mount.level},{exp,NewMount#ets_mount.exp}], [{id,MountId}])end),
		   %%推送坐骑信息
		   pp_mount:handle(16012, Status, Mount#ets_mount.id),
		   %%更新角色坐骑属性加成
		   NewStatus = lib_mount:update_mount_attribute_effect(Status,NewMount),
		   [1,NewStatus];
	   %%坐骑没出战
	   true ->
		   [0,Status ]  
	end.


%% -----------------------------------------------------------------
%% 坐骑改名
%% -----------------------------------------------------------------
rename_mount(Status, MountId, NewName) ->  
	Mount = lib_mount:get_mount(MountId),
	if Mount == [] ->
		   [0,MountId,NewName];
	   true ->
		   %% 更新坐骑名
		   db_agent:rename_mount(Mount#ets_mount.id, NewName),
		   %% 更新ets
		   NewMount = Mount#ets_mount{ name = NewName},
		   update_mount(NewMount),
		   %%推送坐骑信息
		   pp_mount:handle(16012, Status, Mount#ets_mount.id),
		   [1,MountId,NewName]
	end.

%% -----------------------------------------------------------------
%% 坐骑出战
%% -----------------------------------------------------------------
out_mount(Status,Mount) ->
	OutMount = lib_mount:get_out_mount(Status#player.id),
	%%将原出战的坐骑休息
	if is_record(OutMount,ets_mount) ->
		   lib_mount:rest_mount(Status,OutMount);
	   true ->
		   skip
	end,
	NewMount = Mount#ets_mount{status = 1}, 
	update_mount(NewMount),
  	db_agent:mount_update_status(Mount#ets_mount.id,1),
	%%更新角色坐骑属性加成
    NewStatus = lib_mount:update_mount_attribute_effect(Status,NewMount),
	%%坐骑出战任务
	lib_task:event(mount_fight,null,NewStatus),
	%%斗兽竞技榜
	spawn(fun()->lib_mount_arena:rank_by_login(NewMount,NewStatus) end),
	[1,NewStatus].

%% -----------------------------------------------------------------
%% 坐骑休息
%% -----------------------------------------------------------------
rest_mount(Status,Mount) ->
	NewMount = Mount#ets_mount{status = 0}, 
	update_mount(NewMount),
    db_agent:mount_update_status(NewMount#ets_mount.id,0),
	%%从玩家身上拿下坐骑
	if Mount#ets_mount.id == Status#player.mount ->
		   NewStatus = get_off_mount(Status,Mount);
	   true ->
		   NewStatus = Status
	end,
	%%保存坐骑等级经验
	spawn(fun()->db_agent:update_mount([{level,NewMount#ets_mount.level},{exp,NewMount#ets_mount.exp}],[{id,NewMount#ets_mount.id}])end),
	%%更新角色坐骑属性加成
	NewStatus1 = lib_mount:update_mount_attribute_effect(NewStatus,NewMount),
    [1,NewStatus1].

%% -----------------------------------------------------------------
%%坐骑放生
%% -----------------------------------------------------------------
free_mount(Status,Mount) ->
    db_agent:free_mount(Mount#ets_mount.id),
    % 更新缓存
    delete_mount(Mount#ets_mount.id),
	%%同时删除物品中的坐骑(变身没考虑)
	gen_server:cast(Status#player.other#player_other.pid_goods, {'throw_15051', Status,Mount#ets_mount.id, 1}),
	%%刷新新坐骑列表
	pp_mount:handle(16013, Status, []),
	%%从玩家身上拿下坐骑
	if Mount#ets_mount.id == Status#player.mount ->
		   NewStatus = get_off_mount(Status,Mount);
	   true ->
		   NewStatus = Status
	end,
    [1,NewStatus].

%% -----------------------------------------------------------------
%% 坐骑喂养
%% -----------------------------------------------------------------
feed_mount(Status,Mount,Food_type,GoodsNum) ->
	case gen_server:call(Status#player.other#player_other.pid_goods, {'DELETE_MORE_BIND_PRIOR', Food_type, GoodsNum}) of
         1 -> 
			 AddExp = GoodsNum*10,
 			 [NewLevel,NewExp,_RestExp] = update_mount_level(Status#player.lv,Mount#ets_mount.level,Mount#ets_mount.exp,AddExp),
			 if NewLevel > Mount#ets_mount.level ->
					Msg = io_lib:format("恭喜您坐骑等级上升到~p级",[NewLevel]),
					{ok,MyBin} = pt_15:write(15055,[Msg]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send,MyBin);
				true ->
					skip
			 end,
			 NewMount = Mount#ets_mount{level = NewLevel, exp = NewExp}, 
			 update_mount(NewMount),
			 db_agent:update_mount([{level,NewMount#ets_mount.level},{exp,NewMount#ets_mount.exp}],[{id,NewMount#ets_mount.id}]),
			 %%推送坐骑信息
			 pp_mount:handle(16012, Status, NewMount#ets_mount.id),
			 %%更新角色坐骑属性加成
			 NewStatus1 = lib_mount:update_mount_attribute_effect(Status,NewMount),
             [1,NewStatus1];
         _ErrorCode ->
             [0,Status]
    end.

%%坐骑增加经验
add_mount_exp(Status,NewExp) ->
	Mount = get_out_mount(Status#player.id),
	if Mount == [] -> 
		   Status;
	   true ->
		   {ok,MyBin} = pt_16:write(16036,NewExp),
	       lib_send:send_to_sid(Status#player.other#player_other.pid_send,MyBin),
		   [NewLevel,NewExp1,_RestExp] = update_mount_level(Status#player.lv,Mount#ets_mount.level,Mount#ets_mount.exp,NewExp),
		   NewMount = Mount#ets_mount{level = NewLevel, exp = NewExp1},
		   update_mount(NewMount),
		   if NewLevel > Mount#ets_mount.level ->
				  spawn(fun()->db_agent:update_mount([{level,NewMount#ets_mount.level},{exp,NewMount#ets_mount.exp}],[{id,NewMount#ets_mount.id}])end),
				  Msg1 = io_lib:format("恭喜您坐骑等级上升到~p级",[NewLevel]),
				  {ok,MyBin1} = pt_15:write(15055,[Msg1]),
				  lib_send:send_to_sid(Status#player.other#player_other.pid_send,MyBin1),
				  %%同步斗兽榜
				  spawn(fun()->lib_mount_arena:sync_mount_data(NewMount) end),
				  %%更新角色坐骑属性加成
				  NewStatus = lib_mount:update_mount_attribute_effect(Status,NewMount);
			  true ->
				  NewStatus = Status
		   end,
		   %%推送坐骑信息
		   %%pp_mount:handle(16012, Status, NewMount#ets_mount.id),
		   NewStatus
	end.

%%坐骑状态切换开关
change_new_mount_status(PlayerStatus,MountInfo) ->
	case PlayerStatus#player.mount of
		%%原来没有坐骑
		0 ->
			NewPlayerStatus = get_on_mount(PlayerStatus,MountInfo),
			if MountInfo#ets_mount.icon > 0 ->
				   {ok,NewPlayerStatus,MountInfo#ets_mount.icon};
			   true ->
				   {ok,NewPlayerStatus,MountInfo#ets_mount.goods_id}
			end;
		%%有坐骑
		OldMountId ->				
			%%新旧相同则卸下
			case OldMountId =:= MountInfo#ets_mount.id of
				true ->
					NewPlayerStatus = get_off_mount(PlayerStatus,MountInfo),
					{ok,NewPlayerStatus,0};
				%%不同则先卸旧装备新
				false ->
					OldMountInfo = lib_mount:get_mount(OldMountId),
					if
						is_record(OldMountInfo,ets_mount) ->
							PlayerStatus2 = get_off_mount(PlayerStatus,OldMountInfo);
						true ->
							PlayerStatus2 = PlayerStatus
					end,
					NewPlayerStatus = get_on_mount(PlayerStatus2,MountInfo),
					if MountInfo#ets_mount.icon > 0 ->
						   {ok,NewPlayerStatus,MountInfo#ets_mount.icon};
					   true ->
						   {ok,NewPlayerStatus,MountInfo#ets_mount.goods_id}
					end					
			end
	end.

%%装备坐骑			
get_on_mount(PlayerStatus,MountInfo) ->
	if
		is_record(MountInfo,ets_mount) ->			
			[Wq, Yf, _Fbyf,_Spyf,_Zq] = PlayerStatus#player.other#player_other.equip_current,
			if MountInfo#ets_mount.icon > 0 ->
				   NewMountTypeId = MountInfo#ets_mount.icon;
			   true ->
				   NewMountTypeId = MountInfo#ets_mount.goods_id				   
			end,
			Equip_current = [Wq, Yf, _Fbyf,_Spyf, NewMountTypeId],
			NewPlayerStatus = PlayerStatus#player{
                           mount = MountInfo#ets_mount.id,
						   other = PlayerStatus#player.other#player_other{
                           		equip_current = Equip_current,
								mount_stren = MountInfo#ets_mount.stren
								}
            	},
			MountPlayer = lib_player:player_speed_count(NewPlayerStatus),
			spawn(fun()->db_agent:change_mount_status(MountInfo#ets_mount.id,NewPlayerStatus#player.id)end),
			{ok, BinData} = pt_12:write(12010, [NewPlayerStatus#player.id, MountPlayer#player.speed, NewMountTypeId,MountInfo#ets_mount.id,MountInfo#ets_mount.stren]),
    		mod_scene_agent:send_to_area_scene(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, BinData),
			MountPlayer;
		true ->
			PlayerStatus
	end.

%%卸下坐骑			
get_off_mount(PlayerStatus,MountInfo) ->
	if
		is_record(MountInfo,ets_mount) ->	
			[Wq, Yf, _Fbyf,_Spyf,_Zq] = PlayerStatus#player.other#player_other.equip_current,
			%%时装显示设置判断
			[_Player_Id, _ShieldRole, _ShieldSkill, _ShieldRela, _ShieldTeam, _ShieldChat, _Music, _SoundEffect,Fasheffect, _Smelt] = lib_syssetting:query_player_sys_setting(PlayerStatus#player.id),
			case Fasheffect == 1 of
				true ->
					NewPlayerStatus = PlayerStatus#player{
                           mount = 0,
						   other = PlayerStatus#player.other#player_other{
                           		equip_current = [Wq, 0, _Fbyf,_Spyf,0],
								mount_stren = 0
								}
            	};
				false ->
					NewPlayerStatus = PlayerStatus#player{
                   		mount = 0,
						other = PlayerStatus#player.other#player_other{
                      		equip_current = [Wq, Yf, _Fbyf,_Spyf,0],
							mount_stren = 0
						}
            		}
			end,
			MountPlayer = lib_player:player_speed_count(NewPlayerStatus),
			spawn(fun()-> db_agent:change_mount_status(0,NewPlayerStatus#player.id) end),
			{ok, BinData} = pt_12:write(12010, [NewPlayerStatus#player.id, MountPlayer#player.speed, 0,MountInfo#ets_mount.id,0]),
    		mod_scene_agent:send_to_area_scene(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, BinData),
			MountPlayer;
		true ->
			PlayerStatus
	end.

%% 获取坐骑主要属性[外形，速度，强化等级]
get_mount_main_att(Player) ->
	case Player#player.mount of
		0 ->
			[0,0,0];
		MountId ->
			MountInfo = lib_mount:get_mount(MountId),
			Speed = lib_mount:get_mount_speed(Player#player.id),
			if
				is_record(MountInfo,ets_mount) ->
					if %% 如果坐骑变身效果
						MountInfo#ets_mount.icon > 0 ->
							[MountInfo#ets_mount.icon,Speed,MountInfo#ets_mount.stren];
						true ->
							[MountInfo#ets_mount.goods_id,Speed,MountInfo#ets_mount.stren]
					end;
				true ->
					[0,0,0]
			end
	end.

%% 获取出战坐骑跑速
get_mount_speed(PlayerId) ->
	Mount = get_out_mount(PlayerId),
	if
		is_record(Mount,ets_mount) ->
			GoodsInfo = goods_util:get_goods(Mount#ets_mount.id),
			case Mount#ets_mount.status of
				1 ->
					if is_record(GoodsInfo,goods) ->
						   if
							   GoodsInfo#goods.stren > 0 ->
						    		GoodsInfo#goods.speed;
							   true ->
								   NewSpeed =
								   	case Mount#ets_mount.step of
									   0 -> 0;
									   1 -> 30;
									   2 -> 45;
									   3 -> 55;
									   _ -> 65
								   	end,
								   GoodsSpeed = GoodsInfo#goods.speed,
								   if GoodsSpeed >= NewSpeed ->
										  GoodsSpeed;
									  true ->
										  NewSpeed
								   end
						   end;
					   true ->
						   0
					end;
				_ ->
					0
			end;
		true ->
			0
	end.

	
%% 获取坐骑初始速度  注意：只用于parse_goods_addition 分析坐骑速度
%% GoodsInfo为初始值
get_mount_speed_by_id(MountId,GoodsInfo) ->
	case db_agent:select_mount_info(MountId) of
		[] -> 
			if
				is_record(GoodsInfo,goods) ->
					GoodsInfo#goods.speed;
				true ->
					0
			end;
		MountData ->
			Mount = list_to_tuple([ets_mount]++MountData),
			Speed0 = 
				case Mount#ets_mount.step of
					0 -> 0;
					1 -> 30;
					2 -> 45;
					3 -> 55;
					_ -> 65
				end,
			Speed = 
				if
					is_record(GoodsInfo,goods) ->					
						if
							GoodsInfo#goods.speed > Speed0 ->
								GoodsInfo#goods.speed;
							true ->
								Speed0
						end;
					true ->
						Speed0
				end,
			Speed
	end.
	
%% 坐骑进阶界面信息
get_next_step_info(_Status,Mount) ->
	Step = Mount#ets_mount.step,
	[MountTypeId,Name] = data_mount:get_next_step_type_name(Step+1),
	GoodsInfo = goods_util:get_goods(Mount#ets_mount.id),
	if Mount#ets_mount.speed >  GoodsInfo#goods.speed ->
		   NewSpeed = Mount#ets_mount.speed;
	   true ->
		   NewSpeed = GoodsInfo#goods.speed
	end,
%% 	NewSpeed = 
%% 		case Mount#ets_mount.step of
%% 			0 -> 0;
%% 			1 -> 30;
%% 			2 -> 45;
%% 			3 -> 55;
%% 			_ -> 65				   
%% 		end,
	TotalValue = data_mount:get_max_4sp_val(Step+1),
	[Goods_id,Num,Cost] = data_mount:get_need_cond_step(Step+1),
	Luck_val = Mount#ets_mount.luck_val,  
	Max_Luck_val = data_mount:get_max_luck_val(Step),
	[1,Mount#ets_mount.id,MountTypeId,Name,Step+1,NewSpeed,TotalValue,Goods_id,Num,Cost,Luck_val,Max_Luck_val].

%%坐骑进阶
oper_step(Status,Mount,Cost,MountGoodsTypeId,Goods_id,Num,TotalNum,GoldCost) ->
	NewPlayer = lib_goods:cost_money(Status,Cost,coin,1601),
	if 
		TotalNum >= Num ->%%物品够则先删除物品
			gen_server:cast(Status#player.other#player_other.pid_goods, {'DELETE_MORE_BIND_PRIOR', Goods_id, Num}),
			NewPlayer1 = NewPlayer;
		TotalNum > 0 andalso TotalNum < Num ->%%物品不够则先删除物品，再扣元宝
			gen_server:cast(Status#player.other#player_other.pid_goods, {'DELETE_MORE_BIND_PRIOR', Goods_id, TotalNum}),
			NewPlayer1 = lib_goods:cost_money(NewPlayer,GoldCost,gold,1605);
		true ->%%全扣元宝
			NewPlayer1 = lib_goods:cost_money(NewPlayer,GoldCost,gold,1605)
	end,
			
	Now = util:unixtime(),
	Ratio = data_mount:get_ratio_by_luck_step(Mount#ets_mount.step,Mount#ets_mount.luck_val),
	Random = util:rand(1,10000),  
	
	Max_Luck_val = data_mount:get_max_luck_val(Mount#ets_mount.step),
	if Random =< Ratio orelse (Mount#ets_mount.luck_val + 5 > Max_Luck_val) ->
		   [_MountTypeId,Name] = data_mount:get_next_step_type_name(Mount#ets_mount.step+1),
		   %%添加坐骑图鉴
		   add_active_type(NewPlayer1,[MountGoodsTypeId]),
		   
		   [TotalValue1,_Average,_MaxVlaue] = data_mount:get_4sp_val(Mount#ets_mount.step),
		   [TotalValue2,_Average2,_MaxVlaue2] = data_mount:get_4sp_val(Mount#ets_mount.step+1),
		   AverageSp4 = round((TotalValue2-TotalValue1)/4),
		   
		   %%进阶成功后幸运值清0
		   NewMount = Mount#ets_mount{goods_id=MountGoodsTypeId,name=Name,step=Mount#ets_mount.step+1,luck_val=0,close=0,
									  		lp=Mount#ets_mount.lp+AverageSp4,xp=Mount#ets_mount.xp+AverageSp4,tp=Mount#ets_mount.tp+AverageSp4,qp=Mount#ets_mount.qp+AverageSp4,last_time=Now},
		   update_mount(NewMount),
		   db_agent:update_mount([{goods_id,NewMount#ets_mount.goods_id},{name,NewMount#ets_mount.name},{step,NewMount#ets_mount.step},{luck_val,0},{close,0},
								  	  {lp,NewMount#ets_mount.lp},{xp,NewMount#ets_mount.xp},{tp,NewMount#ets_mount.tp},{qp,NewMount#ets_mount.qp},{last_time,Now}],
								 [{id,NewMount#ets_mount.id}]),
		   
		   %%添加坐骑进阶日志
		   spawn(fun()->db_agent:log_mount_oper_step([NewMount#ets_mount.id,Status#player.id,Status#player.nickname,1,Cost,Mount#ets_mount.step,NewMount#ets_mount.step,Mount#ets_mount.name,NewMount#ets_mount.name,
													  Mount#ets_mount.lp,NewMount#ets_mount.lp,Mount#ets_mount.xp,NewMount#ets_mount.xp,Mount#ets_mount.tp,NewMount#ets_mount.tp,
													  Mount#ets_mount.qp,NewMount#ets_mount.qp,Mount#ets_mount.luck_val,NewMount#ets_mount.luck_val,Mount#ets_mount.close,NewMount#ets_mount.close])end),
		  
		   %%进阶成功后同步更新坐骑对应的物品goods_id,并恢复初始速度，重新计算
		   GoodsInfo = goods_util:get_goods(NewMount#ets_mount.id),
		   NewGoodsInfo = GoodsInfo#goods{goods_id = MountGoodsTypeId,speed = GoodsInfo#goods.other_data#goods.speed,other_data=''},
		   ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
		   db_agent:update_goods([{goods_id,MountGoodsTypeId}],[{id,NewMount#ets_mount.id}]),
		  
		   
		   if Mount#ets_mount.step >= 3 ->
				  NameColor = data_agent:get_realm_color(Status#player.realm),
				  Msg = io_lib:format("恭喜！玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]将坐骑<font color='~s'>[~s]</font>提升到~p阶<font color='~s'>[~s]</font>！！",[Status#player.id,Status#player.nickname,Status#player.career,Status#player.sex,NameColor,Status#player.nickname,data_mount:get_skill_name_color(Mount#ets_mount.color),Mount#ets_mount.name,NewMount#ets_mount.step,data_mount:get_skill_name_color(NewMount#ets_mount.color),NewMount#ets_mount.name]),
				  lib_chat:broadcast_sys_msg(2,Msg);
			  true ->
				  skip
			end,
		   %%成就判断
		   lib_achieve_outline:mount_ach_check(Status#player.other#player_other.pid, NewMount, 1),
		   %%同步斗兽榜
		   spawn(fun()->
						 Speed = lib_mount_arena:count_speed(NewMount),
						 lib_mount_arena:sync_mount_data(NewMount#ets_mount{speed = Speed})
				 end),
		   %%更新角色坐骑属性加成
		   NewPlayer2 = lib_mount:update_mount_attribute_effect(NewPlayer1,NewMount),
		   [1,NewPlayer2];%%成功
	   true ->
		   if Mount#ets_mount.luck_val + 5 == Max_Luck_val ->
				  NewMount = Mount#ets_mount{luck_val=Max_Luck_val,last_time=Now};
			  true ->
				  NewMount = Mount#ets_mount{luck_val=Mount#ets_mount.luck_val+5,last_time=Now}
		   end,
		   update_mount(NewMount),
		   db_agent:update_mount([{luck_val,NewMount#ets_mount.luck_val},{last_time,Now}],[{id,NewMount#ets_mount.id}]),
		    %%添加坐骑进阶日志
		   spawn(fun()->db_agent:log_mount_oper_step([NewMount#ets_mount.id,Status#player.id,Status#player.nickname,0,Cost,Mount#ets_mount.step,NewMount#ets_mount.step,Mount#ets_mount.name,NewMount#ets_mount.name,
													  Mount#ets_mount.lp,NewMount#ets_mount.lp,Mount#ets_mount.xp,NewMount#ets_mount.xp,Mount#ets_mount.tp,NewMount#ets_mount.tp,
													  Mount#ets_mount.qp,NewMount#ets_mount.qp,Mount#ets_mount.luck_val,NewMount#ets_mount.luck_val,Mount#ets_mount.close,NewMount#ets_mount.close])end),
		   lib_player:send_player_attribute(NewPlayer1,2),
		   [0,NewPlayer1]%%失败
	end.


%% 坐骑兽魄驯化界面信息
get_4sp_info(_Status,Mount) ->
	Step = Mount#ets_mount.step,
	[Goods_id,Num,Cost] = data_mount:get_need_cond_4sp(Step),
	[1,Goods_id,Num,Cost].


%% 坐骑兽魄驯化操作
oper_4sp(Status,Mount,Cost,Goods_id,Num,TotalNum,GoldCost) ->
	NewPlayer = lib_goods:cost_money(Status,Cost,coin,1602),
	if 
		TotalNum >= Num ->%%物品够则先删除物品
			gen_server:cast(Status#player.other#player_other.pid_goods, {'DELETE_MORE_BIND_PRIOR', Goods_id, Num}),
			NewPlayer1 = NewPlayer;
		TotalNum > 0 andalso TotalNum < Num ->%%物品不够则先删除物品，再扣元宝
			gen_server:cast(Status#player.other#player_other.pid_goods, {'DELETE_MORE_BIND_PRIOR', Goods_id, TotalNum}),
			NewPlayer1 = lib_goods:cost_money(NewPlayer,GoldCost,gold,1606);
		true ->%%全扣元宝
			NewPlayer1 = lib_goods:cost_money(NewPlayer,GoldCost,gold,1606)
	end,
	Step = Mount#ets_mount.step,
	Color = data_mount:get_random_color(Step),
	[_TotalValue,_Average,MaxVlaue] = data_mount:get_4sp_val(Mount#ets_mount.step),
	[Lp,Xp,Tp,Qp] = data_mount:get_mount_title_4sp(Mount),
	Sp4List = [{Lp,1},{Xp,2},{Tp,3},{Qp,4}],
	ResultList = lists:sort(fun({Value1, _Order1},{Value2, _Order2}) -> Value1 >= Value2  end, Sp4List),
	{Value,Order} = lists:nth(1, ResultList),
	Title = 
	if 
	   MaxVlaue - Value == 0 ->
		   case Order of
			   1 -> "汗血仙";
			   2 -> "騿骥仙";
			   3 -> "翠龙仙";
			   4 -> "逾辉仙";
			   _ -> ""
		   end;
	   MaxVlaue - Value == 5 ->
		    case Order of
			   1 -> "汗血王";
			   2 -> "騿骥王";
			   3 -> "翠龙王";
			   4 -> "逾辉王";
				_-> ""				
		   end;
	   MaxVlaue - Value == 10 ->
		   case Order of
			   1 -> "汗血";
			   2 -> "騿骥";
			   3 -> "翠龙";
			   4 -> "逾辉";
			   _ -> ""
		   end;
	   true ->   
		   ""
	end,
	if Step >=  4 ->
		   Title1 = Title;
	   true ->
		   Title1 = ""
	end,
	
	NewMount = Mount#ets_mount{title=Title1,color=Color,lp=Lp,xp=Xp,tp=Tp,qp=Qp},
	update_mount(NewMount),
	db_agent:update_mount([{title,NewMount#ets_mount.title},{color,NewMount#ets_mount.color},{lp,NewMount#ets_mount.lp},{xp,NewMount#ets_mount.xp},{tp,NewMount#ets_mount.tp},{qp,NewMount#ets_mount.qp}],[{id,NewMount#ets_mount.id}]),
	if Color >= 5 ->
		   NameColor = data_agent:get_realm_color(Status#player.realm),
		   Msg2 = io_lib:format("恭喜！玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]终于驯化出了紫色品质的坐骑<font color='~s'>[~s]</font>！",[Status#player.id,Status#player.nickname,Status#player.career,Status#player.sex,NameColor,Status#player.nickname,data_mount:get_skill_name_color(NewMount#ets_mount.color),NewMount#ets_mount.name]),
		   lib_chat:broadcast_sys_msg(2,Msg2);
	   true ->
		   skip
	end,
	
	%%添加坐骑驯化日志
	spawn(fun()->db_agent:log_mount_oper_4sp([NewMount#ets_mount.id,Status#player.id,Status#player.nickname,Cost,Mount#ets_mount.title,NewMount#ets_mount.title,Mount#ets_mount.color,NewMount#ets_mount.color,
				Mount#ets_mount.lp,NewMount#ets_mount.lp,Mount#ets_mount.xp,NewMount#ets_mount.xp,Mount#ets_mount.tp,NewMount#ets_mount.tp, Mount#ets_mount.qp,NewMount#ets_mount.qp])end),
	%%同步斗兽榜
	spawn(fun()->lib_mount_arena:sync_mount_data(NewMount) end),
	%%更新角色坐骑属性加成
	NewPlayer2 = lib_mount:update_mount_attribute_effect(NewPlayer1,NewMount),
 	[1,NewPlayer2].%%成功


%%坐骑猎魂技能列表
mount_skill_split_list(PlayerId) ->
	get_all_mount_skill_split(PlayerId).

%%坐骑五个按钮信息
mount_5_btn(PlayerId) ->
	get_mount_skill_exp(PlayerId).

%%设置自动萃取颜色
auto_step_set(PlayerId,Auto_Color) ->
	if Auto_Color >= 4 ->
		   0;
	   true ->
		   MountSkilExpInfo = get_mount_skill_exp(PlayerId),
		   NewMountSkilExpInfo = MountSkilExpInfo#ets_mount_skill_exp{auto_step=Auto_Color},
		   update_mount_skill_exp(NewMountSkilExpInfo),
		   update_mount_skill_exp([{auto_step,Auto_Color}], [{id,NewMountSkilExpInfo#ets_mount_skill_exp.id}]),
		   1
	end.

%%幸运值清零
clear_mount_lucky_value(PlayerId) ->
	Now = util:unixtime(),
	MountList = lib_mount:get_all_mount(PlayerId),
	F = fun(Mount) ->
				if Mount#ets_mount.luck_val < 100 ->
					   NewMount = Mount#ets_mount{luck_val = 0},
					   update_mount(NewMount),
					   spawn(fun()-> db_agent:update_mount([{luck_val, 0},{last_time, Now}], [{id,NewMount#ets_mount.id}]) end);
				   true ->
					   skip
				end
		end,
	[F(Mount)|| Mount <- MountList].
	

%%点击按钮产生技能按钮顺序从1-5
general_skill(Status,MountSkillExpInfo,Btn_Order,Cost) ->
	NewPlayer = lib_goods:cost_money(Status,Cost,cash,1603),
	%%激活下个按钮
	Active_Next_Btn = data_mount:get_next_btn_ratio(Btn_Order),
	if Btn_Order == 1 ->
		   if MountSkillExpInfo#ets_mount_skill_exp.btn_2 > Active_Next_Btn ->
				  Active_Next_Btn1 = MountSkillExpInfo#ets_mount_skill_exp.btn_2;
			  true ->
				  Active_Next_Btn1 = Active_Next_Btn
		   end,
		   NewMountSkillExpInfo = MountSkillExpInfo#ets_mount_skill_exp{btn_1 = 1,btn_2 = Active_Next_Btn1},
		   KeyValueList = [{btn_1,1},{btn_2,Active_Next_Btn1}];
		Btn_Order == 2 ->
			if MountSkillExpInfo#ets_mount_skill_exp.btn_3 > Active_Next_Btn ->
				  Active_Next_Btn1 = MountSkillExpInfo#ets_mount_skill_exp.btn_3;
			  true ->
				  Active_Next_Btn1 = Active_Next_Btn
		   end,
		   NewMountSkillExpInfo = MountSkillExpInfo#ets_mount_skill_exp{btn_2 = 0,btn_3 = Active_Next_Btn1},
		   KeyValueList = [{btn_2,0},{btn_3,Active_Next_Btn1}];
	   Btn_Order == 3 ->
		   if MountSkillExpInfo#ets_mount_skill_exp.btn_4 > Active_Next_Btn ->
				  Active_Next_Btn1 = MountSkillExpInfo#ets_mount_skill_exp.btn_4;
			  true ->
				  Active_Next_Btn1 = Active_Next_Btn
		   end,
		   NewMountSkillExpInfo = MountSkillExpInfo#ets_mount_skill_exp{btn_3 = 0,btn_4 = Active_Next_Btn1},
		   KeyValueList = [{btn_3,0},{btn_4,Active_Next_Btn1}];
	   Btn_Order == 4 ->
		    if MountSkillExpInfo#ets_mount_skill_exp.btn_5 > Active_Next_Btn ->
				  Active_Next_Btn1 = MountSkillExpInfo#ets_mount_skill_exp.btn_5;
			  true ->
				  Active_Next_Btn1 = Active_Next_Btn
		   end,
			if MountSkillExpInfo#ets_mount_skill_exp.btn4_type ==  1 ->
				  Btn5_type = 1;
			  true ->
				  Btn5_type = 0
		   end,
		   NewMountSkillExpInfo = MountSkillExpInfo#ets_mount_skill_exp{btn_4 = 0,btn4_type = 0,btn_5 = Active_Next_Btn1,btn5_type =Btn5_type},
		   KeyValueList = [{btn_4,0},{btn4_type,0},{btn_5,Active_Next_Btn1},{btn5_type,Btn5_type}];
	   Btn_Order == 5 ->
		   NewMountSkillExpInfo = MountSkillExpInfo#ets_mount_skill_exp{btn_5 = 0,btn5_type = 0},
		   KeyValueList = [{btn_5,0},{btn5_type,0}];
	   true ->
		    NewMountSkillExpInfo = MountSkillExpInfo,
			KeyValueList = [{btn_1,1},{btn_2,Active_Next_Btn}]
	end,
	 update_mount_skill_exp(NewMountSkillExpInfo),
	 update_mount_skill_exp(KeyValueList, [{id,NewMountSkillExpInfo#ets_mount_skill_exp.id}]),
	 ActiveType = get_btn_type(MountSkillExpInfo,Btn_Order),
     %%产生技能
	 SkillId = data_mount:get_random_color_btn(Btn_Order,ActiveType),
	 [Type,Color] = data_mount:get_skill_type_color(SkillId),
	 MountSkillSplitId = save_mount_skill_split(Status#player.id,SkillId,0,Color,1,Type),
	 MountSkillSplitInfo = #ets_mount_skill_split{
							  id = MountSkillSplitId,
							  player_id = Status#player.id,
							  skill_id = SkillId,
							  exp = 0,
							  color = Color,
							  level = 1,
							  type = Type							  
			},
	 update_mount_skill_split(MountSkillSplitInfo),
	 if Color >= 3 andalso Color =< 4 ->
			NameColor = data_agent:get_realm_color(Status#player.realm),
			Msg2 = io_lib:format("恭喜！玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]猎到了极为珍贵的精魂<a href='event:4,~p'><font color='~s'><u>[~s]</u></font></a>！真是让人羡慕妒忌恨啊！",[Status#player.id,Status#player.nickname,Status#player.career,Status#player.sex,NameColor,Status#player.nickname,MountSkillSplitId,data_mount:get_skill_name_color(Color+1),data_mount:get_skill_name(SkillId)]),
			lib_chat:broadcast_sys_msg(2,Msg2),
			lib_act_interf:mount_purple_skill(Status#player.nickname, Color);
		true ->
			skip
	 end,
	%%添加坐骑精魂日志
	spawn(fun()->db_agent:log_mount_skill_split([MountSkillSplitId,Status#player.id,Status#player.nickname,Cost,SkillId,0,Color,1,Type,Btn_Order])end),
	if Active_Next_Btn == 1 ->
		   [1,SkillId,Color,Btn_Order+1,NewPlayer];
	   true ->
		   [1,SkillId,Color,0,NewPlayer]
	end.

%%%%用元宝激活按钮4
active_btn4(Status,MountSkillExpInfo,Cost) ->
	NewPlayer = lib_goods:cost_money(Status,Cost,gold,1604),
	NewMountSkillExpInfo = MountSkillExpInfo#ets_mount_skill_exp{btn_4 = 1,btn4_type = 1},
	KeyValueList = [{btn_4,1},{btn4_type,1}],
	update_mount_skill_exp(NewMountSkillExpInfo),
	update_mount_skill_exp(KeyValueList, [{id,NewMountSkillExpInfo#ets_mount_skill_exp.id}]),
	lib_player:send_player_attribute(NewPlayer,2),
	[1,NewPlayer].

%%技能拖动类型(UpDown 1为从上面拉到下面,2从下面拉到上面,3为闲置技能左右拖动坐骑技能不能左右拖动,Type1为技能合并预览，2为正式技能合并
mount_drag_skill(Status,MountInfo,UpDown,Type,Id1,Id2) ->
	case Type of
		2 -> %%正式技能合并
			drag_mount_skill_normal(Status,MountInfo,UpDown,Id1,Id2);
		_ -> %%技能合并预览
			drag_mount_skill_preview(Status,MountInfo,UpDown,Id1,Id2)
	end.

drag_mount_skill_normal(Status,MountInfo,UpDown,Id1,Id2) ->
	%%从上拉到下
	if UpDown == 1 ->
			MountSkillSplitInfo = get_mount_skill_split(Id1),
			#ets_mount_skill_split{
							  id = MountSkillSplitId,skill_id = SkillId1,exp = SkillExp1,
							  color = SkillStep1, level = SkillLevel1,type = SkillType1 } = MountSkillSplitInfo,
			[Pos, SkillId2, SkillType2, SkillLevel2, SkillStep2, SkillExp2] = get_mount_skill(MountInfo,Id2),
			%%闲置技能阶数高于坐骑技能
			if SkillStep1 > SkillStep2 orelse (SkillStep1 == SkillStep2 andalso SkillLevel1 > SkillLevel2) ->
				   NewSkillId = SkillId1,
				   NewSkillStep = SkillStep1,
				   NewSkillLevel = SkillLevel1,
				   NewSkillType = SkillType1,
				   _Priority = 1;
			   %%闲置技能阶数等于或小于坐骑技能
			   true ->
				   NewSkillId = SkillId2,
				   NewSkillStep = SkillStep2,
				   NewSkillLevel = SkillLevel2,
				   NewSkillType = SkillType2,
				   _Priority = 2
			end,
			%%技能的颜色，当颜色为0或5时不能装备到坐骑上
			[_Type,Color] = data_mount:get_skill_type_color(SkillId1),
			%%判断此种技能id是否已学
			Boolean =  is_study_skill(MountInfo,SkillType1),
			%%已学技能数
			SkillNum = get_mount_skill_num(MountInfo), 
			MaxCell = data_mount:get_skill_num(MountInfo#ets_mount.step), 
			if MountSkillSplitInfo == [] ->
				   [5,<<>>,Status];%%没有匹配的闲置技能
			   Boolean == true andalso SkillId1 =/= SkillId2 ->
				   [6,<<>>,Status];%%坐骑已经拥有此种技能
			   Color < 1 orelse Color > 4 ->
				   [8,<<>>,Status];%%无用精魂和经验精魂不能装备到坐骑上
			   SkillId2 == 0 andalso SkillNum >= MaxCell ->
				   [11,<<>>,Status];%%此阶数不能装备新的坐骑技能
				true->
					%%StepSkillExp1 = data_mount:get_self_skill_exp(SkillStep1),
					%%TotalExp = SkillExp2+SkillExp1+StepSkillExp1,
					TotalExp = SkillExp2+SkillExp1,
					[NewLevel,NewExp,NewStep] = update_mount_skill_level(NewSkillLevel,NewSkillStep,TotalExp),
					NewSkill = util:term_to_string([Pos,NewSkillId,NewSkillType,NewLevel,NewStep,NewExp]),
					case Id2 of
						1 -> NewMountInfo = MountInfo#ets_mount{skill_1=NewSkill},OldSkill = MountInfo#ets_mount.skill_1,KeyValueList = [{skill_1,NewSkill}];
						2 -> NewMountInfo = MountInfo#ets_mount{skill_2=NewSkill},OldSkill = MountInfo#ets_mount.skill_2,KeyValueList = [{skill_2,NewSkill}];
						3 -> NewMountInfo = MountInfo#ets_mount{skill_3=NewSkill},OldSkill = MountInfo#ets_mount.skill_3,KeyValueList = [{skill_3,NewSkill}];
						4 -> NewMountInfo = MountInfo#ets_mount{skill_4=NewSkill},OldSkill = MountInfo#ets_mount.skill_4,KeyValueList = [{skill_4,NewSkill}];
						5 -> NewMountInfo = MountInfo#ets_mount{skill_5=NewSkill},OldSkill = MountInfo#ets_mount.skill_5,KeyValueList = [{skill_5,NewSkill}];
						6 -> NewMountInfo = MountInfo#ets_mount{skill_6=NewSkill},OldSkill = MountInfo#ets_mount.skill_6,KeyValueList = [{skill_6,NewSkill}];
						7 -> NewMountInfo = MountInfo#ets_mount{skill_7=NewSkill},OldSkill = MountInfo#ets_mount.skill_7,KeyValueList = [{skill_7,NewSkill}];
						8 -> NewMountInfo = MountInfo#ets_mount{skill_8=NewSkill},OldSkill = MountInfo#ets_mount.skill_8,KeyValueList = [{skill_8,NewSkill}]
					end,		
					update_mount(NewMountInfo),
					db_agent:update_mount(KeyValueList,[{id,MountInfo#ets_mount.id}]),
					%%同步斗兽榜
					spawn(fun()->lib_mount_arena:sync_mount_data(NewMountInfo) end),
					%%更新角色坐骑属性加成
					NewStatus = lib_mount:update_mount_attribute_effect(Status,NewMountInfo),
					delete_mount_skill_split(MountSkillSplitId),
					delete_mount_skill_split_db(MountSkillSplitId),
					pp_mount:handle(16012, NewStatus, NewMountInfo#ets_mount.id),
					%%添加精魂操作日志
					spawn(fun()->db_agent:log_mount_split_oper([MountSkillSplitId,Status#player.id,Status#player.nickname,MountInfo#ets_mount.id,SkillId1,SkillExp1,SkillStep1,SkillLevel1,SkillType1,0,0,OldSkill,NewSkill,1])end),
					
					[1,<<>>,NewStatus]
			end;
	   %%从下拉到上
	   UpDown == 2 ->
		    [_Pos, SkillId1, SkillType1, SkillLevel1, SkillStep1, SkillExp1] = get_mount_skill(MountInfo,Id1),
			MountSkillSplitInfo = get_mount_skill_split(Id2),
			if SkillId1 == 0 ->
				   [4,<<>>,Status];%%没有指定坐骑技能
			   true ->
				   %%主技能拖动到空闲置技能上
				   if MountSkillSplitInfo == [] ->
						   MountSkillSplitId = save_mount_skill_split(Status#player.id,SkillId1,SkillExp1,SkillStep1,SkillLevel1,SkillType1),
						   NewMountSkillSplitInfo = #ets_mount_skill_split{
							  id = MountSkillSplitId,
							  player_id = Status#player.id,
							  skill_id = SkillId1,
							  exp = SkillExp1,
							  color = SkillStep1,
							  level = SkillLevel1,
							  type = SkillType1							  
							},
						   update_mount_skill_split(NewMountSkillSplitInfo),
						   NewSkill = util:term_to_string([Id1,0,0,0,0,0]),
						   case Id1 of
							   1 -> NewMountInfo = MountInfo#ets_mount{skill_1=NewSkill},KeyValueList = [{skill_1,NewSkill}];
							   2 -> NewMountInfo = MountInfo#ets_mount{skill_2=NewSkill},KeyValueList = [{skill_2,NewSkill}];
							   3 -> NewMountInfo = MountInfo#ets_mount{skill_3=NewSkill},KeyValueList = [{skill_3,NewSkill}];
							   4 -> NewMountInfo = MountInfo#ets_mount{skill_4=NewSkill},KeyValueList = [{skill_4,NewSkill}];
							   5 -> NewMountInfo = MountInfo#ets_mount{skill_5=NewSkill},KeyValueList = [{skill_5,NewSkill}];
							   6 -> NewMountInfo = MountInfo#ets_mount{skill_6=NewSkill},KeyValueList = [{skill_6,NewSkill}];
							   7 -> NewMountInfo = MountInfo#ets_mount{skill_7=NewSkill},KeyValueList = [{skill_7,NewSkill}];
							   8 -> NewMountInfo = MountInfo#ets_mount{skill_8=NewSkill},KeyValueList = [{skill_8,NewSkill}]
						   end,
						   update_mount(NewMountInfo),
						   db_agent:update_mount(KeyValueList,[{id,MountInfo#ets_mount.id}]),
						   %%同步斗兽榜
						   spawn(fun()->lib_mount_arena:sync_mount_data(NewMountInfo) end),
						   %%更新角色坐骑属性加成
						   NewStatus = lib_mount:update_mount_attribute_effect(Status,NewMountInfo),
						   %%添加精魂操作日志
						   NewSkill1 = util:term_to_string([Id1,SkillId1,SkillType1,SkillLevel1,SkillStep1,SkillExp1]),
						   spawn(fun()->db_agent:log_mount_split_oper([MountSkillSplitId,Status#player.id,Status#player.nickname,MountInfo#ets_mount.id,SkillId1,SkillExp1,SkillStep1,SkillLevel1,SkillType1,0,0,"",NewSkill1,4])end),
						   [1,<<>>,NewStatus];						   
					  %%主技能拖动到闲置技能上
					  true ->
						  #ets_mount_skill_split{
							  id = MountSkillSplitId2,skill_id = SkillId2,exp = SkillExp2,
							  color = SkillStep2, level = SkillLevel2, type = SkillType2 } = MountSkillSplitInfo,
						  if SkillStep2 < 1 orelse SkillStep2 > 4 ->
								 [10,<<>>,Status];%%不能将坐骑技能拖动到无用精魂和经验精魂技能上
							 true ->
								 %%闲置技能阶数高于坐骑技能
								 if SkillStep1 > SkillStep2 orelse (SkillStep1 == SkillStep2 andalso SkillLevel1 > SkillLevel2) ->
										NewSkillId = SkillId1,
										NewSkillStep = SkillStep1,
										NewSkillType = SkillType1,
										NewSkillLevel = SkillLevel1;
									%%闲置技能阶数等于或小于坐骑技能
									true ->
										NewSkillId = SkillId2,
										NewSkillStep = SkillStep2,
										NewSkillType = SkillType2,
										NewSkillLevel = SkillLevel2
								 end,
								 %%StepSkillExp1 = data_mount:get_self_skill_exp(SkillStep1),
								 TotalExp = SkillExp2+SkillExp1,
								 [NewLevel,NewExp,NewStep] = update_mount_skill_level(NewSkillLevel,NewSkillStep,TotalExp),
								 NewMountSkillSplitInfo = #ets_mount_skill_split{
																id = MountSkillSplitId2,
																player_id = Status#player.id,
																skill_id = NewSkillId,
																exp = NewExp,
																color = NewStep,
																level = NewLevel,
																type = NewSkillType
															},
								 update_mount_skill_split(NewMountSkillSplitInfo),
								 update_mount_skill_split([{skill_id,NewSkillId},{exp,NewExp},{color,NewStep},{level,NewLevel},{type,NewSkillType}], [{id,MountSkillSplitId2}]),
								 NewSkill = util:term_to_string([Id1,0,0,0,0,0]),
								 case Id1 of
									 1 -> NewMountInfo = MountInfo#ets_mount{skill_1=NewSkill},KeyValueList = [{skill_1,NewSkill}];
									 2 -> NewMountInfo = MountInfo#ets_mount{skill_2=NewSkill},KeyValueList = [{skill_2,NewSkill}];
									 3 -> NewMountInfo = MountInfo#ets_mount{skill_3=NewSkill},KeyValueList = [{skill_3,NewSkill}];
									 4 -> NewMountInfo = MountInfo#ets_mount{skill_4=NewSkill},KeyValueList = [{skill_4,NewSkill}];
									 5 -> NewMountInfo = MountInfo#ets_mount{skill_5=NewSkill},KeyValueList = [{skill_5,NewSkill}];
									 6 -> NewMountInfo = MountInfo#ets_mount{skill_6=NewSkill},KeyValueList = [{skill_6,NewSkill}];
									 7 -> NewMountInfo = MountInfo#ets_mount{skill_7=NewSkill},KeyValueList = [{skill_7,NewSkill}];
									 8 -> NewMountInfo = MountInfo#ets_mount{skill_8=NewSkill},KeyValueList = [{skill_8,NewSkill}]
								 end,
								 update_mount(NewMountInfo),
								 db_agent:update_mount(KeyValueList,[{id,MountInfo#ets_mount.id}]),
								 %%同步斗兽榜
								 spawn(fun()->lib_mount_arena:sync_mount_data(NewMountInfo) end),
								 %%更新角色坐骑属性加成s
								 NewStatus = lib_mount:update_mount_attribute_effect(Status,NewMountInfo),
								 NewSkill1 = util:term_to_string([Id1,NewSkillId,NewSkillType,NewLevel,NewStep,NewExp]),
						   		 spawn(fun()->db_agent:log_mount_split_oper([MountSkillSplitId2,Status#player.id,Status#player.nickname,MountInfo#ets_mount.id,SkillId1,SkillExp1,SkillStep1,SkillLevel1,SkillType1,0,0,"",NewSkill1,4])end),
								 [1,<<>>,NewStatus]
						  end
				   end
				   
			end;
	   %%闲置技能左右拖动
		true ->
			MountSkillSplitInfo1 = get_mount_skill_split(Id1),
			MountSkillSplitInfo2 = get_mount_skill_split(Id2),
			 #ets_mount_skill_split{
							  id = MountSkillSplitId1,skill_id = SkillId1,exp = SkillExp1,
							  color = SkillStep1, level = SkillLevel1,type = SkillType1 } = MountSkillSplitInfo1,
				   #ets_mount_skill_split{
							  id = MountSkillSplitId2,skill_id = SkillId2,exp = SkillExp2,
							  color = SkillStep2, level = SkillLevel2,type = SkillType2 } = MountSkillSplitInfo2,
			%%技能的颜色，当颜色为0或5时不能装备到坐骑上
			[_Type1,Color1] = data_mount:get_skill_type_color(SkillId1),
			%%技能的颜色，当颜色为0或5时不能装备到坐骑上
			[_Type2,Color2] = data_mount:get_skill_type_color(SkillId2),
			if MountSkillSplitInfo1 == [] orelse MountSkillSplitInfo2 == [] ->
				   [7,<<>>,Status];%%需要指定两个闲置技能
			   Color1 < 1 orelse Color1 > 4  orelse Color2 < 1 orelse Color2 > 4 ->
				   [9,<<>>,Status];%%无用精魂和经验精魂不能拖动	
			   true ->
				   %%闲置技能阶数高于坐骑技能
				   if SkillStep1 > SkillStep2 orelse (SkillStep1 == SkillStep2 andalso SkillLevel1 > SkillLevel2) ->
						  NewSkillId = SkillId1,
						  NewSkillStep = SkillStep1,
						  NewSkillType = SkillType1,
						  NewSkillLevel = SkillLevel1,
						  Priority = 1;
					  %%闲置技能阶数等于或小于坐骑技能
					  true ->
						  NewSkillId = SkillId2,
						  NewSkillStep = SkillStep2,
						  NewSkillType = SkillType2,
						  NewSkillLevel = SkillLevel2,
						  Priority = 2
				   end,
				   %%StepSkillExp1 = data_mount:get_self_skill_exp(SkillStep1),
				   TotalExp = SkillExp2+SkillExp1,
				   [NewLevel,NewExp,NewStep] = update_mount_skill_level(NewSkillLevel,NewSkillStep,TotalExp),
				   if Priority == 1 ->
						  NewMountSkillSplitInfo = #ets_mount_skill_split{
							  id = MountSkillSplitId1,
							  player_id = Status#player.id,
							  skill_id = NewSkillId,
							  exp = NewExp,
							  color = NewStep,
							  level = NewLevel,
							  type = NewSkillType							  
							},
						  update_mount_skill_split(NewMountSkillSplitInfo),
						  update_mount_skill_split([{skill_id,NewSkillId},{exp,NewExp},{color,NewStep},{level,NewLevel},{type,NewSkillType}], [{id,MountSkillSplitId1}]),
						  delete_mount_skill_split(MountSkillSplitId2),
						  delete_mount_skill_split_db(MountSkillSplitId2);
					  true ->
						  NewMountSkillSplitInfo = #ets_mount_skill_split{
							  id = MountSkillSplitId2,
							  player_id = Status#player.id,
							  skill_id = NewSkillId,
							  exp = NewExp,
							  color = NewStep,
							  level = NewLevel,
							  type = NewSkillType							  
							},
						  update_mount_skill_split(NewMountSkillSplitInfo),
						  update_mount_skill_split([{skill_id,NewSkillId},{exp,NewExp},{color,NewStep},{level,NewLevel},{type,NewSkillType}], [{id,MountSkillSplitId2}]),
						  delete_mount_skill_split(MountSkillSplitId1),
						  delete_mount_skill_split_db(MountSkillSplitId1)
				   end,
				   [1,<<>>,Status]
			end
	end.
	

drag_mount_skill_preview(Status,MountInfo,UpDown,Id1,Id2) ->
	%%从上拉到下
	if UpDown == 1 ->
			MountSkillSplitInfo = get_mount_skill_split(Id1),
			#ets_mount_skill_split{
							  id = _MountSkillSplitId,skill_id = SkillId1,exp = SkillExp1,
							  color = SkillStep1, level = SkillLevel1,type = SkillType1	} = MountSkillSplitInfo,
			[_Pos, SkillId2, _SkillType2, SkillLevel2, SkillStep2, SkillExp2] = get_mount_skill(MountInfo,Id2),
			%%闲置技能阶数高于坐骑技能
			if SkillStep1 > SkillStep2 orelse (SkillStep1 == SkillStep2 andalso SkillLevel1 > SkillLevel2) ->
				   _NewSkillId = SkillId1,
				   NewSkillStep = SkillStep1,
				   NewSkillLevel = SkillLevel1,
				   Priority = 1;
			   %%闲置技能阶数等于或小于坐骑技能
			   true ->
				   _NewSkillId = SkillId2,
				   NewSkillStep = SkillStep2,
				   NewSkillLevel = SkillLevel2,
				   Priority = 2
			end,
			%%技能的颜色，当颜色为0或5时不能装备到坐骑上
			[_Type,Color] = data_mount:get_skill_type_color(SkillId1),
			%%判断此种技能id是否已学
			Boolean = is_study_skill(MountInfo,SkillType1),
			StepSkillExp1 = data_mount:get_self_skill_exp(SkillStep1),
			TotalExp = SkillExp2+SkillExp1,
			[NewLevel,_NewExp,_NewStep] = update_mount_skill_level(NewSkillLevel,NewSkillStep,TotalExp),
			%%已学技能数
			SkillNum = get_mount_skill_num(MountInfo), 
			MaxCell = data_mount:get_skill_num(MountInfo#ets_mount.step), 
			if MountSkillSplitInfo == [] ->
					[5,<<>>,Status];%%没有匹配的闲置技能
			   Boolean == true andalso SkillId1 =/= SkillId2 ->
				   [6,<<>>,Status];%%坐骑已经拥有此种技能
			   Color < 1 orelse Color > 4 ->
				   [8,<<>>,Status];%%无用精魂和经验精魂不能装备到坐骑上
			   SkillId2 == 0 andalso SkillNum >= MaxCell ->
				   [11,<<>>,Status];%%此阶数不能装备新的坐骑技能
				true->
					if Priority == 1 ->
								  if NewLevel > SkillLevel1 ->
										 Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,并升到~p级！！ ",[data_mount:get_skill_name_color(SkillStep1),SkillStep1,data_mount:get_skill_name(SkillId1),data_mount:get_skill_name_color(SkillStep2),SkillStep2,data_mount:get_skill_name(SkillId2),SkillExp1+StepSkillExp1,NewLevel]);
									 true ->
										 Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_mount:get_skill_name_color(SkillStep1),SkillStep1,data_mount:get_skill_name(SkillId1),data_mount:get_skill_name_color(SkillStep2),SkillStep2,data_mount:get_skill_name(SkillId2),SkillExp1+StepSkillExp1])
								  end;
							  true ->
								  if NewLevel > SkillLevel2 ->
										 Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,并升到【~p】级！！ ",[data_mount:get_skill_name_color(SkillStep2),SkillStep2,data_mount:get_skill_name(SkillId2),data_mount:get_skill_name_color(SkillStep1),SkillStep1,data_mount:get_skill_name(SkillId1),SkillExp1+StepSkillExp1,NewLevel]);
									 true ->
										 Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_mount:get_skill_name_color(SkillStep2),SkillStep2,data_mount:get_skill_name(SkillId2),data_mount:get_skill_name_color(SkillStep1),SkillStep1,data_mount:get_skill_name(SkillId1),SkillExp1+StepSkillExp1])
								  end
						   end,
					[1,Content,Status]
			end;
	   %%从下拉到上
	   UpDown == 2 ->
		    [_Pos, SkillId1, _SkillType1, SkillLevel1, SkillStep1, SkillExp1] = get_mount_skill(MountInfo,Id1),
			StepSkillExp1 = data_mount:get_self_skill_exp(SkillStep1),
			MountSkillSplitInfo = get_mount_skill_split(Id2),
			if SkillId1 == 0 ->
				   [4,<<>>,Status];%%没有指定坐骑技能
			   true ->
				   if MountSkillSplitInfo == [] ->
						  Content = io_lib:format("确定分离此坐骑技能？",[]),
						  [1,Content,Status];
					  true ->
						  #ets_mount_skill_split{
							  id = _MountSkillSplitId,skill_id = SkillId2,exp = SkillExp2,
							  color = SkillStep2, level = SkillLevel2,type = _SkillType2 } = MountSkillSplitInfo,
						  if SkillStep2 < 1 orelse SkillStep2 > 4 ->
								 [10,<<>>,Status];%%不能将坐骑技能拖动到无用精魂和经验精魂技能上
							 true ->
								 %%闲置技能阶数高于坐骑技能
								 if SkillStep1 > SkillStep2 orelse (SkillStep1 == SkillStep2 andalso SkillLevel1 > SkillLevel2) ->
										_NewSkillId = SkillId1,
										NewSkillStep = SkillStep1,
										NewSkillLevel = SkillLevel1,
										Priority = 1;
									%%闲置技能阶数等于或小于坐骑技能
									true ->
										_NewSkillId = SkillId2,
										NewSkillStep = SkillStep2,
										NewSkillLevel = SkillLevel2,
										Priority = 2
								 end,
								 TotalExp = SkillExp2+SkillExp1,
								 [NewLevel,_NewExp,_NewStep] = update_mount_skill_level(NewSkillLevel,NewSkillStep,TotalExp),
								 if Priority == 1 ->
										if NewLevel > SkillLevel1 ->
											   Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,并升到【~p】级！！ ",[data_mount:get_skill_name_color(SkillStep1),SkillStep1,data_mount:get_skill_name(SkillId1),data_mount:get_skill_name_color(SkillStep2),SkillStep2,data_mount:get_skill_name(SkillId2),SkillExp1+StepSkillExp1,NewLevel]);
										   true ->
											   Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_mount:get_skill_name_color(SkillStep1),SkillStep1,data_mount:get_skill_name(SkillId1),data_mount:get_skill_name_color(SkillStep2),SkillStep2,data_mount:get_skill_name(SkillId2),SkillExp1+StepSkillExp1])
										end;
									true ->
										if NewLevel > SkillLevel2 ->
											   Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,并升到【~p】级！！ ",[data_mount:get_skill_name_color(SkillStep2),SkillStep2,data_mount:get_skill_name(SkillId2),data_mount:get_skill_name_color(SkillStep1),SkillStep1,data_mount:get_skill_name(SkillId1),SkillExp1+StepSkillExp1,NewLevel]);
										   true ->
											   Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_mount:get_skill_name_color(SkillStep2),SkillStep2,data_mount:get_skill_name(SkillId2),data_mount:get_skill_name_color(SkillStep1),SkillStep1,data_mount:get_skill_name(SkillId1),SkillExp1+StepSkillExp1])
										end
								 end,
								 [1,Content,Status]
						  end
				   end
			end;
	   %%闲置技能左右拖动
		true ->
			MountSkillSplitInfo1 = get_mount_skill_split(Id1),
			MountSkillSplitInfo2 = get_mount_skill_split(Id2),
			#ets_mount_skill_split{
							  id = _MountSkillSplitId1,skill_id = SkillId1,exp = SkillExp1,
							  color = SkillStep1, level = SkillLevel1,type = _SkillType1 } = MountSkillSplitInfo1,
				   #ets_mount_skill_split{
							  id = _MountSkillSplitId2,skill_id = SkillId2,exp = SkillExp2,
							  color = SkillStep2, level = SkillLevel2,type = _SkillType2 } = MountSkillSplitInfo2,
			%%技能的颜色，当颜色为0或5时不能装备到坐骑上
			[_Type1,Color1] = data_mount:get_skill_type_color(SkillId1),
			%%技能的颜色，当颜色为0或5时不能装备到坐骑上
			[_Type2,Color2] = data_mount:get_skill_type_color(SkillId2),
			if MountSkillSplitInfo1 == [] orelse MountSkillSplitInfo2 == [] ->
				   [7,<<>>,Status];%%需要指定两个闲置技能
			   Color1 < 1 orelse Color1 > 4  orelse Color2 < 1 orelse Color2 > 4 ->
				   [9,<<>>,Status];%%无用精魂和经验精魂不能拖动			   
			   true ->
				   %%闲置技能阶数高于坐骑技能
				   if SkillStep1 > SkillStep2 orelse (SkillStep1 == SkillStep2 andalso SkillLevel1 > SkillLevel2) ->
						  _NewSkillId = SkillId1,
						  NewSkillStep = SkillStep1,
						  NewSkillLevel = SkillLevel1,
						  Priority = 1;
					  %%闲置技能阶数等于或小于坐骑技能
					  true ->
						  _NewSkillId = SkillId2,
						  NewSkillStep = SkillStep2,
						  NewSkillLevel = SkillLevel2,
						  Priority = 2
				   end,
				   StepSkillExp1 = data_mount:get_self_skill_exp(SkillStep1),
				   TotalExp = SkillExp2+SkillExp1,
				   [NewLevel,_NewExp,_NewStep] = update_mount_skill_level(NewSkillLevel,NewSkillStep,TotalExp),
				    if Priority == 1 ->
						   if NewLevel > SkillLevel1 ->
								  Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,并升到【~p】级！！ ",[data_mount:get_skill_name_color(SkillStep1),SkillStep1,data_mount:get_skill_name(SkillId1),data_mount:get_skill_name_color(SkillStep2),SkillStep2,data_mount:get_skill_name(SkillId2),SkillExp1+StepSkillExp1,NewLevel]);
							  true ->
								  Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_mount:get_skill_name_color(SkillStep1),SkillStep1,data_mount:get_skill_name(SkillId1),data_mount:get_skill_name_color(SkillStep2),SkillStep2,data_mount:get_skill_name(SkillId2),SkillExp1+StepSkillExp1])
						   end;
					   true ->
						   if NewLevel > SkillLevel2 ->
								  Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,并升到【~p】级！！ ",[data_mount:get_skill_name_color(SkillStep2),SkillStep2,data_mount:get_skill_name(SkillId2),data_mount:get_skill_name_color(SkillStep1),SkillStep1,data_mount:get_skill_name(SkillId1),SkillExp1+StepSkillExp1,NewLevel]);
							  true ->
								  Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_mount:get_skill_name_color(SkillStep2),SkillStep2,data_mount:get_skill_name(SkillId2),data_mount:get_skill_name_color(SkillStep1),SkillStep1,data_mount:get_skill_name(SkillId1),SkillExp1+StepSkillExp1])
						   end
				   end,
				   [1,Content,Status]
			end
	end.
	
	
%%萃取
skill_fetch(Status,MountSkillSplitInfo) ->
	fetch(Status,MountSkillSplitInfo),
	1.

%%一键萃取
one_key_skill_fetch(Status,MountSkillSplitList) ->
	F =fun(MountSkillSplitInfo) ->
			#ets_mount_skill_split{
			id = MountSkillSplitId,skill_id = SkillId,exp = SkillExp,
			color = SkillStep, level = SkillLevel,type = SkillType } = MountSkillSplitInfo,
			StepSkillExp1 = data_mount:get_self_skill_exp(SkillStep),
			delete_mount_skill_split(MountSkillSplitId),
		    delete_mount_skill_split_db(MountSkillSplitId),
			%%添加精魂操作日志
			spawn(fun()->db_agent:log_mount_split_oper([MountSkillSplitId,Status#player.id,Status#player.nickname,0,SkillId,SkillStep,SkillStep,SkillLevel,SkillType,0,SkillExp+StepSkillExp1	,"","",3])end),
			SkillExp+StepSkillExp1			
	   end,	
	MountSkillExpInfo = lib_mount:mount_5_btn(Status#player.id),
	TotalSkillExp = lists:sum([F(MountSkillSplitInfo)||MountSkillSplitInfo <- MountSkillSplitList,
													   (MountSkillSplitInfo#ets_mount_skill_split.color == 5 orelse (MountSkillSplitInfo#ets_mount_skill_split.color > 0 andalso MountSkillSplitInfo#ets_mount_skill_split.color =< MountSkillExpInfo#ets_mount_skill_exp.auto_step))]),
	
	NewMountSkillExpInfo = MountSkillExpInfo#ets_mount_skill_exp{total_exp = MountSkillExpInfo#ets_mount_skill_exp.total_exp+TotalSkillExp},
	KeyValueList = [{total_exp,NewMountSkillExpInfo#ets_mount_skill_exp.total_exp}],
	update_mount_skill_exp(NewMountSkillExpInfo),
	update_mount_skill_exp(KeyValueList, [{id,NewMountSkillExpInfo#ets_mount_skill_exp.id}]),
	if TotalSkillExp > 0 ->
		  Msg = io_lib:format("萃取获得经验~p",[TotalSkillExp]),
		  {ok,MyBin} = pt_16:write(16041,[Msg]),
		  lib_send:send_to_sid(Status#player.other#player_other.pid_send,MyBin);
	   true ->
		 skip
	 end,
	if TotalSkillExp == 0 ->
		   2;%%有符合条件的精魂
	   true ->
		   1
	end.
	
fetch(Status,MountSkillSplitInfo) ->
	MountSkillExpInfo = lib_mount:mount_5_btn(Status#player.id),
	#ets_mount_skill_split{
			id = MountSkillSplitId,skill_id = SkillId,exp = SkillExp,
			color = SkillStep, level = SkillLevel,type = SkillType } = MountSkillSplitInfo,
	TotalSkillExp = data_mount:get_self_skill_exp(SkillStep) + SkillExp,
	if SkillStep =/= 0 ->
		   delete_mount_skill_split(MountSkillSplitId),
		   delete_mount_skill_split_db(MountSkillSplitId),
		   NewMountSkillExpInfo = MountSkillExpInfo#ets_mount_skill_exp{total_exp = MountSkillExpInfo#ets_mount_skill_exp.total_exp+TotalSkillExp},
		   KeyValueList = [{total_exp,NewMountSkillExpInfo#ets_mount_skill_exp.total_exp}],
		   update_mount_skill_exp(NewMountSkillExpInfo),
		   update_mount_skill_exp(KeyValueList, [{id,NewMountSkillExpInfo#ets_mount_skill_exp.id}]),
		   HasMsg = 1;
	   true ->
		    HasMsg = 0
	end,
	%%添加精魂操作日志
	spawn(fun()->db_agent:log_mount_split_oper([MountSkillSplitId,Status#player.id,Status#player.nickname,0,SkillId,SkillExp,SkillStep,SkillLevel,SkillType,0,TotalSkillExp,"","",3])end),
	
	if HasMsg == 1 ->
		  Msg = io_lib:format("萃取获得经验~p",[TotalSkillExp]),
		  {ok,MyBin} = pt_16:write(16041,[Msg]),
		  lib_send:send_to_sid(Status#player.other#player_other.pid_send,MyBin);
	   true ->
		 skip
	 end.
 	 
	

%%卖出
skill_sell(Status,MountSkillSplitInfo) ->
	sell(MountSkillSplitInfo),
	if MountSkillSplitInfo#ets_mount_skill_split.color == 0 andalso MountSkillSplitInfo#ets_mount_skill_split.player_id == Status#player.id ->
		   NewStatus = Status#player{cash=Status#player.cash+1};
	   true ->
		   NewStatus = Status
	end,
	%%添加精魂操作日志
	spawn(fun()->db_agent:log_mount_split_oper([MountSkillSplitInfo#ets_mount_skill_split.id,Status#player.id,Status#player.nickname,0,MountSkillSplitInfo#ets_mount_skill_split.skill_id,
												MountSkillSplitInfo#ets_mount_skill_split.exp,MountSkillSplitInfo#ets_mount_skill_split.color,MountSkillSplitInfo#ets_mount_skill_split.level,
												MountSkillSplitInfo#ets_mount_skill_split.type,1,0,"","",2])end),
	
	lib_player:send_player_attribute(NewStatus,2),
	db_agent:mm_update_player_info([{cash,NewStatus#player.cash}], [{id,NewStatus#player.id}]),
	[1,NewStatus].

%%一键卖出
one_key_skill_sell(Status,MountSkillSplitList) ->
	NewMountSkillSplitList = [MountSkillSplitInfo||MountSkillSplitInfo <- MountSkillSplitList,MountSkillSplitInfo#ets_mount_skill_split.color == 0 andalso MountSkillSplitInfo#ets_mount_skill_split.player_id == Status#player.id],
	if NewMountSkillSplitList == [] ->
		   [2,Status];%%没有可卖出精魂
	   true ->
		   [sell(MountSkillSplitInfo)||MountSkillSplitInfo <- NewMountSkillSplitList],
		   NewStatus = Status#player{cash=Status#player.cash+length(NewMountSkillSplitList)},
		   lib_player:send_player_attribute(NewStatus,2),
		   db_agent:mm_update_player_info([{cash,NewStatus#player.cash}], [{id,NewStatus#player.id}]),
		   [1,NewStatus]
	end.

sell(MountSkillSplitInfo) ->
	delete_mount_skill_split(MountSkillSplitInfo#ets_mount_skill_split.id),
	delete_mount_skill_split_db(MountSkillSplitInfo#ets_mount_skill_split.id).

%%一键吞噬
one_key_skill_eat(PlayerId,MountSkillSplitList) ->
	F =fun(MountSkillSplitInfo) ->
			#ets_mount_skill_split{
			id = MountSkillSplitId,skill_id = _SkillId,exp = SkillExp,
			color = SkillStep, level = _SkillLevel,type = _SkillType } = MountSkillSplitInfo,
			StepSkillExp1 = data_mount:get_self_skill_exp(SkillStep),
			delete_mount_skill_split(MountSkillSplitId),
		    delete_mount_skill_split_db(MountSkillSplitId),
			SkillExp+StepSkillExp1			
	   end,	
	TotalSkillExp = lists:sum([F(MountSkillSplitInfo)||MountSkillSplitInfo <- MountSkillSplitList,MountSkillSplitInfo#ets_mount_skill_split.color >1,MountSkillSplitInfo#ets_mount_skill_split.player_id ==PlayerId]),
	MountSkillExpInfo = lib_mount:mount_5_btn(PlayerId),
	NewMountSkillExpInfo = MountSkillExpInfo#ets_mount_skill_exp{total_exp = TotalSkillExp},
	KeyValueList = [{total_exp,TotalSkillExp}],
	update_mount_skill_exp(NewMountSkillExpInfo),
	update_mount_skill_exp(KeyValueList, [{id,NewMountSkillExpInfo#ets_mount_skill_exp.id}]),
	1.

%%添加技能经验 坐骑技能位置(1-8)
add_skill_exp(Status,MountInfo,Pos) ->
	MountSkillExpInfo = lib_mount:mount_5_btn(Status#player.id),
	TotalExp = MountSkillExpInfo#ets_mount_skill_exp.total_exp,
	[_Pos, SkillId, SkillType, SkillLevel, SkillStep, SkillExp] = get_mount_skill(MountInfo,Pos), 
	if SkillLevel == 10 ->
		   [3,<<>>,Status];
	   true ->
		   NextLevelExp = data_mount:get_skill_upgrade_exp(SkillLevel,SkillStep),
		   if TotalExp+SkillExp < NextLevelExp ->
				  NewMountSkillExpInfo = MountSkillExpInfo#ets_mount_skill_exp{total_exp = 0},
				  KeyValueList = [{total_exp,0}],
				  update_mount_skill_exp(NewMountSkillExpInfo),
				  update_mount_skill_exp(KeyValueList, [{id,NewMountSkillExpInfo#ets_mount_skill_exp.id}]),
				  NewSkill = util:term_to_string([Pos,SkillId,SkillType,SkillLevel,SkillStep,TotalExp+SkillExp]),
				  case Pos of
					  1 -> NewMountInfo = MountInfo#ets_mount{skill_1=NewSkill},KeyValueList1 = [{skill_1,NewSkill}];
					  2 -> NewMountInfo = MountInfo#ets_mount{skill_2=NewSkill},KeyValueList1 = [{skill_2,NewSkill}];
					  3 -> NewMountInfo = MountInfo#ets_mount{skill_3=NewSkill},KeyValueList1 = [{skill_3,NewSkill}];
					  4 -> NewMountInfo = MountInfo#ets_mount{skill_4=NewSkill},KeyValueList1 = [{skill_4,NewSkill}];
					  5 -> NewMountInfo = MountInfo#ets_mount{skill_5=NewSkill},KeyValueList1 = [{skill_5,NewSkill}];
					  6 -> NewMountInfo = MountInfo#ets_mount{skill_6=NewSkill},KeyValueList1 = [{skill_6,NewSkill}];
					  7 -> NewMountInfo = MountInfo#ets_mount{skill_7=NewSkill},KeyValueList1 = [{skill_7,NewSkill}];
					  8 -> NewMountInfo = MountInfo#ets_mount{skill_8=NewSkill},KeyValueList1 = [{skill_8,NewSkill}]
				  end,
				  update_mount(NewMountInfo),
				  db_agent:update_mount(KeyValueList1,[{id,MountInfo#ets_mount.id}]),
				  NewSkillLevel = SkillLevel,
				  AddExp = TotalExp,
				  NewStatus = Status;
			  true ->
				  NewMountSkillExpInfo = MountSkillExpInfo#ets_mount_skill_exp{total_exp = (TotalExp-(NextLevelExp-SkillExp))},
				  KeyValueList = [{total_exp,(TotalExp-(NextLevelExp-SkillExp))}],
				  update_mount_skill_exp(NewMountSkillExpInfo),
				  update_mount_skill_exp(KeyValueList, [{id,NewMountSkillExpInfo#ets_mount_skill_exp.id}]),
				  NewSkill = util:term_to_string([Pos,SkillId,SkillType,SkillLevel+1,SkillStep,NextLevelExp]),
				  case Pos of
					  1 -> NewMountInfo = MountInfo#ets_mount{skill_1=NewSkill},KeyValueList1 = [{skill_1,NewSkill}];
					  2 -> NewMountInfo = MountInfo#ets_mount{skill_2=NewSkill},KeyValueList1 = [{skill_2,NewSkill}];
					  3 -> NewMountInfo = MountInfo#ets_mount{skill_3=NewSkill},KeyValueList1 = [{skill_3,NewSkill}];
					  4 -> NewMountInfo = MountInfo#ets_mount{skill_4=NewSkill},KeyValueList1 = [{skill_4,NewSkill}];
					  5 -> NewMountInfo = MountInfo#ets_mount{skill_5=NewSkill},KeyValueList1 = [{skill_5,NewSkill}];
					  6 -> NewMountInfo = MountInfo#ets_mount{skill_6=NewSkill},KeyValueList1 = [{skill_6,NewSkill}];
					  7 -> NewMountInfo = MountInfo#ets_mount{skill_7=NewSkill},KeyValueList1 = [{skill_7,NewSkill}];
					  8 -> NewMountInfo = MountInfo#ets_mount{skill_8=NewSkill},KeyValueList1 = [{skill_8,NewSkill}]
				  end,
				  update_mount(NewMountInfo),
				  db_agent:update_mount(KeyValueList1,[{id,MountInfo#ets_mount.id}]),
				  %%同步斗兽榜
				  spawn(fun()->lib_mount_arena:sync_mount_data(NewMountInfo) end),
				  %%更新角色坐骑属性加成
				  NewStatus = lib_mount:update_mount_attribute_effect(Status,NewMountInfo),
				  NewSkillLevel = SkillLevel+1,
				  AddExp = NextLevelExp-SkillExp
		   end,
		   if NewSkillLevel > SkillLevel  ->
				  Content = io_lib:format("<font color='~s'>[~s]</font>获得~p经验,升到~p级！！ ",[data_mount:get_skill_name_color(SkillStep),data_mount:get_skill_name(SkillId),AddExp,NewSkillLevel]);
			  true ->
				  Content = io_lib:format("<font color='~s'>[~s]</font>获得~p经验！！ ",[data_mount:get_skill_name_color(SkillStep),data_mount:get_skill_name(SkillId),AddExp])
		   end,
		   [1,Content,NewStatus]
	end.


%%坐骑图鉴列表
get_all_type(PlayerId) ->
	 MountSkillExpInfo = lib_mount:mount_5_btn(PlayerId),
	 if is_record(MountSkillExpInfo,ets_mount_skill_exp) ->
			MountTypeIdList = util:string_to_term(tool:to_list(MountSkillExpInfo#ets_mount_skill_exp.active_type)),
			MountTypeIdList;
		true ->
			[]
	 end.
	
%%坐骑图鉴切换
change_active_type(PlayerStatus,MountInfo,GoodsTypeId) ->
	case PlayerStatus#player.mount of
		%%原来没有坐骑
		0 ->
			 NewMountInfo = MountInfo#ets_mount{goods_id=GoodsTypeId,icon = 0},KeyValueList = [{goods_id,GoodsTypeId},{icon,0}],
			 update_mount(NewMountInfo),
			 db_agent:update_mount(KeyValueList,[{id,MountInfo#ets_mount.id}]),
			 %%进阶成功后同步更新坐骑对应的物品goods_id
			 GoodsInfo = goods_util:get_goods(MountInfo#ets_mount.id),
			 NewGoodsInfo = GoodsInfo#goods{goods_id = GoodsTypeId,icon = 0},
			 ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
			 db_agent:update_goods([{goods_id,GoodsTypeId}],[{id,MountInfo#ets_mount.id}]),
			%%同步到斗兽
			%%?DEBUG("CHANGE MOUNT ICON = ~p~n.............",[GoodsTypeId]),
			spawn(fun()->lib_mount_arena:sync_mount_data(NewMountInfo#ets_mount{goods_id = GoodsTypeId})end),
			[1,GoodsTypeId,PlayerStatus];			
		%%有坐骑
		OldMountId ->			
			%%新旧相同则卸下
			case OldMountId =/= MountInfo#ets_mount.id of
				true ->
					%%?DEBUG("LIB_MOUNT change_active_type..... ~n",[]),
					[5,GoodsTypeId,PlayerStatus];
				%%不同则先卸旧装备新
				false ->
%% 					PlayerStatus2 = get_off_mount(PlayerStatus,MountInfo),
%% 					NewMountInfo = MountInfo#ets_mount{goods_id=GoodsTypeId},KeyValueList = [{goods_id,GoodsTypeId}],
%% 					update_mount(NewMountInfo),
%% 					db_agent:update_mount(KeyValueList,[{id,MountInfo#ets_mount.id}]),	
%% 					NewPlayerStatus = get_on_mount(PlayerStatus2,NewMountInfo),
					
					
					NewMountInfo = MountInfo#ets_mount{goods_id=GoodsTypeId,icon=0},KeyValueList = [{goods_id,GoodsTypeId},{icon,0}],
					update_mount(NewMountInfo),
					db_agent:update_mount(KeyValueList,[{id,MountInfo#ets_mount.id}]),	
					
					[Wq, Yf, _Fbyf,_Spyf,_Zq] = PlayerStatus#player.other#player_other.equip_current,
					if NewMountInfo#ets_mount.icon > 0 ->
						   NewMountTypeId = NewMountInfo#ets_mount.icon;
					   true ->
						   NewMountTypeId = NewMountInfo#ets_mount.goods_id
					end,
					Equip_current = [Wq, Yf, _Fbyf,_Spyf,NewMountTypeId],
					NewPlayerStatus = PlayerStatus#player{
                           mount = MountInfo#ets_mount.id,
						   other = PlayerStatus#player.other#player_other{
                           		equip_current = Equip_current,
								mount_stren = MountInfo#ets_mount.stren
								}
					},
					MountPlayer = lib_player:player_speed_count(NewPlayerStatus),
					spawn(fun()->db_agent:change_mount_status(MountInfo#ets_mount.id,NewPlayerStatus#player.id)end),
					{ok, BinData} = pt_12:write(12010, [NewPlayerStatus#player.id, MountPlayer#player.speed, NewMountTypeId,MountInfo#ets_mount.id,MountInfo#ets_mount.stren]),
					mod_scene_agent:send_to_area_scene(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, BinData),
					
					%%进阶成功后同步更新坐骑对应的物品goods_id
					GoodsInfo = goods_util:get_goods(MountInfo#ets_mount.id),
					NewGoodsInfo = GoodsInfo#goods{goods_id = GoodsTypeId,icon = 0},
					ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
					db_agent:update_goods([{goods_id,GoodsTypeId},{icon,0}],[{id,MountInfo#ets_mount.id}]),
					%%同步到斗兽
					%%?DEBUG("CHANGE MOUNT ICON = ~p~n.............",[GoodsTypeId]),
					spawn(fun()->lib_mount_arena:sync_mount_data(MountInfo#ets_mount{goods_id = GoodsTypeId})end),
					[1,GoodsTypeId,MountPlayer]			
			end
	end.

%%坐骑变身卡
use_mount_card(PlayerStatus,GoodsBuffs,Mount,GoodsInfo,ResultMountType) ->
	Mount1 = Mount#ets_mount{icon = ResultMountType},
	lib_mount:update_mount(Mount1),
	spawn(fun()-> db_agent:update_mount([{icon,ResultMountType}], [{id,Mount1#ets_mount.id}]) end),
	%%刷新新坐骑
	pp_mount:handle(16012, PlayerStatus,Mount1#ets_mount.id),
	[Wq, Yf, _Fbyf,_Spyf, _Zq] = 
	PlayerStatus#player.other#player_other.equip_current,
	if Mount1#ets_mount.icon > 0 ->
		   NewMountTypeId = Mount1#ets_mount.icon;
	   true ->
		   NewMountTypeId = Mount1#ets_mount.goods_id
	end,
	Equip_current = [Wq, Yf, _Fbyf,_Spyf, NewMountTypeId],
	NewPlayerStatus = PlayerStatus#player{
                    mount = Mount1#ets_mount.id,
					other = PlayerStatus#player.other#player_other{
                    equip_current = Equip_current,
					mount_stren = Mount1#ets_mount.stren}},
	NewPlayer = lib_player:player_speed_count(NewPlayerStatus),
	{ok, BinData} = pt_12:write(12010, [NewPlayerStatus#player.id, NewPlayer#player.speed, NewMountTypeId,Mount1#ets_mount.id,Mount1#ets_mount.stren]),
	mod_scene_agent:send_to_area_scene(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, BinData),
	%%改变物品外形
	NewGoodsInfo = GoodsInfo#goods{icon = ResultMountType}, 
	ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
	db_agent:update_goods([{icon, ResultMountType}],[{id,Mount1#ets_mount.id}]),
	case lists:keyfind(31217, 1, GoodsBuffs) of
			   false ->
				   NewGoodsBuffs = {no_update, GoodsBuffs};
			   {_EGoodsId, _EValue, _ETime} ->
				   GoodsBuffs1 = lib_goods_use:filter_buff(PlayerStatus,GoodsBuffs,[31217]),
				   NewGoodsBuffs = {update, true, GoodsBuffs1}
		   end,
	{NewPlayer,NewGoodsBuffs}.


%% 更新角色坐骑附加属性效果
update_mount_attribute_effect(PlayerStatus,Mount) ->
	%%更新人物信息
	if
		is_record(Mount,ets_mount) ->
			case Mount#ets_mount.status of
				1 ->
					MountMultAttribute= data_mount:get_prop_mount(Mount),
					PlayerStatus2 = PlayerStatus#player{other = PlayerStatus#player.other#player_other{mount_mult_attribute = MountMultAttribute}},
					PlayerStatus3 = lib_player:count_player_attribute(PlayerStatus2);					
				_ ->
					MountMultAttribute= [0,0,0,0,0,0,0,0,0,0,0,0],
					PlayerStatus2 = PlayerStatus#player{other = PlayerStatus#player.other#player_other{mount_mult_attribute = MountMultAttribute}},
					PlayerStatus3 = lib_player:count_player_attribute(PlayerStatus2)
			end,
			lib_player:send_player_attribute(PlayerStatus3,2),
			PlayerStatus3;
		true ->
			PlayerStatus
	end.

%% 取坐骑效果值
get_mount_attribute_effect(MountId) ->
	Mount = lib_mount:get_mount(MountId),
	%%更新人物信息
	if
		is_record(Mount,ets_mount) ->
			data_mount:get_prop_mount(Mount);
		true ->
			[0,0,0,0,0,0,0,0,0,0,0,0]
	end.



%%坐骑升级经验算法(消耗经验)
update_mount_level(PlayerLv,MountLevel,Exp,AddExp) ->
	CrrrentLevelExp = data_mount:get_level_need_exp(MountLevel),
	if (Exp + AddExp) =< CrrrentLevelExp ->
		   [MountLevel,(Exp+AddExp),(AddExp-AddExp)];
	   true ->
		   if PlayerLv == MountLevel ->
				  [MountLevel,CrrrentLevelExp,0];
			  true ->
				  if MountLevel >= 99 ->
						 [99,CrrrentLevelExp,0];
					 true ->
						 update_mount_level(PlayerLv,MountLevel+1,0,AddExp-(CrrrentLevelExp-Exp))
				  end
		   end
	end.

%%坐骑技能升级经验算法(不消耗经验)
update_mount_skill_level(Level,Step,Exp) ->
	NextLevelExp = data_mount:get_skill_upgrade_exp(Level+1,Step),
	if Exp < NextLevelExp ->
		   [Level,Exp,Step];
	   true ->
		   if Level+1 >= 10 ->
				 [10,NextLevelExp,Step];  
			  true ->
				  update_mount_skill_level(Level+1,Step,Exp)
		   end
	end.

%%判断此种技能加成类型是否已学
is_study_skill(MountInfo,SkillType) ->
	F = fun(Num) ->
				[_Pos, _SkillId1, SkillType1, _SkillLevel, _SkillStep, _SkillExp] = get_mount_skill(MountInfo,Num),
				SkillType1
		end,
	SkillTypeList = [F(Num) || Num <- lists:seq(1, 8)],
	lists:member(SkillType, SkillTypeList).

get_mount_skill(MountInfo,Pos) ->
	MountSkill = 
	if Pos == 1 -> MountInfo#ets_mount.skill_1;
	   Pos == 2 -> MountInfo#ets_mount.skill_2;
	   Pos == 3 -> MountInfo#ets_mount.skill_3;
	   Pos == 4 -> MountInfo#ets_mount.skill_4;
	   Pos == 5 -> MountInfo#ets_mount.skill_5;
	   Pos == 6 -> MountInfo#ets_mount.skill_6;
	   Pos == 7 -> MountInfo#ets_mount.skill_7;
	   true ->       MountInfo#ets_mount.skill_8
	end,
	[_Pos, _SkillId, _SkillType, _SkillLevel, _SkillStep, _SkillExp] = util:string_to_term(tool:to_list(MountSkill)).

get_mount_skill_num(MountInfo) ->
	F = fun(Num) ->
				[_Pos, SkillId, _SkillType, _SkillLevel, _SkillStep, _SkillExp] = get_mount_skill(MountInfo,Num),
				if SkillId > 0 ->
					   1;
				   true ->
					   0
				end
		end,
	lists:sum([F(Num) || Num <- lists:seq(1, 8)]).
	

%%取按钮的顺序(0未激活，1激活)
get_btn_value(MountSkillExpInfo,Btn_Order) ->
	if is_record(MountSkillExpInfo,ets_mount_skill_exp) ->
		   if Btn_Order == 1 ->
				  MountSkillExpInfo#ets_mount_skill_exp.btn_1;
			  Btn_Order == 2 ->
				  MountSkillExpInfo#ets_mount_skill_exp.btn_2;
			  Btn_Order == 3 ->
				  MountSkillExpInfo#ets_mount_skill_exp.btn_3;
			  Btn_Order == 4 ->
				  MountSkillExpInfo#ets_mount_skill_exp.btn_4;
			  Btn_Order == 5 ->
				  MountSkillExpInfo#ets_mount_skill_exp.btn_5;
			  true -> 0
		   end;
	   true ->
		   0
	end.

%%取按钮的顺序(0未激活，1激活)
get_btn_type(MountSkillExpInfo,Btn_Order) ->
	if Btn_Order == 1 ->
		   0;
	   Btn_Order == 2 ->
		   0;
	   Btn_Order == 3 ->
		   0;
	   Btn_Order == 4 ->
		   MountSkillExpInfo#ets_mount_skill_exp.btn4_type;
	   Btn_Order == 5 ->
		   MountSkillExpInfo#ets_mount_skill_exp.btn5_type;
	   true -> 0
	end.


%%公用接口
lookup_one(Table, Key) ->
    Record = ets:lookup(Table, Key),
    if  Record =:= [] ->
            [];
        true ->
            [R] = Record,
            R
    end.

lookup_all(Table, Key) ->
    ets:lookup(Table, Key).

match_one(Table, Pattern) ->
    Record = ets:match_object(Table, Pattern),
    if  Record =:= [] ->
            [];
        true ->
            [R|_] = Record,
            R
    end.

match_all(Table, Pattern) ->
    ets:match_object(Table, Pattern).



%%修改坐骑
change_mount_skill() -> 
	MountList = db_agent:select_all_mount(),
	MountSkillSplitList = db_agent:select_all_mount_skill_split(),
	case MountList of
		[] -> skip;
		_ ->
			MountList1 = [list_to_tuple([ets_mount]++MountInfo) || MountInfo <- MountList],
			F = fun(Mount) ->
						F1 = fun(Pos) ->
									[_Pos, SkillId, SkillType, _SkillLevel, _SkillStep, _SkillExp] = get_mount_skill(Mount,Pos),
									if SkillId == 4003 andalso SkillType == 13 ->
										 [_Pos, 4013, SkillType, _SkillLevel, _SkillStep, _SkillExp];
									   true ->
										  [_Pos, SkillId, SkillType, _SkillLevel, _SkillStep, _SkillExp]
									end
							 end,
						MountSkillList = [F1(Pos)|| Pos<- lists:seq(1, 8)],
									
						NewSkill1 = util:term_to_string(lists:nth(1, MountSkillList)),
						NewSkill2 = util:term_to_string(lists:nth(2, MountSkillList)),
						NewSkill3 = util:term_to_string(lists:nth(3, MountSkillList)),
						NewSkill4 = util:term_to_string(lists:nth(4, MountSkillList)),
						NewSkill5 = util:term_to_string(lists:nth(5, MountSkillList)),
						NewSkill6 = util:term_to_string(lists:nth(6, MountSkillList)),
						NewSkill7 = util:term_to_string(lists:nth(7, MountSkillList)),
						NewSkill8 = util:term_to_string(lists:nth(8, MountSkillList)),
						
						KeyValueList = [{skill_1,NewSkill1},{skill_2,NewSkill2},{skill_3,NewSkill3},{skill_4,NewSkill4},
										 {skill_5,NewSkill5},{skill_6,NewSkill6},{skill_7,NewSkill7},{skill_8,NewSkill8}],
						db_agent:update_mount(KeyValueList,[{id,Mount#ets_mount.id}])
				end,
			[F(Mount) || Mount <- MountList1]
	end,
	case MountSkillSplitList of 
		[] -> 
			skip;
		_ ->
			MountSkillSplitInfoList = [list_to_tuple([ets_mount_skill_split]++MountSkillSplit) || MountSkillSplit <- MountSkillSplitList],
			F3 = fun(MountSkillSplitInfo) ->
						Id = MountSkillSplitInfo#ets_mount_skill_split.id,
						Type = MountSkillSplitInfo#ets_mount_skill_split.type,
						SplitSkillId = MountSkillSplitInfo#ets_mount_skill_split.skill_id,
						if SplitSkillId == 4003 andalso Type == 13 ->
							   update_mount_skill_split([{skill_id,4013}], [{id,Id}]);
						   true ->
							   skip
						end
				end,
			[F3(MountSkillSplitInfo) || MountSkillSplitInfo <- MountSkillSplitInfoList]
	end.



