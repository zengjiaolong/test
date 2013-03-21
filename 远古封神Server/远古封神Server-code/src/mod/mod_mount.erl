%%%------------------------------------
%%% @Module  : mod_mount
%%% @Author  : ygzj
%%% @Created : 2011.12.23
%%% @Description: 坐骑处理
%%%------------------------------------
-module(mod_mount).
-include("common.hrl").
-include("record.hrl").
-compile(export_all).

role_login(PlayerId) ->
	lib_mount:init_mount(PlayerId).

%%查看新版坐骑信息
get_mount_info(MountId) ->
	lib_mount:get_mount(MountId).

%%查看坐骑信息(在线，不在线)
get_mount_rank_info(MountId) ->
	Mount =  lib_mount:get_mount(MountId),
	if Mount =/= [] ->
		   Mount1 = Mount;
	   true ->
		   Mount2 = db_agent:select_mount_info(MountId),
		   if Mount2 == [] ->
				  Mount1 = Mount2;
			  true ->
				  Mount1 = list_to_tuple([ets_mount]++Mount2)
		   end
	end,
	Mount1.
	

%%查看新版坐骑列表
get_all_mount(PlayerId) ->
	lib_mount:get_all_mount(PlayerId).

%% 出战坐骑亲密度自动增长
auto_add_close(PlayerStatus,MountId) ->
	lib_mount:auto_add_close(PlayerStatus,MountId).

%%坐骑出战,休息 
%%Type 0为休息 1为出战 2丢弃
change_mount_status(PlayerStatus,MountId,Type) ->
	Mount = lib_mount:get_mount(MountId),
	case Type of
		0 -> rest_mount(PlayerStatus,Mount);
		1 -> out_mount(PlayerStatus,Mount);
		2 -> free_mount(PlayerStatus,Mount);
		_ -> [0,PlayerStatus]
	end.

%% -----------------------------------------------------------------
%%坐骑放生
%% -----------------------------------------------------------------
free_mount(Status,Mount) ->
	 if  Mount =:= []  -> 
			[2,Status];%%坐骑不存在
        true ->         
            if  
                Mount#ets_mount.player_id =/= Status#player.id -> 
					[3,Status];%%该灵兽不归你所有
                Mount#ets_mount.status =:= 1 -> 
					[6,Status];%%出战坐骑不能丢弃
                true ->         
                     lib_mount:free_mount(Status,Mount)
            end
    end.

%% -----------------------------------------------------------------
%% 坐骑休息 状态0
%% -----------------------------------------------------------------
rest_mount(Status,Mount) ->
    if  Mount =:= []  -> 
			[2,Status];%%坐骑不存在
        true ->         
            if  
                Mount#ets_mount.player_id =/= Status#player.id -> 
					[3,Status];%% 该灵兽不归你所有
                true ->         
					if Mount#ets_mount.status =:= 0 ->
						   lib_mount:out_mount(Status, Mount);
					   true ->
						   lib_mount:rest_mount(Status,Mount)
					end
            end
    end.

