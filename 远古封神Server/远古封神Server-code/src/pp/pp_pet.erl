%%%--------------------------------------
%%% @Module  : pp_pet
%%% @Author  : ygzj
%%% @Created : 2010.09.23
%%% @Description: 灵兽
%%%--------------------------------------
-module(pp_pet).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%=========================================================================
%% 接口函数 
%%=========================================================================

%% -----------------------------------------------------------------
%% 灵兽生成
%% -----------------------------------------------------------------
handle(41001, Status, [Goods_Id,Rune_Id]) ->
    [Result, PetId, GoodsTyoeId,PetName, NewStatus] = mod_pet:give_pet(Status, [Goods_Id,Rune_Id]),
	case Result of
		1 ->%%召唤成功了,灵兽判断
			lib_achieve_outline:pet_ach_check(Status#player.id, Status#player.other#player_other.pid);
		_ ->
			skip
	end,
    {ok, BinData} = pt_41:write(41001, [Result, NewStatus#player.coin, NewStatus#player.bcoin, PetId, GoodsTyoeId, PetName]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
    ok;

%% -----------------------------------------------------------------
%% 灵兽放生
%% -----------------------------------------------------------------
handle(41002, Status, [PetId]) ->
	Out_pet = lib_pet:get_out_pet(Status#player.id),
    {Result, Pet} = mod_pet:free_pet(Status, [PetId,0]),
    {ok, BinData} = pt_41:write(41002, [Result, PetId]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	pp_pet:handle(41008, Status, [Status#player.id]), %% add by zkj
	if
		Out_pet =:= [] ->
			skip;
		%%成功且是出战的，则广播删除
		Result =:= 1 andalso Out_pet#ets_pet.id =:= PetId ->	
			DelPetColor = data_pet:get_pet_color(Pet#ets_pet.aptitude),
			{ok,DelBinData} = pt_12:write(12031,[0,Status#player.id,Pet#ets_pet.id ,Pet#ets_pet.name,DelPetColor,Pet#ets_pet.goods_id,Pet#ets_pet.grow,Pet#ets_pet.aptitude]),
			mod_scene_agent:send_to_area_scene(Status#player.scene,Status#player.x, Status#player.y, DelBinData),
			Pet_batt_skill = lib_pet:get_out_pet_batt_skill(Status#player.id),
   			NewStatus = Status#player{other=Status#player.other#player_other{
								out_pet = lib_pet:get_out_pet(Status#player.id),pet_batt_skill=Pet_batt_skill}},
			{ok, NewStatus};
		true ->
			ok
	end;


%% -----------------------------------------------------------------
%% 灵兽改名
%% -----------------------------------------------------------------
handle(41003, Status, [PetId, PetName]) ->
    case (catch mod_pet:rename_pet(Status, [PetId, PetName])) of
		{ok} ->
			{ok, BinData} = pt_41:write(41003,[1,PetId,PetName]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			Out_pet = lib_pet:get_out_pet(Status#player.id),
			if
				Out_pet =:= [] ->
					ok;
				Out_pet#ets_pet.id =:= PetId ->	
					%% 是出战的，需要同步修改Status
					New_out_pet = lib_pet:get_out_pet(Status#player.id),
					PetColor = data_pet:get_pet_color(New_out_pet#ets_pet.aptitude),
					{ok,BinData1} = pt_12:write(12031,[New_out_pet#ets_pet.status, Status#player.id,New_out_pet#ets_pet.id ,New_out_pet#ets_pet.name, PetColor,New_out_pet#ets_pet.goods_id,New_out_pet#ets_pet.grow,New_out_pet#ets_pet.aptitude]),
					mod_scene_agent:send_to_area_scene(Status#player.scene,Status#player.x, Status#player.y, BinData1),		
					NewStatus = Status#player{other=Status#player.other#player_other{
								out_pet = New_out_pet }},
					{ok, NewStatus};
				true ->
					ok
			end;
		{fail,Res} ->
			{ok, BinData} = pt_41:write(41003,[Res,PetId,PetName]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok;
		_Error ->
			{ok, BinData} = pt_41:write(41003,[0,0,[]]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;

%% -----------------------------------------------------------------
%% 灵兽状态切换
%% -----------------------------------------------------------------
handle(41004, Status, [PetId,PetStatus]) ->
	case lib_spring:is_spring_scene(Status#player.scene) andalso PetStatus =:= 1 of
		true ->
			{ok,BinData} = pt_41:write(41004,[8,PetId,0]);
		false ->
	%%状态切换前如果有出战的灵兽先收回。
	if
		PetStatus =:= 1 ->
			%%收回并广播
			case (catch mod_pet:before_change_status(Status)) of
				{ok,OldPet} ->
					{ok,OldBinData} = pt_41:write(41004,[1,OldPet#ets_pet.id,OldPet#ets_pet.status]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send,OldBinData),
					OldPetColor = data_pet:get_pet_color(OldPet#ets_pet.aptitude),
					{ok,OldBinData1} = pt_12:write(12031,[OldPet#ets_pet.status,Status#player.id,OldPet#ets_pet.id ,OldPet#ets_pet.name,OldPetColor,OldPet#ets_pet.goods_id,OldPet#ets_pet.grow,OldPet#ets_pet.aptitude]),
					mod_scene_agent:send_to_area_scene(Status#player.scene,Status#player.x, Status#player.y, OldBinData1);			
				_Err ->
					skip		
			end;
		true ->
			skip
	end,
	case (catch mod_pet:change_status(Status,[PetId,PetStatus])) of
		{ok,Pet} ->
			%%返回
			{ok,BinData} = pt_41:write(41004,[1,PetId,Pet#ets_pet.status]),
			%%广播
			PetColor = data_pet:get_pet_color(Pet#ets_pet.aptitude),
			{ok,BinData1} = pt_12:write(12031,[Pet#ets_pet.status,Status#player.id,PetId,Pet#ets_pet.name,PetColor,Pet#ets_pet.goods_id,Pet#ets_pet.grow,Pet#ets_pet.aptitude]),
			mod_scene_agent:send_to_area_scene(Status#player.scene,Status#player.x, Status#player.y, BinData1);
		{fail,Res} ->
			{ok,BinData} = pt_41:write(41004,[Res,PetId,0]);
		_Error ->
			{ok,BinData} = pt_41:write(41004,[0,0,0])
	end
	end,
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	Pet_batt_skill = lib_pet:get_out_pet_batt_skill(Status#player.id),
   	NewStatus = Status#player{other=Status#player.other#player_other{
				out_pet = lib_pet:get_out_pet(Status#player.id),pet_batt_skill = Pet_batt_skill}},	
	gen_server:cast(NewStatus#player.other#player_other.pid, {'SET_PLAYER', [{out_pet,NewStatus#player.other#player_other.out_pet},{pet_batt_skill,Pet_batt_skill}]}),
	{ok, NewStatus};					  
									  
%% -----------------------------------------------------------------
%% 灵兽资质提升
%% -----------------------------------------------------------------
handle(41005,Status,[PetId,AptType,PType,Auto_purch]) ->
	case (catch mod_pet:upgrade_aptitude(Status,[PetId,AptType,PType,Auto_purch])) of
		{ok,NewStatus,Pet,Res,Rest_Apt,Rest_P,RP,Coin} ->
			{ok, BinData} = pt_41:write(41005,[Res,Pet#ets_pet.id,Pet#ets_pet.aptitude,Rest_Apt,Rest_P,RP,Coin]);
		{fail,Res} ->
			NewStatus = Status,
			{ok, BinData} = pt_41:write(41005,[Res,0,0,0,0,0,0]);
		_Error ->
			NewStatus = Status,
			{ok, BinData} = pt_41:write(41005,[0,0,0,0,0,0,0])
	end,
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	{ok, NewStatus};
		  
%% -----------------------------------------------------------------
%% 灵兽喂养
%% -----------------------------------------------------------------
handle(41006, Status, [PetId, Food_type, GoodsUseNum]) ->
	Pet = lib_pet:get_pet(PetId),
   case (catch mod_pet:feed_pet(Status, [Pet, Food_type, GoodsUseNum])) of
	   {ok,PetNew,RestNum} ->
		   mod_pet:pet_attribute_effect(Status,PetNew),
		   {ok,BinData} = pt_41:write(41006,[1,PetId,PetNew#ets_pet.happy,RestNum]);
	   {fail,Res} ->
		   {ok,BinData} = pt_41:write(41006,[Res,PetId,0,0]);
	   _Error ->
		   {ok,BinData} = pt_41:write(41006,[0,0,0,0])
   end, 
   lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
   ok;
    
%% -----------------------------------------------------------------
%% 获取灵兽信息
%% -----------------------------------------------------------------
handle(41007, Status, [PetId]) ->
    Pet = mod_pet:get_pet_info(Status, [PetId]),
    {ok, BinData} = pt_41:write(41007, [Status,Pet]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
    ok;

%% -----------------------------------------------------------------
%% 获取灵兽列表
%% -----------------------------------------------------------------
handle(41008, Status, [PlayerId]) ->
    [Res,PetRecordList] = mod_pet:get_pet_list(Status, [PlayerId]),
    {ok, BinData} = pt_41:write(41008, [Res,Status,PetRecordList]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
    ok;

%% ------------------------------------------------------------------
%% 灵兽属性加点
%% ------------------------------------------------------------------
handle(41009,Status,[PetId,Forza,Agile,Wit,Physique]) ->
	case (catch mod_pet:mod_pet_attribute(Status,[PetId,Forza,Agile,Wit,Physique])) of
		{ok,Pet,[Pet_hp,Pet_att,Pet_hit,Pet_mp]} ->
			{ok,BinData} = pt_41:write(41009,[1,PetId,Pet#ets_pet.forza,Pet#ets_pet.agile,Pet#ets_pet.wit,Pet#ets_pet.physique,Pet#ets_pet.point,Pet_hp,Pet_att,Pet_hit,Pet_mp]);
		{fail,Res} ->
			{ok,BinData} = pt_41:write(41009,[Res,PetId,0,0,0,0,0,0,0,0,0]);
		_Error ->
			{ok,BinData} = pt_41:write(41009,[0,0,0,0,0,0,0,0,0,0,0])
	end,
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	ok;  

%% ------------------------------------------------------------------
%% 获取灵兽的快乐值和经验值
%% ------------------------------------------------------------------
handle(41010,Status,[PetId]) ->
	case mod_pet:timer_trigger(Status,PetId) of
		%%有快乐值
		{ok,Happy,Exp,Level,MaxExp,Name,Goods_id,Pet} ->
			{ok,BinData} = pt_41:write(41010,[1,PetId,Happy,Exp,Level,MaxExp,Name,Goods_id,Pet]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData);
		%%快乐值为0并收回
%% 		{fail,RestPet} ->
%% 			RestBinData = pt_41:write(41004,[1,RestPet#ets_pet.id,RestPet#ets_pet.status]),
%% 			lib_send:send_to_sid(Status#player.other#player_other.pid_send,RestBinData),
%% 			RestPetColor = data_pet:get_pet_color(RestPet#ets_pet.aptitude),
%% 			{ok,RestBinData1} = pt_12:write(12031,[RestPet#ets_pet.status,Status#player.id,RestPet#ets_pet.id ,RestPet#ets_pet.name,RestPetColor,RestPet#ets_pet.goods_id,RestPet#ets_pet.grow,RestPet#ets_pet.aptitude]),
%% 			mod_scene_agent:send_to_area_scene(Status#player.scene,Status#player.x, Status#player.y, RestBinData1),
%% 			OutPet = lib_pet:get_out_pet(Status#player.id),
%%    			NewStatus = Status#player{
%% 				other=Status#player.other#player_other{
%% 					out_pet = OutPet
%% 				}
%% 			},
%% 			mod_player:save_online_info_fields(NewStatus, [{out_pet, OutPet}]);
		%%出错
		{fail} ->
			{ok,BinData} = pt_41:write(41010,[0,0,0,0,0,0,<<>>,0,[]]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData);
		skip->
			skip
	end;

%% -----------------------------------------------------------------
%% 通过灵兽秘笈选定灵兽升级
%% -----------------------------------------------------------------
handle(41011,Status,[PetId,Goods_id]) ->
	Pet = lib_pet:get_pet(Status#player.id,PetId),
	case mod_pet:upgrade_by_using(Status,[Pet,Goods_id]) of
		{ok,_NewStatus,PetNew} ->
			MaxExp = data_pet:get_upgrade_exp(PetNew#ets_pet.level),
			{ok,BinData} = pt_41:write(41011,[1,PetId,PetNew#ets_pet.level,PetNew#ets_pet.happy,PetNew#ets_pet.exp,MaxExp,PetNew#ets_pet.point]);
		{fail,Res} ->
			{ok,BinData} = pt_41:write(41011,[Res,PetId,0,0,0,0,0])
	end,
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	ok;

%% -----------------------------------------------------------------
%% 灵兽道具数量查询
%% -----------------------------------------------------------------
handle(41012,Status,[Goods_id]) ->
	case mod_pet:get_goods_info(Status,Goods_id) of
		{ok,Num} ->
			{ok,BinData} = pt_41:write(41012,[1,Goods_id,Num]);
		{fail} ->
			{ok,BinData} = pt_41:write(41012,[0,0,0])
	end,
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	ok;

%% ------------------------------------------------------------------
%% 灵兽洗点
%% ------------------------------------------------------------------
handle(41013,Status,[PetId]) ->
	case (catch mod_pet:mod_clear_attribute(Status,[PetId])) of
		{ok,Pet} ->
			{ok,BinData} = pt_41:write(41013,[1,PetId,Pet#ets_pet.point]);
		{fail,Res} ->
			{ok,BinData} = pt_41:write(41013,[Res,PetId,0]);
		_Error ->
			{ok,BinData} = pt_41:write(41013,[0,0,0])
	end,
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	ok;

%% -----------------------------------------------------------------
%% 灵兽技能遗忘
%% -----------------------------------------------------------------
handle(41014,PlayerStatus,[PetId,Position])->
	case  mod_pet:mod_forget_skill(PlayerStatus,[PetId,Position]) of
		{ok,NewPlayerStatus}->{ok,NewPlayerStatus};
		{error,ErrorCode}->
			{ok,BinData} = pt_41:write(41014,[ErrorCode]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData)
	end;

%% -----------------------------------------------------------------
%% 灵兽成长值提升
%% -----------------------------------------------------------------
handle(41015,Status,[PetId,GrowType,PType,Lucky,Auto_purch]) ->
	case (catch mod_pet:upgrade_grow(Status,[PetId,GrowType,PType,Lucky,Auto_purch])) of
		{ok,NewStatus,Pet,Res,Rest_Grow,Rest_P,_RP} ->
			{ok, BinData} = pt_41:write(41015,[Res,Pet#ets_pet.id,Pet#ets_pet.grow,Rest_Grow,Rest_P,Pet#ets_pet.point]);
		{fail,Res} ->
			NewStatus = Status,
			{ok, BinData} = pt_41:write(41015,[Res,0,0,0,0,0]);
		_Error ->
			NewStatus = Status,
			{ok, BinData} = pt_41:write(41015,[0,0,0,0,0,0])
	end,
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	{ok, NewStatus};

%% -----------------------------------------------------------------
%% 开始灵兽训练
%% -----------------------------------------------------------------
handle(41016,Status,[PetId,GoodsNum,MoneyType,Auto])->
	case (catch mod_pet:pet_train_start(Status,[PetId,GoodsNum,MoneyType,Auto]) )of
		{ok,NewStatus,Pet}->
			{ok, BinData} = pt_41:write(41016,[1,Pet#ets_pet.id,Pet#ets_pet.status]);
		{fail,Error}->
			NewStatus = Status,
			{ok, BinData} = pt_41:write(41016,[Error,0,0]);
		_Error->
			NewStatus = Status,
			{ok, BinData} = pt_41:write(41016,[0,0,0])
	end,
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	Pet_batt_skill = lib_pet:get_out_pet_batt_skill(NewStatus#player.id),
	NewStatus1 = NewStatus#player{other = NewStatus#player.other#player_other{pet_batt_skill = Pet_batt_skill}},
	{ok, NewStatus1};

%% -----------------------------------------------------------------
%% 停止灵兽训练
%% -----------------------------------------------------------------
handle(41017,Status,[PetId])->
	case (catch mod_pet:pet_train_stop(Status,[PetId]) )of
		{ok,NewStatus,Pet,GoodsId,Num,MoneyType,Money}->
			lib_player:send_player_attribute2(NewStatus, 1),
			{ok, BinData} = pt_41:write(41017,[1,Pet#ets_pet.id,Pet#ets_pet.status,GoodsId,Num,MoneyType,Money]);
		{fail,Error}->
			NewStatus = Status,
			{ok, BinData} = pt_41:write(41017,[Error,0,0,0,0,0,0]);
		_Error->
			NewStatus = Status,
			{ok, BinData} = pt_41:write(41017,[0,0,0,0,0,0,0])
	end,
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	{ok, NewStatus};

%% -----------------------------------------------------------------
%% 判断灵兽是否可以化形
%% add by zkj
%% -----------------------------------------------------------------
handle(41018,Status,[PetId])->
	case (catch lib_pet:judge_pet_chenge(Status,[PetId]))of
		{ok,CanChange}-> %%可以进行化形
			{ok, BinData} = pt_41:write(41018,[CanChange]);
		{fail,Error}-> %%不可以进行化形
			{ok, BinData} = pt_41:write(41018,[Error]);
		_Error-> %%异常
			{ok, BinData} = pt_41:write(41018,[0])
	end,
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%% 灵兽化形
%% add by zkj
%% -----------------------------------------------------------------
handle(41019,Status,[PetId])->
	case ( lib_pet:pet_chenge(Status,[PetId]))of
		{ok,PlayerStatus,_}-> %%可以进行化形
			Change_statue = 1,
			{ok, BinData} = pt_41:write(41019,[1]);
		{fail,Error}-> %%不可以进行化形
			Change_statue = 0,
			{ok, BinData} = pt_41:write(41019,[Error]),
			PlayerStatus = Status;
		_Error-> %%异常
			Change_statue = 0,
			{ok, BinData} = pt_41:write(41019,[0]),
			PlayerStatus = Status
	end,
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	if
		Change_statue =/= 0 ->
			handle(41008, PlayerStatus, [PlayerStatus#player.id]);
		true ->
			ok
	end,
    {ok,PlayerStatus};

%% -----------------------------------------------------------------
%% 购买化形果实
%% add by zkj
%% -----------------------------------------------------------------
handle(41020,Status,[_r])->
	case (catch lib_pet:buy_chenge_fruit(Status))of
		{ok, NewStatus, Buy_statue}-> %%购买成功
			{ok, BinData} = pt_41:write(41020,[Buy_statue]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
			{ok, NewStatus};
		{fail,_NewStatus, Error}-> %%购买失败
			{ok, BinData} = pt_41:write(41020,[Error]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
			ok;
		_Error-> %%异常
			{ok, BinData} = pt_41:write(41020,[0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData)
	end;
	
%% -----------------------------------------------------------------
%% 灵兽融合
%% add by zkj
%% -----------------------------------------------------------------
handle(41021,Status,[PetId1, PetId2])->
	case  lib_pet:pet_merge(Status,[PetId1, PetId2])of
		{ok, Merge_success}-> %%融合成功
			Merge_statue = 1,
			{ok, BinData} = pt_41:write(41021,Merge_success),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData);
		{fail, Merge_error}-> %%融合失败
			Merge_statue = 0,
			{ok, BinData} = pt_41:write(41021,Merge_error),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData);
		_Error-> %%异常
			Merge_statue = 0,
			ok
	end,
	if
		Merge_statue =/= 0 ->
			pp_pet:handle(41008, Status, [Status#player.id]);
		true ->
			ok
	end;

%% -----------------------------------------------------------------
%% 灵兽融合预览
%% add by zkj
%% -----------------------------------------------------------------
handle(41022,Status,[PetId1, PetId2])->
	case ( lib_pet:pet_merge_preview(Status,[PetId1, PetId2]))of
		{ok, Merge_success}-> %%融合成功
			{ok, BinData} = pt_41:write(41022,Merge_success),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData);
		{fail, Merge_error}-> %%融合失败
			{ok, BinData} = pt_41:write(41022,Merge_error),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData);
		_Error-> %%异常
			ok
	end;

%% -----------------------------------------------------------------
%% 获取某个玩家的灵兽信息
%% add by zkj
%% -----------------------------------------------------------------
handle(41023, Status, [PetId]) ->
    Pet = lib_pet:get_player_pet_info([PetId]),
    {ok, BinData} = pt_41:write(41023, [Pet]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);

%% -----------------------------------------------------------------
%% 灵兽技能分离
%% -----------------------------------------------------------------
handle(41024,PlayerStatus,[PetId])->
	Data = mod_pet:split_skill(PlayerStatus,[PetId]),
	{ok,BinData} = pt_41:write(41024,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%% 灵兽分离技能列表
%% -----------------------------------------------------------------
handle(41025,PlayerStatus,[])->
	Data = mod_pet:get_all_split_skill(PlayerStatus#player.id),
	{ok,BinData} = pt_41:write(41025,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%% 灵兽一键合成所有闲置技能
%% -----------------------------------------------------------------
handle(41026,PlayerStatus,[])->
	Data = mod_pet:merge_all_split_skill(PlayerStatus#player.id),
	{ok,BinData} = pt_41:write(41026,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%% 技能合成或升级,分离Oper(1为技能合并预览，2为正式技能合并)
%% -----------------------------------------------------------------
handle(41027,PlayerStatus,[PetId,Type,Oper,Skill1,Skill2])->
	Data = mod_pet:drag_skill(PlayerStatus#player.id,PetId,Type,Oper,Skill1,Skill2),
	{ok,BinData} = pt_41:write(41027,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%% 灵兽购买面板
%% -----------------------------------------------------------------
handle(41029,PlayerStatus,[])->
	Data = mod_pet:pet_buy_list(PlayerStatus#player.id),
	{ok,BinData} = pt_41:write(41029,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%% 刷新灵兽购买面板
%% -----------------------------------------------------------------
handle(41030,PlayerStatus,[])->
	Data = mod_pet:flush_pet_buy_list(PlayerStatus),
	{ok,BinData} = pt_41:write(41030,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%% 灵兽批量操作type 1为技能批量分离，2为灵兽放生
%% -----------------------------------------------------------------
handle(41031,PlayerStatus,[Type])->
	Data = mod_pet:batch_oper(PlayerStatus#player.id,Type),
	{ok,BinData} = pt_41:write(41031,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);
		

%% ------------------------------------------------------------------
%% 出战灵兽技能经验自动增长
%% ------------------------------------------------------------------
handle(41032,PlayerStatus,[PetId]) ->
	mod_pet:add_pet_skill_exp_auto(PlayerStatus,PetId);

%% ------------------------------------------------------------------
%% 设置灵兽自动萃取的阶数
%% ------------------------------------------------------------------
handle(41034,PlayerStatus,[Auto_Step]) ->
	Data = mod_pet:set_auto_step(PlayerStatus#player.id,Auto_Step),
	{ok,BinData} = pt_41:write(41034,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% ------------------------------------------------------------------
%% 随机批量购买面板列表
%% ------------------------------------------------------------------
handle(41035,PlayerStatus,[]) ->
	Data = mod_pet:get_random_pet_buy_list(PlayerStatus#player.id),
	{ok,BinData} = pt_41:write(41035,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% ------------------------------------------------------------------
%% 随机批量购买面板购买动作Order为顺序号，为0是购买所有,单个购买顺序号1-6
%% ------------------------------------------------------------------
handle(41036,PlayerStatus,[Order]) ->
	Data = mod_pet:buy_random_pet(PlayerStatus,Order),
	{ok,BinData} = pt_41:write(41036,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% ------------------------------------------------------------------
%% 查询玩家的幸运值和经验槽经验值
%% ------------------------------------------------------------------
handle(41037,PlayerStatus,[]) ->
	Data = mod_pet:query_lucky_exp(PlayerStatus#player.id),
	{ok,BinData} = pt_41:write(41037,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%% 通过经验槽经验值提升技能等级
%% -----------------------------------------------------------------
handle(41039,PlayerStatus,[PetId,Skill])->
	Data = mod_pet:update_skill_level_by_exp(PlayerStatus,PetId,Skill),
	{ok,BinData} = pt_41:write(41039,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%% 灵兽一键萃取所有闲置技能
%% -----------------------------------------------------------------
handle(41040,PlayerStatus,[])->
	Data = mod_pet:fetch_all_split_skill(PlayerStatus),
	{ok,BinData} = pt_41:write(41040,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%% 灵兽化形类型id
%% -----------------------------------------------------------------
handle(41041,PlayerStatus,[PetTypeId])->
	Data = lib_pet:get_chenge_id(PetTypeId),
	if Data == [] ->
		   Data1 = 0;
	   true ->
		   Data1 = Data
	end,
	{ok,BinData} = pt_41:write(41041,Data1),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%%  灵兽神兽蛋预览
%% -----------------------------------------------------------------
handle(41042,PlayerStatus,[])->
	Data = mod_pet:egg_view(PlayerStatus#player.id),
	{ok,BinData} = pt_41:write(41042,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);


%% -----------------------------------------------------------------
%% Type 1神兽蛋获取技能,2神兽蛋萃取经验
%% -----------------------------------------------------------------
handle(41043,PlayerStatus,[Type])->
	Data = mod_pet:fetch_egg_skill(PlayerStatus,Type),
	case Data of
		{fail,Code,Ets_Pet_Extra} ->
			Data1 = [Code,Ets_Pet_Extra#ets_pet_extra.lucky_value,0,0,Ets_Pet_Extra#ets_pet_extra.free_flush,lib_pet:get_max_free_flush()];
		{ok,[Lucky_value,Skill_Id,Step,Dree_flush2,FREE_FLUSE_TIMES]} ->
			spawn(fun()->lib_task:event(use_goods, {24800}, PlayerStatus)end),
			Data1 = [1,Lucky_value,Skill_Id,Step,Dree_flush2,FREE_FLUSE_TIMES]
	end,		
	{ok,BinData} = pt_41:write(41043,Data1),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%% 1神兽蛋面板免费刷新,2批量购买面板免费刷新,2批量购买面板批量元宝刷新 动作Order为顺序号，为0是神兽蛋免费刷新　批量购买免费刷新顺序号1-6
%% -----------------------------------------------------------------
handle(41044,PlayerStatus,[Type,Order])->
	{_,Code} = mod_pet:free_flush(PlayerStatus,Type,Order),
	{ok,BinData} = pt_41:write(41044,Code),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);


%% -----------------------------------------------------------------
%%  战魂石预览
%% -----------------------------------------------------------------
handle(41046,PlayerStatus,[Gid])->
	Data = mod_pet:batt_stone_view(PlayerStatus#player.id,Gid),
	{ok,BinData} = pt_41:write(41046,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);


%% ----------------------------------------------------------------
%%查看战斗技能批量刷新面板	
%% ----------------------------------------------------------------
handle(41047,PlayerStatus,[Gid]) ->
	Data = mod_pet:get_batch_batt_skill_list(PlayerStatus#player.id,Gid),
	{ok,BinData} = pt_41:write(41047,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% ----------------------------------------------------------------
%%战斗技能刷新	Type 1为战魂石免费刷新　2为战魂石元宝刷新　3为战魂石批量刷新 4为灵水刷新单个技能 5为灵水批量刷新技能
%% ----------------------------------------------------------------
handle(41048,PlayerStatus,[Gid,Type]) ->
	Data = mod_pet:fluse_batt_skill(PlayerStatus,Gid,Type),
	{ok,BinData} = pt_41:write(41048,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%%  战斗技能获取Order 0为忆魂石页面,1-12为战斗技能批量刷新面板
%% -----------------------------------------------------------------
handle(41049,PlayerStatus,[Gid,Order])->
	Data = mod_pet:batt_skill_fetch(PlayerStatus,Gid,Order),
	{ok,BinData} = pt_41:write(41049,Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% -----------------------------------------------------------------
%%战斗技能 Type 1技能书学习 2删除技能书
%% -----------------------------------------------------------------
handle(41050,PlayerStatus,[Gid,PetId,Type])->
	if Type == 1 ->
		   [Code,NewPlayerStatus] = mod_pet:learn_batt_skill(PlayerStatus,Gid,PetId),
		   if Code == 1 ->
				  handle(41008, PlayerStatus, [PlayerStatus#player.id]);
			  true ->
				  skip
		   end,
		   {ok,BinData} = pt_41:write(41050,Code),
		   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
		   Pet_batt_skill = lib_pet:get_out_pet_batt_skill(PlayerStatus#player.id),
		   NewPlayerStatus1 = NewPlayerStatus#player{other = NewPlayerStatus#player.other#player_other{pet_batt_skill = Pet_batt_skill}},
		   {ok,NewPlayerStatus1};
	   Type == 2 ->
		   [Code,_NewPlayerStatus] = mod_pet:del_batt_skill(PlayerStatus,Gid),
		   {ok,BinData} = pt_41:write(41050,Code),
		   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);
	   true ->
		   skip
	end;

%% ----------------------------------------------------------------
%%战斗技能遗忘
%% ----------------------------------------------------------------
handle(41051,PlayerStatus,[PetId,SkillId])->
	Code = mod_pet:forget_batt_skill(PlayerStatus#player.id,PetId,SkillId),
	if Code == 1 ->
		   handle(41008, PlayerStatus, [PlayerStatus#player.id]);
	   true ->
		   skip
	end,
	{ok,BinData} = pt_41:write(41051,Code),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	Pet_batt_skill = lib_pet:get_out_pet_batt_skill(PlayerStatus#player.id),
	NewPlayerStatus = PlayerStatus#player{other = PlayerStatus#player.other#player_other{pet_batt_skill = Pet_batt_skill}},
	{ok,NewPlayerStatus};

%% ----------------------------------------------------------------
%%战斗技能封印
%% ----------------------------------------------------------------
handle(41052,PlayerStatus,[PetId,SkillId])->
	Code = mod_pet:transfer_batt_skill(PlayerStatus,PetId,SkillId),
	if Code == 1 ->
		   handle(41008, PlayerStatus, [PlayerStatus#player.id]);
	   true ->
		   skip
	end,
	{ok,BinData} = pt_41:write(41052,Code),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	Pet_batt_skill = lib_pet:get_out_pet_batt_skill(PlayerStatus#player.id),
	NewPlayerStatus = PlayerStatus#player{other = PlayerStatus#player.other#player_other{pet_batt_skill = Pet_batt_skill}},
	{ok,NewPlayerStatus};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
handle(_Cmd, _Status, _Data) ->
    {error, "pp_pet no match"}.