%% -----------------------------------------------------------------
%% 坐骑出战 状态1
%% -----------------------------------------------------------------
out_mount(Status, Mount) ->
	if  Mount =:= []  ->
			[2,Status];
        true ->           
             if  
                Mount#ets_mount.player_id =/= Status#player.id -> 
					[3,Status];%% 该灵兽不归你所有
                true -> 
					if Mount#ets_mount.status =:= 1 -> 
						   lib_mount:rest_mount(Status,Mount);
					   true ->
						   %%先判断有没有在乘骑上，有则先卸下
						   MountInfo = lib_mount:get_mount(Status#player.mount),
						   NewStatus = lib_mount:get_off_mount(Status,MountInfo), 
						   lib_mount:out_mount(NewStatus,Mount)
					end
            end
    end.	

%% -----------------------------------------------------------------
%% 坐骑喂养
%% -----------------------------------------------------------------
feed_mount(Status,MountId, Food_type, GoodsNum) ->
	Mount = lib_mount:get_mount(MountId),
	case check_feed_mount(Status,Mount,Food_type,GoodsNum) of
		1 ->
			lib_mount:feed_mount(Status,Mount,Food_type,GoodsNum);
		Res ->
			[Res,Status]
	end.

%% 坐骑改名
rename_mount(PlayerStatus, MountId, NewName) ->
	lib_mount:rename_mount(PlayerStatus, MountId, NewName).
	
check_feed_mount(Status,Mount,Food_type,GoodsNum) ->
	Food_num = get_goods_info(Status,Food_type),
	[NewLevel,_NewExp,_RestExp] = lib_mount:update_mount_level(Mount#ets_mount.level,Mount#ets_mount.exp,GoodsNum*10),
	if
		Mount == [] ->
			2;%%灵兽不存在
		Mount#ets_mount.level > Status#player.lv ->
			3;%%不能超过角色等级
		NewLevel > Status#player.lv ->
			3;%%不能超过角色等级
		Food_num =:= 0 ->
			4;%%物品不存在
		Mount#ets_mount.player_id =/= Status#player.id ->
			5;%%灵兽不归你所有
		Food_type =/= 24000 ->
			6;%%物品类型不正确
		Food_num < GoodsNum ->
			7;%%数量不足 
		true ->
			1
	end.	

%% ----------------------------------------------------------------
%%坐骑状态切换
%% ----------------------------------------------------------------
change_new_mount_status(Status,MountId) ->
	case check_new_change_mount_status(Status,MountId) of
		{fail,NewStatus,Res} ->
			[Res,0,NewStatus];
		{ok,NewStatus,MountInfo} ->
			case (catch lib_mount:change_new_mount_status(Status,MountInfo)) of
				{ok,NewPlayerStatus1,MountType} ->
					%% 是否在打坐状态
					{ok, SitPlayer} = 
						if
							NewPlayerStatus1#player.status =/= 6 ->
								{ok, NewPlayerStatus1};
							true ->
								lib_player:cancelSitStatus(NewPlayerStatus1)
						end,
					%%更新角色坐骑属性加成
					Mount = lib_mount:get_mount(MountId),
					NewPlayerStatus2 = lib_mount:update_mount_attribute_effect(SitPlayer, Mount),
					[1,MountType,NewPlayerStatus2];
				Error ->
					?ERROR_MSG("mod_mount change_new_mount_status Err:~p",[Error]),
					[0,0,NewStatus]
			end
	end.
	

check_new_change_mount_status(Status,MountId) ->
%% MountSkillExpInfo = lib_mount:mount_5_btn(Status#player.id),
%% MountTypeIdList = util:string_to_term(tool:to_list(MountSkillExpInfo#ets_mount_skill_exp.active_type)),
	MountInfo = lib_mount:get_mount(MountId),
	if
		is_record(MountInfo,ets_mount) =:= false ->
			{fail,Status,2};
		Status#player.id =/= MountInfo#goods.player_id ->
			{fail,Status,3};
		%%除了正常状态都不能上坐骑
		Status#player.status =/= 0 andalso Status#player.status =/= 6 ->
			{fail,Status,4};
		%%押镖不能上坐骑
		Status#player.carry_mark>0->
			{fail,Status,5};
%% 		IsCanUse == false ->
%% 			{fail,Status,18};
		MountInfo#ets_mount.status =/= 1 ->
			{fail,Status,19};
		true ->
			{ok,Status,MountInfo}
	end.

%% 坐骑进阶界面信息
get_next_step_info(Status,MountId) ->
	MountInfo = lib_mount:get_mount(MountId),
	if
		is_record(MountInfo,ets_mount) =:= false ->
			[0,MountId,0,<<>>,0,0,0,0];%%坐骑不存在
		Status#player.id =/= MountInfo#goods.player_id ->
			[2,MountId,0,<<>>,0,0,0,0];%%坐骑不属于你
		true ->
			lib_mount:get_next_step_info(Status,MountInfo)
	end.

%% 坐骑进阶操作
oper_step(Status,MountId,MountGoodsTypeId,Auto_purch) ->
	MountInfo = lib_mount:get_mount(MountId),
	if
		is_record(MountInfo,ets_mount) == true ->
			NeedLv = data_mount:get_need_level(MountInfo#ets_mount.step+1),
			[Goods_id,Num,Cost] = data_mount:get_need_cond_step(MountInfo#ets_mount.step+1),
			GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, Goods_id),
			StoneList = goods_util:get_type_goods_list(Status#player.id,Goods_id,4),
			TotalNum  = goods_util:get_goods_totalnum(StoneList),
			if 
				Status#player.id =/= MountInfo#ets_mount.player_id ->
					[2,Status];%%坐骑不属于你
				Auto_purch == 0 andalso TotalNum < Num ->
					[4,Status];
				Status#player.coin + Status#player.bcoin < Cost ->
					[5,Status]; %%铜币不足
				MountInfo#ets_mount.level < NeedLv ->
				    [7,Status];%%坐骑等级不够
				MountInfo#ets_mount.step >= 10 ->
					[8,Status];%%坐骑已经是最高阶数
				Auto_purch == 1 andalso TotalNum < Num andalso Status#player.gold < GoodsTypeInfo#ets_base_goods.price*(Num-TotalNum) ->
					[9,Status];%%自动购买元宝不够
			   true ->
				   lib_mount:oper_step(Status,MountInfo,Cost,MountGoodsTypeId,Goods_id,Num,TotalNum,GoodsTypeInfo#ets_base_goods.price*(Num-TotalNum))
			end;
		true ->
			[3,Status]%%坐骑不存在
	end.
	
%% 坐骑兽魄驯化界面信息
get_4sp_info(Status,MountId) ->
	MountInfo = lib_mount:get_mount(MountId),
	if
		is_record(MountInfo,ets_mount) =:= false ->
			[0,0,0,0];%%坐骑不存在
		Status#player.id =/= MountInfo#goods.player_id ->
			[2,0,0,0];%%坐骑不属于你
		true ->
			lib_mount:get_4sp_info(Status,MountInfo)
	end.
	
%%坐骑兽魄驯化操作
oper_4sp(Status,MountId,Auto_purch) ->
	MountInfo = lib_mount:get_mount(MountId),
	if
		is_record(MountInfo,ets_mount) == true ->
			[Goods_id,Num,Cost] = data_mount:get_need_cond_4sp(MountInfo#ets_mount.step),
			GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, Goods_id),
			StoneList = goods_util:get_type_goods_list(Status#player.id,Goods_id,4),
			TotalNum  = goods_util:get_goods_totalnum(StoneList),
			if 
				Status#player.id =/= MountInfo#ets_mount.player_id ->
					[2,Status];%%坐骑不属于你
				Auto_purch == 0 andalso TotalNum < Num ->
					[4,Status];
				Status#player.coin + Status#player.bcoin < Cost ->
					[5,Status]; %%铜币不足
				Auto_purch == 1 andalso TotalNum < Num andalso Status#player.gold < GoodsTypeInfo#ets_base_goods.price*(Num-TotalNum) ->
					[8,Status];%%自动购买元宝不够
			   true ->
				   lib_mount:oper_4sp(Status,MountInfo,Cost,Goods_id,Num,TotalNum,GoodsTypeInfo#ets_base_goods.price*(Num-TotalNum))
			end;
		true ->
			[3,Status]%%坐骑不存在
	end.


%%坐骑猎魂技能列表
mount_skill_split_list(PlayerId) ->
	lib_mount:mount_skill_split_list(PlayerId).

%%坐骑五个按钮信息
mount_5_btn(PlayerId) ->
	lib_mount:mount_5_btn(PlayerId).

%%设置自动萃取颜色
auto_step_set(PlayerId,Auto_Color) ->
	lib_mount:auto_step_set(PlayerId,Auto_Color).

%%点击按钮产生技能按钮顺序从1-5
general_skill(Status,Btn_Order) ->
	MountSkillExpInfo = lib_mount:mount_5_btn(Status#player.id),
	Need_Cash = data_mount:get_need_cond_cash_btn(Btn_Order),
	Active_value = lib_mount:get_btn_value(MountSkillExpInfo,Btn_Order),
	MountSkillSplitCount = length(lib_mount:get_all_mount_skill_split(Status#player.id)),
	MaxMountSkillSplit = lib_mount:get_max_mount_skill_split(),
	if 
		MountSkillExpInfo == [] ->
			[2,0,0,0,Status];%%坐骑信息错误
		Status#player.cash < Need_Cash ->
			[3,0,0,0,Status];%%礼券不够
		Active_value == 0 orelse Btn_Order > 5 orelse Btn_Order < 1->
			[4,0,0,0,Status];%%该按钮未激活
		MountSkillSplitCount >= MaxMountSkillSplit ->
			[5,0,0,0,Status];%%猎魂空间已满，请先将处理现有精魂
		true ->
			lib_mount:general_skill(Status,MountSkillExpInfo,Btn_Order,Need_Cash)
	end.

%%一键猎魂
auto_general_skill(Status) ->
	MaxMountSkillSplit = lib_mount:get_max_mount_skill_split(),
	loop_auto_general_skill(Status,MaxMountSkillSplit,0).

loop_auto_general_skill(Status,MaxMountSkillSplit,_Num) ->
	MountSkillExpInfo = lib_mount:mount_5_btn(Status#player.id),
	MountSkillSplitCount = length(lib_mount:get_all_mount_skill_split(Status#player.id)),
	if 
		is_record(MountSkillExpInfo,ets_mount_skill_exp) == false ->
			[4,0,0,0,Status];%%坐骑信息错误
		true ->
			Btn_List1 = [{5,MountSkillExpInfo#ets_mount_skill_exp.btn_5},{4,MountSkillExpInfo#ets_mount_skill_exp.btn_4},{3,MountSkillExpInfo#ets_mount_skill_exp.btn_3},
						 		  {2,MountSkillExpInfo#ets_mount_skill_exp.btn_2},{1,MountSkillExpInfo#ets_mount_skill_exp.btn_1}],
			Btn_List2 = [_Btn_Order || {_Btn_Order,Value} <- Btn_List1,Value == 1],
			Btn_Order = lists:nth(1, Btn_List2),
			Need_Cash = data_mount:get_need_cond_cash_btn(Btn_Order),
			MaxMountSkillSplit = lib_mount:get_max_mount_skill_split(),
			if Status#player.cash < Need_Cash ->
				   [3,0,0,0,Status];%%礼券不够
		       MountSkillSplitCount >= MaxMountSkillSplit ->
				   [5,0,0,0,Status];%%猎魂空间已满，请先将处理现有精魂
			true ->
				[1,_SkillId,_Color,_Pos,NewPlayer] = lib_mount:general_skill(Status,MountSkillExpInfo,Btn_Order,Need_Cash),
				loop_auto_general_skill(NewPlayer,MaxMountSkillSplit,1)
			end
	end.
	
%%技能拖动类型(UpDown 1为从上面拉到下面,2从下面拉到上面,3为闲置技能左右拖动坐骑技能不能左右拖动,Type1为技能合并预览，2为正式技能合并
mount_drag_skill(Status,MountId,UpDown,Type,Id1,Id2) ->
	case check_drag_skill(Status,MountId,UpDown,Id1,Id2) of
		{fail,Res,NewStatus} ->
			[Res,<<>>,NewStatus];
		{ok,MountInfo} ->
			lib_mount:mount_drag_skill(Status,MountInfo,UpDown,Type,Id1,Id2)
	end.

%%检查拖动条件
check_drag_skill(Status,MountId,UpDown,Id1,Id2) ->
	MountInfo = lib_mount:get_mount(MountId),
	MountSkillSplitInfo1 = lib_mount:get_mount_skill_split(Id1),
	MountSkillSplitInfo2 = lib_mount:get_mount_skill_split(Id2),
	MountSkillSplitCount = length(lib_mount:get_all_mount_skill_split(Status#player.id)),
	MaxMountSkillSplit = lib_mount:get_max_mount_skill_split(),
	if
		(UpDown == 1 orelse UpDown == 2) andalso MountInfo == [] -> %%没有指定坐骑
			{fail,2,Status};
		(UpDown == 1 orelse UpDown == 2) andalso MountInfo#ets_mount.player_id  =/= Status#player.id -> %%坐骑不属于你
			{fail,3,Status};
		UpDown == 1  andalso (Id2 > 8 orelse Id2 < 1) -> %%没有指定坐骑技能
			{fail,4,Status};
		UpDown == 1  andalso is_record(MountSkillSplitInfo1,ets_mount_skill_split) == false  -> %%闲置技能不存在
			{fail,4,Status};
		UpDown == 2  andalso (Id1 > 8 orelse Id1 < 1) -> %%没有指定坐骑技能
			{fail,4,Status};
		UpDown == 3  andalso (MountSkillSplitInfo1 == [] orelse MountSkillSplitInfo2 == [] ) -> %%没有指定坐骑技能
			{fail,7,Status};
		(UpDown == 1 orelse UpDown == 2) andalso MountInfo#ets_mount.status =/= 1 ->
			{fail,12,Status};
		UpDown == 2  andalso (MountSkillSplitCount >= MaxMountSkillSplit) -> %%超出最大闲置技能存放空间
			{fail,13,Status};
		true ->
			{ok,MountInfo}
	end.

%%%%用元宝激活按钮4
active_btn4(Status) ->
	MountSkillExpInfo = lib_mount:mount_5_btn(Status#player.id),
	Active_value = lib_mount:get_btn_value(MountSkillExpInfo,4),
	Cost = 200,
	if 
		MountSkillExpInfo == [] ->
			[2,Status];%%坐骑信息错误
		Status#player.gold < Cost ->
			[3,Status];%%元宝不够
		Active_value == 1 ->
			[4,Status];%%该按钮已激活
		true ->
			lib_mount:active_btn4(Status,MountSkillExpInfo,Cost)
	end.
	
%%萃取
skill_fetch(Status,MountSkillSplitId) ->
	MountSkillSplitInfo = lib_mount:get_mount_skill_split(MountSkillSplitId),
	if MountSkillSplitInfo == [] ->
		   0; %%闲置技能不存在
	   MountSkillSplitInfo#ets_mount_skill_split.player_id =/= Status#player.id ->
		   2;%%闲置技能不属于你
	   true ->
		   lib_mount:skill_fetch(Status,MountSkillSplitInfo) 
	end.

%%一键萃取
one_key_skill_fetch(Status) ->
	MountSkillSplitList = lib_mount:get_all_mount_skill_split(Status#player.id),
	if MountSkillSplitList == [] ->
		   0; %%闲置技能不存在
	   true ->
		   lib_mount:one_key_skill_fetch(Status,MountSkillSplitList) 
	end.

%%卖出
skill_sell(Status,MountSkillSplitId) ->
	MountSkillSplitInfo = lib_mount:get_mount_skill_split(MountSkillSplitId),
	if MountSkillSplitInfo == [] ->
		   [0,Status]; %%闲置技能不存在
	   MountSkillSplitInfo#ets_mount_skill_split.player_id =/= Status#player.id ->
		   [2,Status];%%闲置技能不属于你
	   true ->
		   lib_mount:skill_sell(Status,MountSkillSplitInfo) 
	end.

%%一键卖出
one_key_skill_sell(Status) ->
	MountSkillSplitList = lib_mount:get_all_mount_skill_split(Status#player.id),
	if MountSkillSplitList == [] ->
		   [0,Status]; %%闲置技能不存在
	   true ->
		   lib_mount:one_key_skill_sell(Status,MountSkillSplitList) 
	end.

%%一键吞噬
one_key_skill_eat(PlayerId) ->
	MountSkillSplitList = lib_mount:get_all_mount_skill_split(PlayerId),
	if MountSkillSplitList == [] ->
		   0; %%闲置技能不存在
	   true ->
		   lib_mount:one_key_skill_eat(PlayerId,MountSkillSplitList) 
	end.

%%添加技能经验 坐骑技能位置(1-8)
add_skill_exp(Status,MountId,Pos) ->
	MountInfo = lib_mount:get_mount(MountId),
	if Pos < 1 orelse Pos > 8 ->
		   [1,<<>>,Status]; %%坐骑技能不存在
	   MountInfo == [] ->
		   [2,<<>>,Status];%%坐骑不存在
	   true ->
		  lib_mount:add_skill_exp(Status,MountInfo,Pos)
	end.
	

%%坐骑图鉴列表
get_all_type(PlayerId) ->
	lib_mount:get_all_type(PlayerId). 


%%坐骑图鉴切换
change_active_type(Status,MountId,GoodsTypeId) ->
	MountSkillExpInfo = lib_mount:mount_5_btn(Status#player.id),
	MountTypeIdList = util:string_to_term(tool:to_list(MountSkillExpInfo#ets_mount_skill_exp.active_type)),
	IsCanUse = lists:member(GoodsTypeId, MountTypeIdList),
	MountInfo = lib_mount:get_mount(MountId),
	if MountInfo == [] ->
		   [2,GoodsTypeId,Status]; %%坐骑不存在
	   MountInfo#ets_mount.status =/= 1 ->
		   [3,GoodsTypeId,Status];%%出战状态才能切换外形
	   MountInfo#ets_mount.player_id =/= Status#player.id ->
		   [4,GoodsTypeId,Status];%%坐骑不属于你
	   IsCanUse == false ->
 		   [6,GoodsTypeId,Status];
	   true ->
		   %%坐骑变形任务
		   lib_task:event(mount_change,null,Status),
		   lib_mount:change_active_type(Status,MountInfo,GoodsTypeId)
	end.


%% 坐骑闲置技能查看
get_mount_skill_split_info(MountSkillSplitId)  ->
	MountSkillSplitInfo = lib_mount:get_mount_skill_split(MountSkillSplitId),
	if is_record(MountSkillSplitInfo,ets_mount_skill_split) ->
		   MountSkillSplitInfo;
	   true ->
		   MountSkillSplitInfo2 = db_agent:select_mount_skill_split(MountSkillSplitId),
		   if MountSkillSplitInfo2 == [] ->
				  [];
			  true ->
				  MountSkillSplitInfo1 = list_to_tuple([ets_mount_skill_split]++MountSkillSplitInfo2),
				  MountSkillSplitInfo1
		   end
	end.

%% ----------------------------------------------------------------
%% 获取坐骑道具信息
%% ----------------------------------------------------------------
get_goods_info(Status,Goods_id) ->
	Total = goods_util:get_goods_num(Status#player.id, Goods_id, 4),
	Total.



