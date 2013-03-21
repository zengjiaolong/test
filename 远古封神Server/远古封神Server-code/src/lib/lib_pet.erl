%%%--------------------------------------
%%% @Module  : lib_pet
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description : 宠物信息
%%%--------------------------------------
-module(lib_pet).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-compile(export_all).


-define(CHENGE_FRUIT_ID, 24106).%%化形果实ID
-define(RANDOM_PET_PRICE, 48).%%随机灵兽购买价格
-define(BATCHRANDOM_PET_PRICE, 268).%%随机灵兽购买价格
-define(PET_LUCKY_VALUE, 5).%%购买随机灵兽增加的幸运值
-define(FREE_FLUSH_TIMES,6).%%免费刷新次数(神兽蛋和批量购买都是6次)
-define(FREE_BATT_FLUSH_TIMES,6).%%战斗技能免费刷新次数(战魂石免费刷新次数都是1次)
-define(FLUSH_COST,10).%%技能元宝刷新消费
%%=========================================================================
%% 初始化回调函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 系统启动后的加载
%% -----------------------------------------------------------------

get_max_free_flush() ->
	?FREE_FLUSH_TIMES.

get_flush_cost() ->
	?FLUSH_COST.

load_base_pet() ->
    BasePetList = db_agent:load_base_pet(),
    lists:map(fun load_base_pet_into_ets/1, BasePetList),
	ok.

load_base_pet_into_ets(PetInfo) ->
    BasePet =list_to_tuple([ets_base_pet]++PetInfo),
    update_base_pet(BasePet).

%%灵兽技能效果表
load_base_pet_skill_effect() -> 
	BasePetSkillEffectList = db_agent:load_base_pet_skill_effect(),
    lists:map(fun load_base_pet_skill_effect_into_ets/1, BasePetSkillEffectList),
	ok.

load_base_pet_skill_effect_into_ets(BasePetSkillEffect) ->
    BasePetSkillEffectInfo =list_to_tuple([ets_base_pet_skill_effect]++BasePetSkillEffect),
    update_base_pet_skill_effect(BasePetSkillEffectInfo).

%% -----------------------------------------------------------------
%% 登录后的初始化
%% -----------------------------------------------------------------
role_login(PlayerStatus,Pid_send,Pid_Goods) ->
    %%加载灵兽
	load_all_pet(PlayerStatus,Pid_send,Pid_Goods),
	load_all_pet_buy(PlayerStatus),
	load_all_pet_split_skill(PlayerStatus),
	load_all_pet_buy(PlayerStatus),
	load_pet_extra(PlayerStatus),
	load_pet_extra_buy(PlayerStatus),
    Pet = get_out_pet(PlayerStatus#player.id),
    % 灵兽加成
    if
		is_record(Pet,ets_pet) ->
			[Pet#ets_pet.forza,Pet#ets_pet.wit,Pet#ets_pet.agile,Pet#ets_pet.physique];
		true ->
			[0,0,0,0]
	end.

%%加载角色灵兽
load_all_pet(PlayerStatus,Pid_send,Pid_Goods) ->
    PetList = db_agent:select_player_all_pet(PlayerStatus#player.id),
	lists:map(fun(E)-> load_pet_into_ets(PlayerStatus,Pid_send,Pid_Goods,E) end,PetList),
    length(PetList).

%%加载角色灵兽购买记录
load_all_pet_buy(PlayerStatus) ->
	PetBuyList = db_agent:load_all_pet_buy(PlayerStatus#player.id),
	lists:map(fun(PetBuy)-> load_pet_buy_into_ets(PetBuy) end,PetBuyList),
	ok.

%%加载角色灵兽技能分离
load_all_pet_split_skill(PlayerStatus) ->
	PetSplitSkillList = db_agent:load_all_pet_split_skill(PlayerStatus#player.id),
	lists:map(fun(PetSplitSkill)-> load_pet_split_skill_into_ets(PetSplitSkill) end,PetSplitSkillList),
	ok.

%%加载角色灵兽额外信息
load_pet_extra(PlayerStatus) ->
	PeExtraList = db_agent:load_pet_extra(PlayerStatus#player.id),
	if 
		%%如果没有数据就新增一条
		PeExtraList == [] ->
			 Id = db_agent:save_pet_extra(PlayerStatus#player.id,0,0,0),
			 NewPetExtra = #ets_pet_extra{
							  id = Id,
							  player_id = PlayerStatus#player.id,
							  skill_exp = 0,
							  lucky_value = 0,
							  batt_lucky_value = 0,
							  auto_step = 0,
							  free_flush = 0,
							  last_time = 0							  
			};
		true ->
			NewPetExtra =  list_to_tuple([ets_pet_extra]++PeExtraList)
	end,
	load_pet_extra_into_ets(NewPetExtra),
	ok.

%%加载玩家的随机购买灵兽的数据
load_pet_extra_buy(PlayerStatus) ->
	PetExtraValue = db_agent:get_random_pet(PlayerStatus#player.id),
	if
		PetExtraValue == [] ->
			skip;
		true ->
			NewPetExtraValue = list_to_tuple([ets_pet_extra_value]++PetExtraValue),
			load_ets_pet_extra_value_into_ets(NewPetExtraValue)
	end.
	

%%加载灵兽到ets
load_pet_into_ets(PlayerStatus,Pid_send,Pid_Goods,PetInfo) ->
    Pet = list_to_tuple([ets_pet]++PetInfo),
	PetNew= case Pet#ets_pet.grow<20 of
				true->
					Grow = get_pet_base_grow(base),
					db_agent:pet_get_grow(Pet#ets_pet.id,Grow),
					Pet#ets_pet{grow=Grow};
				false->Pet
			end,
	[AddPoint,PrevGrow] = data_pet:get_add_extra_point(PetNew#ets_pet.grow,PetNew#ets_pet.apt_range),
	if AddPoint > 0 ->
		   PetNew1 = PetNew#ets_pet{point=PetNew#ets_pet.point+AddPoint,apt_range=PrevGrow};
	   true ->
		   PetNew1 = PetNew
	end,
	{ok,NewPet} = lib_train_finish(PlayerStatus,Pid_send,Pid_Goods,PetNew1),
    update_pet(NewPet).

%%加载灵兽购买记录到ets
load_pet_buy_into_ets(PetBuy) ->
    PetBuyInfo = list_to_tuple([ets_pet_buy]++PetBuy),
    update_pet_buy(PetBuyInfo).

%%加载灵分离技能记录到ets
load_pet_split_skill_into_ets(PetSplitSkill) ->
    PetSplitSkillInfo = list_to_tuple([ets_pet_split_skill]++PetSplitSkill),
    update_pet_split_skill(PetSplitSkillInfo).

%%加载角色灵兽额外信息
load_pet_extra_into_ets(PetExtra) ->
    insert_pet_extra(PetExtra).

%%加载玩家的随机购买灵兽的数据
load_ets_pet_extra_value_into_ets(PetExtraValue) ->
	save_pet_extra_value(PetExtraValue).

%%添加购买记录
add_pet_buy(Player_Id,Goods_id,Now) ->
	Id = db_agent:save_pet_buy(Player_Id,Goods_id,Now),
	PetBuyInfo = #ets_pet_buy{
							  id = Id,
							  player_id = Player_Id,
							  goods_id = Goods_id,
							  ct = Now							  
			},
	ets:insert(?ETS_PET_BUY, PetBuyInfo).

%% -----------------------------------------------------------------
%% 退出后的存盘
%% -----------------------------------------------------------------
role_logout(PlayerId) ->
%% 	Pet  = get_out_pet(PlayerId),
%% 	if is_record(Pet,ets_pet) =:= true ->
%% 		   save_pet(Pet);
%% 	   true->skip
%% 	end,
    %% 删除所有缓存宠物
    delete_all_pet(PlayerId),
	delete_all_pet_split_skill(PlayerId),
	delete_all_pet_buy(PlayerId),
	%%删除两天前的购买记录
	db_agent:delete_all_pet_buy(PlayerId).


save_pet(Pet) ->
	if Pet#ets_pet.chenge > 2 ->
		   Chenge = 1;
	   true ->
		   Chenge = Pet#ets_pet.chenge
	end,
    db_agent:save_pet(Pet#ets_pet.id,
					  Pet#ets_pet.goods_id,
					  Pet#ets_pet.level,
					  Pet#ets_pet.exp,
					  Pet#ets_pet.forza,
					  Pet#ets_pet.wit,
					  Pet#ets_pet.agile,
					  Pet#ets_pet.physique,
					  Pet#ets_pet.happy,
					  Pet#ets_pet.aptitude,
					  Pet#ets_pet.point,
					  Pet#ets_pet.grow,
					  Pet#ets_pet.skill_1,
					  Pet#ets_pet.skill_2,
					  Pet#ets_pet.skill_3,
					  Pet#ets_pet.skill_4,
					  Pet#ets_pet.skill_5,
					  Pet#ets_pet.skill_6,
					  Chenge,
					  Pet#ets_pet.batt_skill,
					  Pet#ets_pet.apt_range
					 ).

save_pet_split_skill(Pet) ->
	Skill_1 = Pet#ets_pet.skill_1,
	Skill_2 = Pet#ets_pet.skill_2,
	Skill_3 = Pet#ets_pet.skill_3,
	Skill_4 = Pet#ets_pet.skill_4,
	Skill_5 = Pet#ets_pet.skill_5,
	Skill_6 = Pet#ets_pet.skill_6,
	SkillList = [Skill_1,Skill_2,Skill_3,Skill_4,Skill_5,Skill_6],
	Now = util:unixtime(),
	F = fun(Skill) ->
				if 
					Skill =/= <<"[0,0,0,0]">> ->
						Id = db_agent:save_pet_split_skill(Pet#ets_pet.player_id,Pet#ets_pet.id,Skill,Now),
						PetSplitSkillInfo = #ets_pet_split_skill{id=Id,player_id=Pet#ets_pet.player_id,pet_id=Pet#ets_pet.id,pet_skill=Skill,ct=Now},
						update_pet_split_skill(PetSplitSkillInfo),
						spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(Pet#ets_pet.player_id,Pet#ets_pet.id, Skill, Skill, 1, Now)) end),
						%%保存灵兽的信息
						NewPet = Pet#ets_pet{skill_1 = <<"[0,0,0,0]">>,skill_2 = <<"[0,0,0,0]">>,skill_3 = <<"[0,0,0,0]">>,skill_4 = <<"[0,0,0,0]">>,skill_5 = <<"[0,0,0,0]">>,skill_6 = <<"[0,0,0,0]">>},
						lib_pet:update_pet(NewPet),
						save_pet(NewPet);
					true ->
						skip
				end
		end,	
	[F(Skill) || Skill <- SkillList],
	1.

updata_pet_split_skill(PetSplitSkillInfo) ->
	db_agent:updata_pet_split_skill(PetSplitSkillInfo).

save_pet_extra_value_db(Ets_pet_extra_value) ->
	db_agent:insert_random_pet(Ets_pet_extra_value#ets_pet_extra_value.player_id,
								   Ets_pet_extra_value#ets_pet_extra_value.before_value,
								   Ets_pet_extra_value#ets_pet_extra_value.after_value,
								   Ets_pet_extra_value#ets_pet_extra_value.before_value1,
							       Ets_pet_extra_value#ets_pet_extra_value.after_value1,
							   	   Ets_pet_extra_value#ets_pet_extra_value.batt_before_value,
							       Ets_pet_extra_value#ets_pet_extra_value.batt_after_value,
								   Ets_pet_extra_value#ets_pet_extra_value.order,
								   Ets_pet_extra_value#ets_pet_extra_value.ct).

update_pet_extra_value_db(Ets_pet_extra_value) ->
	db_agent:updata_random_pet(Ets_pet_extra_value#ets_pet_extra_value.player_id,
								   Ets_pet_extra_value#ets_pet_extra_value.before_value,
								   Ets_pet_extra_value#ets_pet_extra_value.after_value,
							       Ets_pet_extra_value#ets_pet_extra_value.before_value1,
								   Ets_pet_extra_value#ets_pet_extra_value.after_value1,
							       Ets_pet_extra_value#ets_pet_extra_value.batt_before_value,
							       Ets_pet_extra_value#ets_pet_extra_value.batt_after_value,
								   Ets_pet_extra_value#ets_pet_extra_value.order,
								   Ets_pet_extra_value#ets_pet_extra_value.ct).
	

%%=========================================================================
%% 业务操作函数
%%=========================================================================

%%生成灵兽
give_pet_task(PlayerId,GoodsId)->
%% 	Goods_id = 24600,
	PetTypeInfo = lib_pet:get_base_pet(GoodsId),
	give_pet(PlayerId,PetTypeInfo,20,1).
		
%%获取一个灵兽id
get_out_pet_id(PlayerId)->
	case get_all_pet(PlayerId) of
		[]->error;
		[Pet|_]->Pet#ets_pet.id
	end.

give_pet(PlayerId,PetTypeInfo,Aptitude,Step) ->
	%%资质
	GoodsId = PetTypeInfo#ets_base_pet.goods_id,
	Name = PetTypeInfo#ets_base_pet.name,
	SkillId = PetTypeInfo#ets_base_pet.skill,
	%%改版后的灵兽技能格式改变
	if 
		SkillId == 0 ->
		   NewSkill = tool:to_binary(util:term_to_string([0,0,0,0]));
	   true ->
		   NewSkill = tool:to_binary(util:term_to_string([SkillId,1,Step,0]))
	end,
	Grow = get_pet_base_grow(new),
	Point = data_pet:grow_to_point(Grow),
	case db_agent:give_pet(PlayerId,GoodsId,Name,Aptitude,Grow,Point,NewSkill) of
		{mongo,Ret} ->
			Pet = #ets_pet{id = Ret,player_id = PlayerId,goods_id = GoodsId,name = Name,aptitude = Aptitude,grow = Grow,point = Point,skill_1 = NewSkill};
		_Ret ->
			PetData = db_agent:get_new_pet(PlayerId),
			Pet = list_to_tuple([ets_pet]++ PetData)
	end,
	case is_record(Pet,ets_pet) of
		true ->
			ets:insert(ets_pet,Pet),
			{ok,Pet#ets_pet.id,Pet#ets_pet.name,Grow};
		false ->
			{fail,0,<<>>}
	end.


%% -----------------------------------------------------------------
%% 灵兽放生
%% -----------------------------------------------------------------
free_pet(PetId) ->
    db_agent:free_pet(PetId),
    % 更新缓存
    delete_pet(PetId),
    ok.

%% -----------------------------------------------------------------
%% 灵兽改名
%% -----------------------------------------------------------------
rename_pet(Pet, NewName) ->    
    % 更新灵兽名
    db_agent:rename_pet(Pet#ets_pet.id, NewName),
	 % 更新ets
    PetNew = Pet#ets_pet{ name = NewName},
    lib_pet:update_pet(PetNew),
    ok.

%% -----------------------------------------------------------------
%% 修改灵兽属性点
%% -----------------------------------------------------------------
mod_pet_attribute(Pet,Forza,Agile,Wit,Physique) ->
	Num = Forza+Agile+Wit+Physique - Pet#ets_pet.forza - Pet#ets_pet.agile - Pet#ets_pet.wit - Pet#ets_pet.physique,
	Point = Pet#ets_pet.point - Num,
	PetNew = Pet#ets_pet{forza = Forza,agile = Agile,wit = Wit,physique = Physique,point = Point},
	db_agent:log_pet_addpoint(Pet#ets_pet.player_id,Pet#ets_pet.id,Point,Forza,Agile,Wit,Physique,util:unixtime()),
	save_pet(PetNew),
	lib_pet:update_pet(PetNew),	
	{ok,PetNew}.

%%灵兽加点提示
add_point_tips(NewPet,OldPet,PlayerStatus)->
	%%[力量,体质,敏捷,智力]
	[New_hp,New_att,New_hit,New_mp] = count_att_add(NewPet,PlayerStatus#player.career,PlayerStatus#player.lv),
	[Old_hp,Old_att,Old_hit,Old_mp] = count_att_add(OldPet,PlayerStatus#player.career,PlayerStatus#player.lv),
	[Pet_hp,Pet_att,Pet_hit,Pet_mp] = [New_hp-Old_hp,New_att-Old_att,New_hit-Old_hit,New_mp-Old_mp],
	Msg=io_lib:format("灵兽【~s】加点，人物属性增加~p气血；增加~p攻击；增加~p命中；增加~p法力",[NewPet#ets_pet.name,Pet_hp,Pet_att,Pet_hit,Pet_mp]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin),
	[Pet_hp,Pet_att,Pet_hit,Pet_mp].

count_att_add(Pet,Career,Lv)->
	Pet_forza = (Pet#ets_pet.forza)*Pet#ets_pet.aptitude / 50 ,
	Pet_physique = (Pet#ets_pet.physique)*Pet#ets_pet.aptitude / 50,
	Pet_agile = (Pet#ets_pet.agile)*Pet#ets_pet.aptitude / 50,
	Pet_wit = (Pet#ets_pet.wit)*Pet#ets_pet.aptitude / 50,
 	lib_player:pet_attribute_1_to_2(Pet_forza,Pet_physique,Pet_agile,Pet_wit,Career,Lv).

%% -----------------------------------------------------------------
%% 灵兽洗点
%% -----------------------------------------------------------------
mod_clear_attribute(PlayerStatus,Pet) -> 
	case gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', 24101, 1}) of
		1->
			Point = round(Pet#ets_pet.level*data_pet:grow_to_point(Pet#ets_pet.grow)), 
			[AddPoint,PrevGrow] = data_pet:get_add_extra_point(Pet#ets_pet.grow,0),
			PetNew = Pet#ets_pet{forza = 0,agile = 0,wit = 0,physique = 0,point = Point+AddPoint,apt_range=PrevGrow},
			db_agent:log_pet_wash_point(PlayerStatus#player.id,Pet#ets_pet.id,Point+AddPoint,util:unixtime()),
			save_pet(PetNew),
			lib_pet:update_pet(PetNew),	
			{ok,PetNew};
		_->
			{fail,4}
	end.

%% -----------------------------------------------------------------
%% 灵兽洗点 (物品使用触发)
%% -----------------------------------------------------------------
wash_pet(Pet,PlayerStatus) ->
	if
		is_record(Pet,ets_pet) =:= true ->
			Point = round(Pet#ets_pet.level*data_pet:grow_to_point(Pet#ets_pet.grow)),
			[AddPoint,PrevGrow] = data_pet:get_add_extra_point(Pet#ets_pet.grow,0),
			PetNew = Pet#ets_pet{forza = 0,agile = 0,wit = 0,physique = 0,point = Point+AddPoint,apt_range=PrevGrow},
			db_agent:log_pet_wash_point(PlayerStatus#player.id,Pet#ets_pet.id,Point+AddPoint,util:unixtime()),
			ets:insert(ets_pet,PetNew),
			save_pet(PetNew),
			lib_pet:update_pet(PetNew),
			{ok,BinData} = pt_41:write(41013,[1,PetNew#ets_pet.id,PetNew#ets_pet.point]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
			{ok,PetNew};
		true ->
			{fail}
	end.

%% -----------------------------------------------------------------
%% 灵兽出战
%% -----------------------------------------------------------------
out_pet(Pet) ->
	Time = util:unixtime(),
	PetNew = Pet#ets_pet{status = 1,time = Time}, 
	lib_pet:update_pet(PetNew),
  	db_agent:pet_update_status(PetNew#ets_pet.id,1),
	PetNew.


%% -----------------------------------------------------------------
%% 灵兽休息
%% -----------------------------------------------------------------
rest_pet(Pet) ->
	PetNew = Pet#ets_pet{status = 0,time =0}, 
	lib_pet:update_pet(PetNew),
    db_agent:pet_update_status(PetNew#ets_pet.id,0),
    PetNew.


%% -----------------------------------------------------------------
%% 喂养灵兽
%% -----------------------------------------------------------------
feed_pet(Status,PetInfo,Food_type,GoodsUseNum) ->
	case gen_server:call(Status#player.other#player_other.pid_goods, {'DELETE_MORE_BIND_PRIOR', Food_type, GoodsUseNum}) of
         1 -> 
			 HappyValue =
				 if
					 GoodsUseNum * 200 + PetInfo#ets_pet.happy > 1000 ->
						 1000;
					 true ->
						 GoodsUseNum * 200 + PetInfo#ets_pet.happy
				 end,
			 PetNew=PetInfo#ets_pet{happy = HappyValue},
			 ets:insert(ets_pet,PetNew),
			 save_pet(PetNew),
             {ok,PetNew};
         GoodsModuleCode ->
             GoodsModuleCode
    end.

%% 在背包中使用灵兽口粮
feed_pet(PlayerStatus,PetInfo,GoodsNum)->
	HappyValue = 
		if
			200 * GoodsNum + PetInfo#ets_pet.happy > 1000 ->
				1000;
			true ->
				200 * GoodsNum + PetInfo#ets_pet.happy
		end,
	PetNew = PetInfo#ets_pet{happy = HappyValue},
	ets:insert(ets_pet,PetNew),
	MaxExp = data_pet:get_upgrade_exp(PetNew#ets_pet.level),
	{ok,BinData} = pt_41:write(41010,[1,PetNew#ets_pet.id,PetNew#ets_pet.happy,PetNew#ets_pet.exp,PetNew#ets_pet.level,MaxExp,PetNew#ets_pet.name,PetNew#ets_pet.goods_id,PetNew]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	mod_pet:pet_attribute_effect(PlayerStatus,PetNew),
	ok.


%% -----------------------------------------------------------------
%% 灵兽资质提升
%% -----------------------------------------------------------------
upgrade_aptitude(Status,PetInfo,AptType,PType,Rule,AptNum,GoldCost) ->
	Result = 
	if AptNum == 0 -> %%原来背包里是否有资质符(直接消费元宝)
		   1;
	   true ->
		   case gen_server:call(Status#player.other#player_other.pid_goods,{'delete_more',AptType,1}) of 
			   1 ->
				   1;
			  Code ->
				  Code
		   end
	end,
	 Safe =
		if   PType > 0 ->
				 case gen_server:call(Status#player.other#player_other.pid_goods,{'delete_more',PType,1}) of
					 1 ->
						 1;
					 _ERR_CODE ->
						 0
				 end;
			 true ->
				 0
		end,
	if Result == 1 ->
		   Rand = util:rand(1,10000),
			[Ratio,Cost] = Rule,
			{Res,Aptitude} =
			if
				%%成功
				Ratio * 100 > Rand ->
					AddAptitude = data_pet:get_add_random_aptitude(PetInfo#ets_pet.aptitude),
					if
						PetInfo#ets_pet.chenge =/= 0 -> %%是否已经化形
							if
								PetInfo#ets_pet.aptitude + AddAptitude > 80 andalso PetInfo#ets_pet.chenge =/=2 -> %% 一次化形后最高资质为80
									log_up_apt(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.aptitude,80,Ratio,Rand,Safe,Cost),
									{1,80};
								PetInfo#ets_pet.aptitude + AddAptitude > 100 andalso PetInfo#ets_pet.chenge ==2 -> %% 二次化形后最高资质为100
									log_up_apt(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.aptitude,100,Ratio,Rand,Safe,Cost),
									{1,100};
								true ->
									log_up_apt(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.aptitude,PetInfo#ets_pet.aptitude + AddAptitude,Ratio,Rand,Cost,Safe),
									{1,PetInfo#ets_pet.aptitude + AddAptitude}
							end;
						true -> %%未化形
							if
								PetInfo#ets_pet.aptitude + AddAptitude > 70 -> %%未化形最高资质为70
									log_up_apt(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.aptitude,70,Ratio,Rand,Cost,Safe),
									{1,70};
								true ->
									log_up_apt(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.aptitude,PetInfo#ets_pet.aptitude + AddAptitude,Ratio,Rand,Cost,Safe),
									{1,PetInfo#ets_pet.aptitude + AddAptitude}
							end
					end;
				%%失败
				true ->
					case Safe of
						1 ->
							log_up_apt(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.aptitude,PetInfo#ets_pet.aptitude ,Ratio,Rand,Cost,Safe),
							{0,PetInfo#ets_pet.aptitude};
						0 ->
							SubAptitude = data_pet:get_sub_random_aptitude(PetInfo#ets_pet.aptitude),
							if PetInfo#ets_pet.aptitude - SubAptitude < 20 ->
								   log_up_apt(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.aptitude,20,Ratio,Rand,Cost,Safe),
								   {0,20};
							   true ->
								   log_up_apt(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.aptitude,PetInfo#ets_pet.aptitude - SubAptitude,Ratio,Rand,Cost,Safe),
								   {0,PetInfo#ets_pet.aptitude - SubAptitude}
							end
					end
			end,
			PetNew = PetInfo#ets_pet{aptitude = Aptitude},
			ets:insert(ets_pet,PetNew),
			save_pet(PetNew),
			%%扣铜币
			NewStatus = lib_goods:cost_money(Status,Cost,coin,4101),
		    if AptNum == 0 ->%%直接扣元宝
				   spawn(fun() ->log:log_shop([1,1,NewStatus#player.id,NewStatus#player.nickname,AptType,gold,GoldCost,1]) end),
				   NewStatus1 = lib_goods:cost_money(NewStatus,GoldCost,gold,4107);
			   true ->
				   NewStatus1 = NewStatus
		    end,
			%%返回值
			{ok,NewStatus1,PetNew,Res};
	   true ->
		   {fail,Result}
	end.
	
	

%%灵兽资质提升日志
log_up_apt(PlayerId,PetId,OldApt,NewApt,Ratio,Rand,Cost,Safe)->
	spawn(fun()->catch(db_agent:upgrade_aptitude_log([PlayerId,PetId,OldApt,NewApt,Ratio* 100,Rand,Cost,Safe,util:unixtime()]))end).


  %% -----------------------------------------------------------------
%% 灵兽成长值提升
%% -----------------------------------------------------------------
upgrade_grow(Status,PetInfo,GrowType,PType,Rule,Lucky,GrowNum,GrowCost) ->
	Result = 
	if GrowNum == 0 -> %%原来背包里是否有资质符(直接消费元宝)
		   1;
	   true ->
		   case gen_server:call(Status#player.other#player_other.pid_goods,{'delete_more',GrowType,1}) of 
			   1 ->
				   1;
			  Code ->
				  Code
		   end
	end,
	 Safe =
		if   PType > 0 ->
				 case gen_server:call(Status#player.other#player_other.pid_goods,{'delete_more',PType,1}) of
					 1 ->
						 1;
					 _ERR_CODE ->
						 0
				 end;
			 true ->
				 0
		end,
	{LuckyRes,RpAdd} = 
				if Lucky > 0->
					   case catch gen_server:call(Status#player.other#player_other.pid_goods,{'delete_more',24403,Lucky}) of 
						1 ->
							{ok,Lucky*3};
						_ ->
							{error,0}
					end;
				   true->{ok,0}
				end,
	case LuckyRes of
		error->{fail,8};
		ok->
			if Result == 1 ->
				   Rand = util:rand(1,10000),
				   [Ratio,Save] = Rule,
				   BaseGrowUp = data_pet:base_grow_up(),
				   {Res,Grow} =
					if
						%%成功
						(Ratio+RpAdd) * 100 > Rand ->
							if PetInfo#ets_pet.chenge == 2 andalso PetInfo#ets_pet.grow +BaseGrowUp > 80 -> %%第二次化形
								   log_up_grow(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.grow,80,Safe,Ratio,Rand),
								   {1,80};									  
							   true ->
								   if
									   PetInfo#ets_pet.chenge == 2 ->
										   log_up_grow(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.grow,PetInfo#ets_pet.grow + BaseGrowUp,Safe,Ratio,Rand),
										   {1,PetInfo#ets_pet.grow + BaseGrowUp};
									   true ->
										   if 
											   PetInfo#ets_pet.grow +BaseGrowUp > 60 ->
												   log_up_grow(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.grow,60,Safe,Ratio,Rand),
												   {1,60};
											   true ->
												   log_up_grow(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.grow,PetInfo#ets_pet.grow + BaseGrowUp,Safe,Ratio,Rand),
												   {1,PetInfo#ets_pet.grow + BaseGrowUp}
										   end
								   end
							end;
						%%失败
						true ->
							case Safe of
								1 ->
									log_up_grow(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.grow,PetInfo#ets_pet.grow,Safe,Ratio,Rand),
									{0,PetInfo#ets_pet.grow};
								0 ->
									log_up_grow(Status#player.id,PetInfo#ets_pet.id,PetInfo#ets_pet.grow,Save,Safe,Ratio,Rand),
									{0,Save}
							end
					end,
					PetNew = PetInfo#ets_pet{grow = Grow},
				    [AddPoint,PrevGrow] = data_pet:get_add_extra_point(PetNew#ets_pet.grow,PetNew#ets_pet.apt_range),
				    if AddPoint > 0 ->
						   PetNew1 = PetNew#ets_pet{point=PetNew#ets_pet.point+AddPoint,apt_range=PrevGrow};
					   true ->
						   PetNew1 = PetNew
					end,
					ets:insert(ets_pet,PetNew1),
					save_pet(PetNew1),
				   %%扣元宝
				   if GrowNum == 0 ->%%直接扣元宝
						  spawn(fun() ->log:log_shop([1,1,Status#player.id,Status#player.nickname,GrowType,gold,GrowCost,1]) end),
						  NewStatus1 = lib_goods:cost_money(Status,GrowCost,gold,4108);
					  true ->
						  NewStatus1 = Status
				   end,
				   %%返回值
				   {ok,NewStatus1,PetNew1,Res,PetInfo#ets_pet.grow}
			end;
	   true ->
		   {fail,Result}
	end.

%%灵兽成长值提升日志
log_up_grow(PlayerId,PetId,OldGrow,NewGrow,Safe,Ratio,Rand)->
	spawn(fun()->catch(db_agent:upgrade_grow_log([PlayerId,PetId,OldGrow,NewGrow,Safe,Ratio* 100,Rand,util:unixtime()]))end).

%%灵兽升级日志
log_pet_uplv(PlayerId,PetId,Lv,Exp,Apt,Grow,Point,Timestamp)->
	if Lv >= 15->
		spawn(fun()->catch (db_agent:log_pet_uplv(PlayerId,PetId,Lv,Exp,Apt,Grow,Point,Timestamp)) end);
	   true->skip
	end.

%%获取灵兽初始成长值
get_pet_base_grow(Type)->
	case Type of
		new->
			Rp = util:rand(1,10000),
			[Min,Max]=data_pet:base_grow(Rp),
			util:rand(Min,Max);
		base->20
	end.

%% ----------------------------------------------------------------
%% 灵兽快乐值和经验值改变
%% ----------------------------------------------------------------
upgrade_pet(PidSend,Pet,MaxLevel,Now,Mult) ->
	Decrease = data_pet:get_decrease_happy(Pet#ets_pet.level),
	NewHappy = 
		if
			Pet#ets_pet.happy - Decrease =< 0 -> 
				0;
			true ->
				Pet#ets_pet.happy - Decrease
		end,
	NextLevelExp = data_pet:get_upgrade_exp(Pet#ets_pet.level),
	ExpAdd = round(60 * Mult),
	[NewExp,NewLevel] =
		if
			%%满级
			Pet#ets_pet.level >= 60 ->
				[Pet#ets_pet.exp,60];
			%%不大于角色等级
			(Pet#ets_pet.level =:= MaxLevel) andalso (Pet#ets_pet.exp + 60 > NextLevelExp) ->
				[NextLevelExp,Pet#ets_pet.level];
			true ->
				if
					Pet#ets_pet.exp + ExpAdd > NextLevelExp   ->
						if
							Pet#ets_pet.level =< 14 ->
								[Pet#ets_pet.exp + ExpAdd - NextLevelExp,Pet#ets_pet.level + 1];
							true ->
								[NextLevelExp,Pet#ets_pet.level]
						end;				
					Pet#ets_pet.exp + ExpAdd =:= NextLevelExp  ->
						if
							Pet#ets_pet.level =< 14 ->
								[0,Pet#ets_pet.level + 1];
							true ->
								[NextLevelExp,Pet#ets_pet.level]
						end;
					true  ->
						[Pet#ets_pet.exp + ExpAdd,Pet#ets_pet.level]				
				end
		end,
	if
		%%被角色等级卡住的不更新
		(Pet#ets_pet.exp =:= NewExp) andalso (Pet#ets_pet.level =:= NewLevel) ->
			PetNew = Pet#ets_pet{happy = NewHappy,time = Now},
			ets:insert(ets_pet,PetNew);
		true ->
			P = Pet#ets_pet.point,
			if
				Pet#ets_pet.level =/= NewLevel ->
					log_pet_uplv(Pet#ets_pet.player_id,Pet#ets_pet.id,NewLevel,NewExp,Pet#ets_pet.aptitude,Pet#ets_pet.grow,Pet#ets_pet.point,Now),
					Point = P + data_pet:grow_to_point(Pet#ets_pet.grow);
				true ->
					Point = P
			end,
			PetNew = Pet#ets_pet{happy = NewHappy,exp = NewExp, level = NewLevel ,time = Now,point = Point},
			%%即时更新ets
			ets:insert(ets_pet,PetNew),
			if %%灵兽等级成就判断
				PetNew#ets_pet.level >= 25 ->
					lib_achieve:check_achieve_finish(PidSend, PetNew#ets_pet.player_id, 514, [PetNew#ets_pet.level]);
				PetNew#ets_pet.level >= 10 ->
					lib_achieve:check_achieve_finish(PidSend, PetNew#ets_pet.player_id, 513, [PetNew#ets_pet.level]);
				PetNew#ets_pet.level >= 5 ->
					lib_achieve:check_achieve_finish(PidSend, PetNew#ets_pet.player_id, 512, [PetNew#ets_pet.level]);
				true ->
					skip
			end,
			%%5分钟更新一次数据库
			CheckTime =util:floor(util:unixtime()/60),
			if
				CheckTime rem 5 =:= 0 ->
					save_pet(PetNew);
				true ->
					skip
			end
	end,
	PetNew.

%% ----------------------------------------------------------------
%% 通过灵兽秘笈升级灵兽
%% ----------------------------------------------------------------
%选定灵兽触发
upgrade_by_using(Status,Pet,Goods_id) ->
	case gen_server:call(Status#player.other#player_other.pid_goods, {'delete_more',Goods_id, 1}) of
		1 ->
			%%成功删除物品
			upgrade_by_using(Pet);
		_Code ->
			{fail,5}
	end.

%使用物品触发
upgrade_by_using(Pet) ->
	CurLevel = Pet#ets_pet.level,
	if
		CurLevel >=15 andalso CurLevel =< 59  ->
			Point = Pet#ets_pet.point+data_pet:grow_to_point(Pet#ets_pet.grow),
			PetNew = Pet#ets_pet{exp =0, level = CurLevel +1,point=Point};
		true ->
			PetNew = Pet
	end,
	ets:insert(ets_pet,PetNew),
	save_pet(PetNew),
	{ok,PetNew}.

%%背包使用物品调用
upgrade_by_using_only(PlayerStatus,Pet) ->
	CurLevel = Pet#ets_pet.level,
	if
		CurLevel >=15 andalso CurLevel =< 59  ->
			Point = Pet#ets_pet.point+data_pet:grow_to_point(Pet#ets_pet.grow),
			PetNew = Pet#ets_pet{exp =0, level = CurLevel +1,point=Point};
		true ->
			PetNew = Pet
	end,
	ets:insert(ets_pet,PetNew),
	save_pet(PetNew),
	%%升级广播通知
	MaxExp = data_pet:get_upgrade_exp(PetNew#ets_pet.level),
	{ok,BinData} = pt_41:write(41011,[1,PetNew#ets_pet.id,PetNew#ets_pet.level,PetNew#ets_pet.happy,PetNew#ets_pet.exp,MaxExp,PetNew#ets_pet.point]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,PetNew}.

%% -----------------------------------------------------------------
%% 灵兽学习技能(物品使用触发)
%% -----------------------------------------------------------------
learn_skill(PlayerStatus,SkillId) ->
	Now = util:unixtime(),
	SkillExp = data_pet:get_pet_skill_exp(1,4),
	NewSkill = util:term_to_string([SkillId, 1, 4, SkillExp]),
	NewSplitSkill = tool:to_binary(NewSkill),
	Id = db_agent:save_pet_split_skill(PlayerStatus#player.id,0,NewSplitSkill,Now),
	PetSplitSkillInfo = #ets_pet_split_skill{id=Id,player_id=PlayerStatus#player.id,pet_id=0,pet_skill=NewSplitSkill,ct=Now},
	update_pet_split_skill(PetSplitSkillInfo),
	spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(PlayerStatus#player.id,0, <<>>, NewSplitSkill, 6, Now)) end).
	

%% -----------------------------------------------------------------
%% 灵兽遗忘技能
%% -----------------------------------------------------------------
forget_skill(PlayerStatus,Pet,Skill)->
	PetNew =
		case Skill of
		skill_1 ->Pet#ets_pet{skill_1 = 0};
		skill_2 ->Pet#ets_pet{skill_2 = 0};
		skill_3 ->Pet#ets_pet{skill_3 = 0};
		skill_4 ->Pet#ets_pet{skill_4 = 0};
		skill_5 ->Pet#ets_pet{skill_5 = 0};
		skill_6 ->Pet#ets_pet{skill_6 = 0};
		_->Pet
	end,
	update_pet(PetNew),
	db_agent:pet_forget_skill(Pet#ets_pet.id,Skill),
	pp_pet:handle(41008, PlayerStatus, [PlayerStatus#player.id]),
	PetNew.

get_skill_position(Position)->
	case Position of 
		1->{ok,skill_1};
		2->{ok,skill_2};
		3->{ok,skill_3};
		4->{ok,skill_4};
		5->{ok,skill_5}; 
		6->{ok,skill_6}; 
		_->{error,Position}
	end.
%% -----------------------------------------------------------------
%% 灵兽变身(物品使用触发)
%% -----------------------------------------------------------------
change_pet(PlayerStatus,Pet,GoodsInfo) ->
	_OtherData = goods_util:get_goods_other_data(GoodsInfo#goods.goods_id),
	_Ovalue = goods_util:parse_goods_other_data(_OtherData,value),
	case is_integer(_Ovalue) of
		false ->
			{ok,PlayerStatus};
		true ->
			To_petTypeInfo = goods_util:get_goods_type(_Ovalue),
			case is_record(To_petTypeInfo,ets_base_goods) of
				true ->
					if GoodsInfo#goods.goods_id == 24509 ->%%哪吒变身卡
						   if Pet#ets_pet.chenge > 2 -> 
								  BaseChenag = 1;
							  true -> 
								 BaseChenag = Pet#ets_pet.chenge
						   end,
						   NewGoodsId = _Ovalue+BaseChenag;
					   true ->
						   NewGoodsId = 
							   if Pet#ets_pet.chenge > 0 ->
									  Id = get_chenge_id(_Ovalue),
									  if Pet#ets_pet.chenge =:= 2->
											 Id1 = get_chenge_id(Id),
											 Id1;
										 true->Id
									  end;
								  true->_Ovalue
							   end
					end,
					PetNew = Pet#ets_pet{goods_id = NewGoodsId},
					ets:insert(ets_pet,PetNew),
					save_pet(PetNew),
					db_agent:change_pet(Pet#ets_pet.id,NewGoodsId),
					{ok,NewPlayerStatus} = pp_pet:handle(41004, PlayerStatus, [PetNew#ets_pet.id,1]),
					{ok,NewPlayerStatus};			
				false ->
					{ok,PlayerStatus}
			end
	end.

%% -----------------------------------------------------------------
%% 开始训练灵兽
%% -----------------------------------------------------------------
lib_train_start(Status,Pet,GoodsNum,MoneyType,Auto,TrainTime,TrainMoney)->
	case gen_server:call(Status#player.other#player_other.pid_goods,{'delete_more',24000,GoodsNum}) of
		1->
			case Pet#ets_pet.status=:=1 of
				true->
					RestPet = lib_pet:rest_pet(Pet),
					PetColor = data_pet:get_pet_color(Pet#ets_pet.aptitude),
					{ok,BinData1} = pt_12:write(12031,[RestPet#ets_pet.status,Status#player.id,RestPet#ets_pet.id,RestPet#ets_pet.name,PetColor,RestPet#ets_pet.goods_id,RestPet#ets_pet.grow,RestPet#ets_pet.aptitude]),
					mod_scene_agent:send_to_area_scene(Status#player.scene,Status#player.x, Status#player.y, BinData1),
					NewStatus = Status#player{other=Status#player.other#player_other{
								out_pet = lib_pet:get_out_pet(Status#player.id)}};
				false->
					RestPet=Pet,
					NewStatus=Status
			end,
			NowTime = util:unixtime(),
			db_agent:pet_train(Pet#ets_pet.id,2,GoodsNum,MoneyType,TrainMoney,Auto,NowTime,TrainTime+NowTime),
			NewPet = RestPet#ets_pet{status = 2,goods_num = GoodsNum,money_type = MoneyType,money_num = TrainMoney,auto_up=Auto,train_start=NowTime,train_end=TrainTime+NowTime},
			NewPlayerStatus = case MoneyType of
								   1->lib_goods:cost_money(NewStatus,TrainMoney,gold,4104);
								   _->lib_goods:cost_money(NewStatus,TrainMoney,coinonly,4104)
							   end,
			ets:insert(ets_pet,NewPet),
			log_train(Status#player.id,Pet#ets_pet.id,Pet#ets_pet.level,GoodsNum,MoneyType,TrainMoney,TrainTime,1),
			{ok,NewPlayerStatus,NewPet};
		_->{fail,5}
	end.

%% -----------------------------------------------------------------
%% 停止训练灵兽
%% -----------------------------------------------------------------
lib_train_stop(Status,Pet)->
	TimeRemain = Pet#ets_pet.train_end-util:unixtime(),
	Foods=data_pet:time_to_food(TimeRemain,Pet#ets_pet.level),
	case gen_server:call(Status#player.other#player_other.pid_goods, {'cell_num'}) < tool:ceil(Foods/99) of
		true->{fail,5};
		false->
			if Foods >0 ->
				   gen_server:call(Status#player.other#player_other.pid_goods, {'give_goods', Status,24000, Foods,2});
			   true->skip
			end,
			Money = data_pet:get_train_money(Pet#ets_pet.money_type,TimeRemain),
			NewStatus=case Pet#ets_pet.money_type of
				1->lib_goods:add_money(Status,Money,gold,4104);
				_->lib_goods:add_money(Status,Money,coinonly,4104)
			end,
			db_agent:pet_train(Pet#ets_pet.id,0,0,0,0,0,0,0),
			NewPet = Pet#ets_pet{status = 0,goods_num = 0,money_type = 0,money_num = 0,auto_up=0,train_start=0,train_end=0},
			ets:insert(ets_pet,NewPet),
			log_train(Status#player.id,Pet#ets_pet.id,Pet#ets_pet.level,Foods,Pet#ets_pet.money_type,Money,TimeRemain,2),
			 %%灵兽训练完成通知客户端
			{ok,BinData} = pt_41:write(41045,NewPet#ets_pet.id),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),		
			{ok,NewStatus,Pet,24000,Foods,Pet#ets_pet.money_type,Money}
	end.

%% -----------------------------------------------------------------
%% 完成训练灵兽
%% -----------------------------------------------------------------
lib_train_finish(Status,Pid_send,Pid_Goods,Pet)->
	if Pet#ets_pet.status=:=2->
		   NowTime = util:unixtime(),
		   if Pet#ets_pet.train_end > NowTime->
				  Exp = round(NowTime-Pet#ets_pet.train_start),
				  %%每5分钟增加灵兽技能5分钟15点
				  SkillExp = round((Exp/300)*15),
				  add_pet_skill_exp(Pet,SkillExp),
				  {ok,NewPet}= pet_train_exp(Status,Pid_send,Pid_Goods,Pet,Status#player.lv,Exp,Pet#ets_pet.auto_up),
				  db_agent:update_train_time(Pet#ets_pet.id,NowTime),
				  NewPet1 = NewPet#ets_pet{train_start=NowTime},
				  ets:insert(ets_pet,NewPet1),
				  {ok,NewPet1};
			  true->
				  Exp = round(Pet#ets_pet.train_end-Pet#ets_pet.train_start),
				  %%每5分钟增加灵兽技能5分钟15点
				  SkillExp = round((Exp/300)*15),
				  add_pet_skill_exp(Pet,SkillExp),
				  {ok,NewPet} = pet_train_exp(Status,Pid_send,Pid_Goods,Pet,Status#player.lv,Exp,Pet#ets_pet.auto_up),
				  db_agent:pet_train(Pet#ets_pet.id,0,0,0,0,0,0,0),
				  NewPet1 = NewPet#ets_pet{status = 0,goods_num = 0,money_type = 0,money_num = 0,auto_up=0,train_start=0,train_end=0},
				  ets:insert(ets_pet,NewPet1),
				   %%灵兽训练完成通知客户端
				  {ok,BinData} = pt_41:write(41045,NewPet1#ets_pet.id),
			      lib_send:send_to_sid(Pid_send,BinData),	
				  {ok,NewPet1}
			end;
	   true->{ok,Pet}
	end.

%% ----------------------------------------------------------------
%% 灵兽训练经验增长
%% ----------------------------------------------------------------
pet_train_exp(Status,Pid_send,Pid_Goods,Pet,MaxLevel,Exp,Auto)->
	PetNew = add_exp(Status,Pid_send,Pid_Goods,Pet,MaxLevel,Exp,Auto),
	NextLevelExp = data_pet:get_upgrade_exp(PetNew#ets_pet.level),
	if PetNew#ets_pet.exp > NextLevelExp->
		   pet_train_exp(Status,Pid_send,Pid_Goods,PetNew,MaxLevel,0,Auto);
	   true->{ok,PetNew}
	end.
	
add_exp(_Status,Pid_send,Pid_Goods,Pet,MaxLevel,Exp,Auto) ->
	NextLevelExp = data_pet:get_upgrade_exp(Pet#ets_pet.level),
	[NewExp,NewLevel] =
		if
			%%满级
			Pet#ets_pet.level >= 60 ->
				[Pet#ets_pet.exp,60];
			%%不大于角色等级
			(Pet#ets_pet.level =:= MaxLevel) andalso (Pet#ets_pet.exp + Exp > NextLevelExp) ->
				[NextLevelExp,Pet#ets_pet.level];
			true ->
				if
					Pet#ets_pet.exp + Exp > NextLevelExp   ->
						if
							Pet#ets_pet.level =< 14 ->
								[Pet#ets_pet.exp + Exp - NextLevelExp,Pet#ets_pet.level + 1];
							true ->
								if Auto=:= 0->
									[NextLevelExp,Pet#ets_pet.level];
								   true->
									   case catch(gen_server:call(Pid_Goods,{'delete_more',24100,1})) of
										   1->
									   			[Pet#ets_pet.exp + Exp - NextLevelExp,Pet#ets_pet.level + 1];
										   _->[NextLevelExp,Pet#ets_pet.level]
									   end
								end
						end;				
					Pet#ets_pet.exp + Exp =:= NextLevelExp  ->
						if
							Pet#ets_pet.level =< 14 andalso Auto=:= 0->
								[0,Pet#ets_pet.level + 1];
							true ->
								if Auto=:= 0->
									[NextLevelExp,Pet#ets_pet.level];
								   true->
									   case catch(gen_server:call(Pid_Goods,{'delete_more',24100,1})) of
										   1->
									   			[0,Pet#ets_pet.level + 1];
										   _->[NextLevelExp,Pet#ets_pet.level]
									   end
								end
						
						end;
					true  ->
						[Pet#ets_pet.exp + Exp,Pet#ets_pet.level]				
				end
		end,
	if
		%%被角色等级卡住的不更新
		(Pet#ets_pet.exp =:= NewExp) andalso (Pet#ets_pet.level =:= NewLevel) ->
			PetNew = Pet,
			ets:insert(ets_pet,PetNew);
		true ->
			P = Pet#ets_pet.point,
			if
				Pet#ets_pet.level =/= NewLevel ->
					log_pet_uplv(Pet#ets_pet.player_id,Pet#ets_pet.id,NewLevel,NewExp,
								 Pet#ets_pet.aptitude,Pet#ets_pet.grow,Pet#ets_pet.point,util:unixtime()),
					Point = P + data_pet:grow_to_point(Pet#ets_pet.grow);
				true ->
					Point = P
			end,
			PetNew = Pet#ets_pet{exp = NewExp, level = NewLevel ,point = Point},
			%%即时更新ets
			ets:insert(ets_pet,PetNew),
			if %%灵兽等级成就判断
				PetNew#ets_pet.level >= 25 ->
					lib_achieve:check_achieve_finish(Pid_send,PetNew#ets_pet.player_id, 514, [PetNew#ets_pet.level]);
				PetNew#ets_pet.level >= 10 ->
					lib_achieve:check_achieve_finish(Pid_send,PetNew#ets_pet.player_id, 513, [PetNew#ets_pet.level]);
				PetNew#ets_pet.level >= 5 ->
					lib_achieve:check_achieve_finish(Pid_send,PetNew#ets_pet.player_id, 512, [PetNew#ets_pet.level]);
				true ->
					skip
			end,
			save_pet(PetNew)
	end,
	PetNew.

%%灵兽成长值提升日志
log_train(PlayerId,PetId,Lv,Foods,Mt,M,TrainTime,Opt)->
	spawn(fun()->catch(db_agent:train_pet_log([PlayerId,PetId,Lv,Foods,Mt,M,TrainTime,Opt,util:unixtime()]))end).

%% -----------------------------------------------------------------
%% 获取灵兽信息
%% -----------------------------------------------------------------
get_pet_info(PetId) ->
    get_pet(PetId).
  
        
%% -----------------------------------------------------------------
%% 获取灵兽列表
%% -----------------------------------------------------------------
get_pet_list(PlayerId) ->
    get_all_pet(PlayerId).

%%查询自己资质或成长最高的灵兽(type 3返回[资质，成长]，1返回[资质,0]，2返回[成长,0])
get_pet_max_apt_grow(PlayerId,Type) ->
	PetList = get_pet_list(PlayerId),
	if PetList == [] ->
		   [0,0];
	   true ->
			if Type == 1 ->
				  ResultList1 = lists:sort(fun(Pet1,Pet2) -> Pet1#ets_pet.aptitude >=  Pet2#ets_pet.aptitude end,  PetList),
				  [H | _] = ResultList1,
				  [H#ets_pet.aptitude,0];
			  Type == 2 ->
				  ResultList2 = lists:sort(fun(Pet1,Pet2) -> Pet1#ets_pet.grow >=  Pet2#ets_pet.grow end,  PetList),
				  [H | _] = ResultList2,
				  [H#ets_pet.grow,0];
			  true ->
				   ResultList1 = lists:sort(fun(Pet1,Pet2) -> Pet1#ets_pet.aptitude >=  Pet2#ets_pet.aptitude end,  PetList),
				   ResultList2 = lists:sort(fun(Pet1,Pet2) -> Pet1#ets_pet.grow >=  Pet2#ets_pet.grow end,  PetList),
				   [H1 | _] = ResultList1,
				   [H2 | _] = ResultList2,
				   [H1#ets_pet.aptitude,H2#ets_pet.grow]
		   end
	end.
			  
	   
	
	
	

%% -----------------------------------------------------------------
%% 获取灵兽对人物角色的属性加成 [力量，敏捷，智力，体质]
%% -----------------------------------------------------------------
get_out_pet_attribute(PlayerStatus) ->
	Outpet = get_out_pet(PlayerStatus#player.id),
	if
		is_record(Outpet,ets_pet) andalso Outpet#ets_pet.happy > 0 ->
			get_pet_attribute(Outpet);
		true ->
			[0,0,0,0]
	end.
get_pet_attribute(Pet) ->
	Pet_forza = Pet#ets_pet.forza * Pet#ets_pet.aptitude / 50 ,
	Pet_agile = Pet#ets_pet.agile * Pet#ets_pet.aptitude / 50 ,
	Pet_wit = Pet#ets_pet.wit * Pet#ets_pet.aptitude / 50 ,
	Pet_physique = Pet#ets_pet.physique * Pet#ets_pet.aptitude / 50 ,
	[Pet_forza,Pet_agile,Pet_wit,Pet_physique].

%% -----------------------------------------------------------------
%% 获取灵兽的技能属性加成系数  [气血，法力，防御，攻击，抗性，命中，闪躲，打坐回血，打坐回蓝] 
%% -----------------------------------------------------------------
get_out_pet_skill_effect(PlayerStatus) ->
	Outpet = get_out_pet(PlayerStatus#player.id),
	if
		is_record(Outpet,ets_pet) andalso Outpet#ets_pet.happy > 0->
			get_pet_skill_effect(Outpet); 
		true ->
			[[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0]]
	end.

get_pet_skill_effect(Pet) ->
	F = fun(PetSkill,Effect) ->
				[SkillId, SkillLevel, SkillStep, _SkillExp] = util:string_to_term(tool:to_list(PetSkill)),
				[[Hp,HpFix],[Mp,MpFix],[Def,DefFix],[Att,AttFix],[Anti,AntiFix],[Hit,HitFix],[Dodge,DodgeFix],[R_hp,R_hpFix],[R_mp,R_mpFix]] = Effect,
				[[Hp2,Hp2Fix],[Mp2,Mp2Fix],[Def2,Def2Fix],[Att2,Att2Fix],[Anti2,Anti2Fix],[Hit2,Hit2Fix],[Dodge2,Dodge2Fix],[R_hp2,R_hp2Fix],[R_mp2,R_mp2Fix]]=
					data_pet:get_pet_skill_effect(SkillId, SkillLevel, SkillStep),
				[[Hp+Hp2,HpFix+Hp2Fix],[Mp+Mp2,MpFix+Mp2Fix],[Def+Def2,DefFix+Def2Fix],[Att+Att2,AttFix+Att2Fix],[Anti+Anti2,AntiFix+Anti2Fix],[Hit+Hit2,HitFix+Hit2Fix],[Dodge+Dodge2,DodgeFix+Dodge2Fix],[R_hp+R_hp2,R_hpFix+R_hp2Fix],[R_mp+R_mp2,R_mpFix+R_mp2Fix]]
		end,
	SkillList = [Pet#ets_pet.skill_1,Pet#ets_pet.skill_2,Pet#ets_pet.skill_3,Pet#ets_pet.skill_4, Pet#ets_pet.skill_5,Pet#ets_pet.skill_6],
	[[PetMult_hp1,PetMult_hpFix1],[PetMult_mp1,PetMult_mpFix1],[PetMult_def1,PetMult_defFix1],[PetMult_att1,PetMult_attFix1],[PetMult_anti1,PetMult_antiFix1],[PetMult_hit1,PetMult_hitFix1],[PetMult_dodge1,PetMult_dodgeFix1],[_PetMult_r_hp1,_PetMult_r_hpFix1],[_PetMult_r_mp1,_PetMult_r_mpFix1]] = 
			lists:foldl(F, [[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0]], SkillList),
	[Att,Hp,Def] = data_pet:get_extra_attribute(Pet#ets_pet.aptitude),
	[[PetMult_hp1,PetMult_hpFix1+Hp],[PetMult_mp1,PetMult_mpFix1],[PetMult_def1,PetMult_defFix1+Def],[PetMult_att1,PetMult_attFix1+Att],[PetMult_anti1,PetMult_antiFix1],[PetMult_hit1,PetMult_hitFix1],[PetMult_dodge1,PetMult_dodgeFix1],[_PetMult_r_hp1,_PetMult_r_hpFix1],[_PetMult_r_mp1,_PetMult_r_mpFix1]].

get_out_pet_batt_skill(PlayerId) -> 
	Outpet = get_out_pet(PlayerId),
	if
		is_record(Outpet,ets_pet) andalso Outpet#ets_pet.happy > 0->
			Batt_skill1 = util:string_to_term(tool:to_list(Outpet#ets_pet.batt_skill)),
			if Batt_skill1 == undefined ->
				   Batt_skill = [];
			   true ->
				   F = fun(SkillId) ->
							   Ets_pet_skill = data_pet_skill:get(SkillId),
							   if is_record(Ets_pet_skill,ets_pet_skill) ->
									  [{Ets_pet_skill#ets_pet_skill.type,SkillId,trunc(Ets_pet_skill#ets_pet_skill.rate*100)}];
								  true ->
									  []
							   end
					   end,
				   Batt_skillList = [F(SkillId) ||SkillId <- Batt_skill1],
				   Batt_skill = [Elem ||Elem <- Batt_skillList,Elem =/= []]							   
			end,
			lists:flatten(Batt_skill); 
		true ->
			[]
	end.

%% -----------------------------------------------------------------
%% 角色死亡扣减
%% -----------------------------------------------------------------
handle_role_dead(Status) ->
    OutPet  = lib_pet:get_out_pet(Status#player.id),
    if  length(OutPet) > 0 ->
            {ok, Bin} = pt_41:write(41000, [0]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin);
        true ->
            void
    end.



%% -----------------------------------------------------------------
%% 删除角色
%% -----------------------------------------------------------------
delete_role(PlayerId) ->
    % 删除灵兽表记录
    db_agent:lp_delete_role(PlayerId),
    % 删除缓存
    delete_all_pet(PlayerId),
    ok.

%% -----------------------------------------------------------------
%% 判断灵兽是否可以化形
%% add by zkj
%% -----------------------------------------------------------------
judge_pet_chenge(PlayerStatus,[PetId]) ->
	Pet = get_pet(PlayerStatus#player.id,PetId),
	if  
		Pet =:= []  -> %%灵兽不存在  
			{fail,2};
		true ->
			if  
				Pet#ets_pet.player_id =/= PlayerStatus#player.id -> %%该灵兽不归你所有 
					{fail,3};
				Pet#ets_pet.goods_id==24616->
					{fail,11};
				true->
					Chenge = Pet#ets_pet.chenge,
					%%第一次化形条件
					if Chenge == 0 ->
						   if 
							   Pet#ets_pet.level < 25 -> %%灵兽等级小于25级
								   {fail,4};
							   Pet#ets_pet.aptitude < 55 -> %%灵兽资质小于55
								   {fail,5};
							   Pet#ets_pet.chenge =/= 0 -> %%灵兽已化形
								   {fail,6};
							   true ->
								   {ok,Pet}
						   end;
					   Chenge >= 1 andalso  Chenge =/= 2->%%灵兽已第一次化形	
						   if
							   Pet#ets_pet.aptitude < 80 -> %%灵兽资质小于80
								   {fail,9};
							   Pet#ets_pet.grow < 60 -> %%成长小于60
								   {fail,10};
							   true ->
								   {ok,Pet}
						   end;
					    Chenge == 2 ->%%灵兽已化形
							{fail,6};
					   true ->
						   {fail,0}
					end
			end
	end.

%%判断背包里是否有化形果实
judge_chenge_fruit(PlayerStatus) ->
	%%到内存表查找
	MS = ets:fun2ms(fun(T) when T#goods.player_id == PlayerStatus#player.id andalso T#goods.goods_id == ?CHENGE_FRUIT_ID andalso T#goods.location == 4 ->
			T
	end),
	Chenge_fruit_list = ets:select(?ETS_GOODS_ONLINE,MS),
	case length(Chenge_fruit_list) > 0 of
		true ->
			1; %%有化形果实
		_ ->
			2  %%无化形果实
	end.

%% -----------------------------------------------------------------
%% 灵兽化形
%% add by zkj
%% -----------------------------------------------------------------
pet_chenge(PlayerStatus,[PetId]) ->
	case ( judge_pet_chenge(PlayerStatus,[PetId])) of
		{ok,Pet} -> %%可以进行化形
			%%删除一个化形果实
			case gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', ?CHENGE_FRUIT_ID, 1}) of
				1->
					GoodsBuffs = lib_goods:get_player_goodsbuffs(),
					chenge(PlayerStatus,Pet,GoodsBuffs);
				_->
					{fail,7}
			end;
		{fail,Error} -> %%不可以进行化形
			{fail,Error};
		_Error-> %%异常
			{fail,0}
	end.

chenge(PlayerStatus,Pet,GoodsBuffs)->
	NowTime = util:unixtime(),
	if Pet#ets_pet.goods_id == 24616 ->
		   case lists:keyfind(31218, 1, GoodsBuffs) of
			   false ->
				   NewGoodsBuffs = {no_update, GoodsBuffs},
				   NewGoodsId = get_chenge_id(Pet#ets_pet.goods_id);
			   {_EGoodsId, EValue, _ETime} ->
				   {_BuffId,{_LastTime,OldGoodsId}} =  EValue,
				   GoodsBuffs1 = lib_goods_use:filter_buff(PlayerStatus,GoodsBuffs,[31218]),
				   NewGoodsBuffs = {update, true, GoodsBuffs1},
				   NewGoodsId = get_chenge_id(OldGoodsId)
		   end;
	   true ->
		    NewGoodsBuffs = {no_update, GoodsBuffs},
			NewGoodsId = get_chenge_id(Pet#ets_pet.goods_id)
	end,
	if 
	   Pet#ets_pet.chenge >= 1 ->
		   Chenge = 2;
	   true ->
		   Chenge = 1
	end,
	PetNew = Pet#ets_pet{goods_id = NewGoodsId, chenge = Chenge },
	lib_achieve:check_achieve_finish(PlayerStatus#player.other#player_other.pid_send, PetNew#ets_pet.player_id, 520, [1]),
    lib_pet:update_pet(PetNew),
	%%修改数据库
	db_agent:pet_chenge(Pet#ets_pet.id,NewGoodsId,Chenge),
	spawn(fun()->db_agent:log_pet_chenge(PlayerStatus#player.id,Pet#ets_pet.id,Pet#ets_pet.goods_id,NewGoodsId,NowTime)end),
	%返回
	{ok,NewPlayerStatus} = pp_pet:handle(41004, PlayerStatus, [PetNew#ets_pet.id,1]),
	{ok,NewPlayerStatus,NewGoodsBuffs}.

%% -----------------------------------------------------------------
%% 得到资源ID
%% add by zkj
%% -----------------------------------------------------------------
get_chenge_id(Goods_id) ->
	_OtherData = goods_util:get_goods_other_data(Goods_id),
	_Ovalue = goods_util:parse_goods_other_data(_OtherData,chenge),
	_Ovalue.

%% -----------------------------------------------------------------
%% 购买化形果实
%% add by zkj
%% -----------------------------------------------------------------
buy_chenge_fruit(Status) ->
	%%判断是否够钱
	Coin_status = goods_util:is_enough_money(Status, (goods_util:get_goods(?CHENGE_FRUIT_ID))#goods.price, (goods_util:get_goods(?CHENGE_FRUIT_ID))#goods.price_type),
	if
		Coin_status =:= false ->
			%%钱不够，无法购买
			{fail,Status, 2};
		true ->
			%%扣钱
			NewStatus = lib_goods:cost_money(Status, (goods_util:get_goods(?CHENGE_FRUIT_ID))#goods.price, (goods_util:get_goods(?CHENGE_FRUIT_ID))#goods.price_type, 4201),
			%%将东西放入背包
			lib_goods:give_plant_goods({?CHENGE_FRUIT_ID, 1}, Status#player.id),
			%%返回状态
			{ok, NewStatus, 1}
	end.

%% -----------------------------------------------------------------
%% 灵兽融合
%% add by zkj
%% -----------------------------------------------------------------
pet_merge(PlayerStatus,[PetId1, PetId2]) ->
	if
		PetId1 =:= PetId2 ->
			{fail,[6, 0]};
		true ->
			Pet1 = lib_pet:get_pet(PlayerStatus#player.id,PetId1),
			Pet2 = lib_pet:get_pet(PlayerStatus#player.id,PetId2),
			H_AP_Pet = Pet1,
			H_CL_Pet = Pet2,
			%%检查两个灵兽是否符合融合条件
			case pet_merge_check(PlayerStatus, H_AP_Pet, 2, 1) of 
				{ok, _ } -> %% 高资质灵兽可以融合
					case pet_merge_check(PlayerStatus, H_CL_Pet, 2, 2) of
						{ok, _ } -> %% 高等级灵兽可以融合
							if
								H_AP_Pet#ets_pet.aptitude ==  H_CL_Pet#ets_pet.aptitude ->
									NewAptitude1 = H_AP_Pet#ets_pet.aptitude + 1;
								true ->
									NewAptitude1 = lists:max([H_AP_Pet#ets_pet.aptitude, H_CL_Pet#ets_pet.aptitude])
							end,
							Apt_range1 = H_AP_Pet#ets_pet.apt_range,
							Apt_range2 = H_CL_Pet#ets_pet.apt_range,
							if
								Apt_range1 >= Apt_range2 ->
									Apt_range = Apt_range1;
								true ->
									Apt_range = Apt_range2
							end,
							if
								NewAptitude1 >= 100 ->
									NewAptitude = 100;
								true ->
									NewAptitude = NewAptitude1
							end,
							if 
								H_AP_Pet#ets_pet.level > H_CL_Pet#ets_pet.level ->
						  			Level = H_AP_Pet#ets_pet.level;
					  			true->
									Level = H_CL_Pet#ets_pet.level
					  		end,
							if
								H_AP_Pet#ets_pet.grow > H_CL_Pet#ets_pet.grow ->
									Grow = H_AP_Pet#ets_pet.grow;
								true ->
									Grow = H_CL_Pet#ets_pet.grow
							end,
							%%有第二次化形
							if H_CL_Pet#ets_pet.chenge =< 0->
								   NewGoodsId = H_AP_Pet#ets_pet.goods_id,
								   NewChenge= H_AP_Pet#ets_pet.chenge;
							   H_CL_Pet#ets_pet.chenge =:= 2->
								   NewChenge = H_CL_Pet#ets_pet.chenge,
								   NewGoodsId = 
									   if H_AP_Pet#ets_pet.chenge =:= 2->
											  H_AP_Pet#ets_pet.goods_id;
										  H_AP_Pet#ets_pet.chenge =< 0->
											  Chenge1 = get_chenge_id(H_AP_Pet#ets_pet.goods_id),
											  get_chenge_id(Chenge1);
										  true->
											  get_chenge_id(H_AP_Pet#ets_pet.goods_id)
									   end;
							   true->
								   {NewGoodsId,NewChenge} = 
									   if H_AP_Pet#ets_pet.chenge =:= 2->
											  {H_AP_Pet#ets_pet.goods_id,H_AP_Pet#ets_pet.chenge};
										  H_AP_Pet#ets_pet.chenge =< 0->
											  {get_chenge_id(H_AP_Pet#ets_pet.goods_id),H_CL_Pet#ets_pet.chenge};
										  true->
											  {H_AP_Pet#ets_pet.goods_id,H_AP_Pet#ets_pet.chenge}
									   end
							end,
							if 
								Pet1#ets_pet.level >= Pet2#ets_pet.level ->
									Point = H_AP_Pet#ets_pet.point,
									Forza = H_AP_Pet#ets_pet.forza,
									Wit = H_AP_Pet#ets_pet.wit,
									Agile = H_AP_Pet#ets_pet.agile,
									Physique = H_AP_Pet#ets_pet.physique;
								true ->
									Point = H_CL_Pet#ets_pet.point,
									Forza = H_CL_Pet#ets_pet.forza,
									Wit = H_CL_Pet#ets_pet.wit,
									Agile = H_CL_Pet#ets_pet.agile,
									Physique = H_CL_Pet#ets_pet.physique
							end,		
							%%返回值
							Ret = {ok,[1, H_AP_Pet#ets_pet.id]},
							Exp1 = H_AP_Pet#ets_pet.exp,
							Exp2 = H_CL_Pet#ets_pet.exp,
							Happy1 = H_AP_Pet#ets_pet.happy,
							Happy2 = H_CL_Pet#ets_pet.happy,
							if Pet1#ets_pet.level >= Pet2#ets_pet.level ->
								  Exp = Exp1;
							   true ->
								  Exp = Exp2
							end,
							if Pet1#ets_pet.level >= Pet2#ets_pet.level ->
								   Happy = Happy1;
							   true ->
								  Happy = Happy2
							end,
							%%融合灵兽，内存表操作
							PetNew = H_AP_Pet#ets_pet{goods_id = NewGoodsId,
													  level = Level,
													  exp = Exp,
													  happy = Happy,
													  point = Point,
													  forza = Forza,
													  wit = Wit,
													  agile = Agile,
													  physique = Physique,
													  grow = Grow,
													  status = H_AP_Pet#ets_pet.status,
													  skill_1 = H_AP_Pet#ets_pet.skill_1,
													  skill_2 = H_AP_Pet#ets_pet.skill_2,
													  skill_3 = H_AP_Pet#ets_pet.skill_3,
													  skill_4 = H_AP_Pet#ets_pet.skill_4,
													  time = H_AP_Pet#ets_pet.time,
													  chenge = NewChenge,
													  skill_5 = H_AP_Pet#ets_pet.skill_5,
													  aptitude = NewAptitude,
													  skill_6 = H_AP_Pet#ets_pet.skill_6,
													  apt_range = Apt_range
													  },
							lib_pet:update_pet(PetNew),
							%%融合灵兽，数据库操作
							db_agent:pet_merge(H_AP_Pet#ets_pet.id,NewGoodsId, Level, Exp, Happy,
											  PetNew#ets_pet.point, PetNew#ets_pet.forza, PetNew#ets_pet.wit, PetNew#ets_pet.agile, PetNew#ets_pet.physique,
											  Grow,H_AP_Pet#ets_pet.status,H_AP_Pet#ets_pet.skill_1,H_AP_Pet#ets_pet.skill_2,H_AP_Pet#ets_pet.skill_3,
											   H_AP_Pet#ets_pet.skill_4,H_AP_Pet#ets_pet.time,NewChenge,H_AP_Pet#ets_pet.skill_5,NewAptitude,H_AP_Pet#ets_pet.skill_6,Apt_range),
							mod_pet:free_pet(PlayerStatus, [H_CL_Pet#ets_pet.id,1]),
							%%融合日志
							spawn(fun()->db_agent:log_pet_merge(PlayerStatus#player.id,H_AP_Pet#ets_pet.id,NewGoodsId,Level,Exp,Happy,
												   PetNew#ets_pet.point,NewChenge,PetNew#ets_pet.forza, PetNew#ets_pet.wit, PetNew#ets_pet.agile, PetNew#ets_pet.physique,
												   Grow,H_AP_Pet#ets_pet.aptitude,H_AP_Pet#ets_pet.skill_1,H_AP_Pet#ets_pet.skill_2,H_AP_Pet#ets_pet.skill_3,
											   H_AP_Pet#ets_pet.skill_4,H_AP_Pet#ets_pet.skill_5,NewAptitude,H_AP_Pet#ets_pet.skill_6,Apt_range,util:unixtime())end),
							
							Ret;
						{fail,Error} ->
						  {fail,[Error, 0]};
						_ ->
							{fail,[0, 0]}
					end;
				{fail,Error} ->
					{fail,[Error, 0]};
				_ ->
					{fail,[0, 0]}
			end
	end.

%% -----------------------------------------------------------------
%% 灵兽融合预览
%% add by zkj
%% -----------------------------------------------------------------
pet_merge_preview(PlayerStatus,[PetId1, PetId2]) ->
	if
		PetId1 =:= PetId2 ->
			{fail,[6, 0,0,0,<<>>,0, 0,0,0,0,0, 0,0,0,0,0, 0,0, [], 0,0,0,0,0]};
		true ->
			Pet1 = lib_pet:get_pet(PlayerStatus#player.id,PetId1),
			Pet2 = lib_pet:get_pet(PlayerStatus#player.id,PetId2),
			H_AP_Pet = Pet1,
			H_CL_Pet = Pet2,
			%%检查两个灵兽是否符合融合条件
			case pet_merge_check(PlayerStatus, H_AP_Pet, 1, 1) of 
				{ok, _ } -> %% 高资质灵兽可以融合
					case pet_merge_check(PlayerStatus, H_CL_Pet, 1, 2) of
						{ok, _ } -> %% 高等级灵兽可以融合
							if
								H_AP_Pet#ets_pet.aptitude ==  H_CL_Pet#ets_pet.aptitude ->
									NewAptitude = H_AP_Pet#ets_pet.aptitude + 1;
								true ->
									NewAptitude = lists:max([H_AP_Pet#ets_pet.aptitude, H_CL_Pet#ets_pet.aptitude])
							end,
							[R1,C]= data_pet:get_upgrade_aptitude(NewAptitude),
							{_NewPlayerStatus,_,VipAward} = lib_vip:get_vip_award(pet,PlayerStatus),
							R= round(R1 + VipAward*100),
							if 
								H_AP_Pet#ets_pet.level > H_CL_Pet#ets_pet.level ->
						  			Level = H_AP_Pet#ets_pet.level;
					  			true->
									Level = H_CL_Pet#ets_pet.level
					  		end,
							if
								H_AP_Pet#ets_pet.grow > H_CL_Pet#ets_pet.grow ->
									Grow = H_AP_Pet#ets_pet.grow;
								true ->
									Grow = H_CL_Pet#ets_pet.grow
							end,
							%%有第二次化形
							if H_CL_Pet#ets_pet.chenge =< 0->
								   NewGoodsId = H_AP_Pet#ets_pet.goods_id,
								   NewChenge= H_AP_Pet#ets_pet.chenge;
							   H_CL_Pet#ets_pet.chenge =:= 2->
								   NewChenge = H_CL_Pet#ets_pet.chenge,
								   NewGoodsId = 
									   if H_AP_Pet#ets_pet.chenge =:= 2->
											  H_AP_Pet#ets_pet.goods_id;
										  H_AP_Pet#ets_pet.chenge =< 0->
											  Chenge1 = get_chenge_id(H_AP_Pet#ets_pet.goods_id),
											  get_chenge_id(Chenge1);
										  true->
											  get_chenge_id(H_AP_Pet#ets_pet.goods_id)
									   end;
							   true->
								   {NewGoodsId,NewChenge} = 
									   if H_AP_Pet#ets_pet.chenge =:= 2->
											  {H_AP_Pet#ets_pet.goods_id,H_AP_Pet#ets_pet.chenge};
										  H_AP_Pet#ets_pet.chenge =< 0->
											  {get_chenge_id(H_AP_Pet#ets_pet.goods_id),H_CL_Pet#ets_pet.chenge};
										  true->
											  {H_AP_Pet#ets_pet.goods_id,H_AP_Pet#ets_pet.chenge}
									   end
							end,
							if 
								Pet1#ets_pet.level >= Pet2#ets_pet.level ->
									Point = H_AP_Pet#ets_pet.point,
									Forza = H_AP_Pet#ets_pet.forza,
									Wit = H_AP_Pet#ets_pet.wit,
									Agile = H_AP_Pet#ets_pet.agile,
									Physique = H_AP_Pet#ets_pet.physique;
								true ->
									Point = H_CL_Pet#ets_pet.point,
									Forza = H_CL_Pet#ets_pet.forza,
									Wit = H_CL_Pet#ets_pet.wit,
									Agile = H_CL_Pet#ets_pet.agile,
									Physique = H_CL_Pet#ets_pet.physique
							end,	
							Ret = {ok,[1, H_AP_Pet#ets_pet.id,H_AP_Pet#ets_pet.player_id,NewGoodsId,H_AP_Pet#ets_pet.name,H_AP_Pet#ets_pet.rename_count, 
								   Level,H_CL_Pet#ets_pet.exp,data_pet:get_upgrade_exp(Level),H_AP_Pet#ets_pet.happy,Point, 
								   Forza,Wit,Agile,Physique,NewAptitude, 
								   Grow,H_AP_Pet#ets_pet.status,H_AP_Pet,H_AP_Pet#ets_pet.time,R,C, H_AP_Pet#ets_pet.train_end,NewChenge]},
							Ret;
						{fail,Error} ->
						  {fail,[Error, 0,0,0,<<>>,0, 0,0,0,0,0, 0,0,0,0,0, 0,0, [], 0,0,0,0,0]};
						_ ->
							{fail,[0, 0,0,0,<<>>,0, 0,0,0,0,0, 0,0,0,0,0, 0,0, [], 0,0,0,0,0]}
					end;
				{fail,Error} ->
					{fail,[Error, 0,0,0,<<>>,0, 0,0,0,0,0, 0,0,0,0,0, 0,0, [], 0,0,0,0,0]};
				_ ->
					{fail,[0, 0,0,0,<<>>,0, 0,0,0,0,0, 0,0,0,0,0, 0,0, [], 0,0,0,0,0]}
			end
	end.

%%检查灵兽是否可以融合Type 1为预览，2为融合,Order为两个灵兽的顺序
pet_merge_check(Status, Pet, Type , Order) ->
	HasSkill = judge_pet_has_skill(Pet),
	if  
		Status#player.realm == 100 ->
			{fail,8}; %%新手不能融合灵兽
        Pet =:= []  -> %% 灵兽不存在 
			{fail,2};
		Type ==2 andalso Order == 2 andalso HasSkill == true ->
			{fail,7}; %%副灵兽有技能不能融合
        true ->         
            if  
                Pet#ets_pet.player_id =/= Status#player.id -> %% 该灵兽不归你所有  
					{fail,3};
                Pet#ets_pet.status =:= 1 -> %% 灵兽已经出战 
					{fail,4};
				Pet#ets_pet.status =:= 2 -> %% 灵兽训练中
					{fail,5};
				true ->
					{ok,1}
			end
	end.

%% -----------------------------------------------------------------
%% 获取某个玩家的灵兽信息
%% add by zkj
%% -----------------------------------------------------------------
get_player_pet_info([PetId]) ->
	PetList = db_agent:select_player_petid(PetId),
	if
		PetList =/= [] ->
			Pet = list_to_tuple([ets_pet] ++ lists:nth(1,PetList)),
			
			Goods_id = Pet#ets_pet.goods_id,
			Name = tool:to_binary(Pet#ets_pet.name),
			Level = Pet#ets_pet.level,
			Point = Pet#ets_pet.point,
			Forza = Pet#ets_pet.forza, 
			Wit = Pet#ets_pet.wit,
			Agile = Pet#ets_pet.agile,
			Physique = Pet#ets_pet.physique,
			Aptitude = Pet#ets_pet.aptitude,
			Grow = Pet#ets_pet.grow,
			Chenge = Pet#ets_pet.chenge,
			[1, Goods_id, Name, Level, Point, Forza, Wit, Agile, Physique, Aptitude, Grow, Pet, Chenge];			
		true ->
			[2, 0, <<>>, 0,0,0,0,0, 0,0,0,[],0] %%异常
	end.


%%灵兽技能分离
split_skill(Pet) ->
	save_pet_split_skill(Pet).

%%灵兽分离技能列表
get_all_split_skill(PlayerId) ->
	MS = ets:fun2ms(fun(T) when T#ets_pet_split_skill.player_id == PlayerId -> T end),
	ets:select(?ETS_PET_SPLIT_SKILL, MS).

%%查询角色的灵兽闲置技能
%%灵兽分离技能列表
find_split_skill(PlayerId,Skill) ->
	MS = ets:fun2ms(fun(T) when T#ets_pet_split_skill.player_id == PlayerId andalso T#ets_pet_split_skill.pet_skill == Skill -> T end),
	ets:select(?ETS_PET_SPLIT_SKILL, MS).

%%判断灵兽已有技能位置(全匹配)
find_pet_skill(Pet,Skill) ->
	Skill_1 = Pet#ets_pet.skill_1,
	Skill_2 = Pet#ets_pet.skill_2,
	Skill_3 = Pet#ets_pet.skill_3,
	Skill_4 = Pet#ets_pet.skill_4,
	Skill_5 = Pet#ets_pet.skill_5,
	Skill_6 = Pet#ets_pet.skill_6,
	if
		Skill_1 == Skill ->
			1;
		Skill_2 == Skill ->
			2;
		Skill_3 == Skill ->
			3;
		Skill_4 == Skill ->
			4;
		Skill_5 == Skill ->
			5;
		Skill_6 == Skill ->
			6;
		true ->
			0
	end.

%%判断灵兽还是否可以学习此种技能(结果为0表示可以学习)
find_pet_can_skill(Pet,Skill1,Skill2) ->
	 Skill_1 = Pet#ets_pet.skill_1,
	 Skill_2 = Pet#ets_pet.skill_2,
	 Skill_3 = Pet#ets_pet.skill_3,
	 Skill_4 = Pet#ets_pet.skill_4,
	 Skill_5 = Pet#ets_pet.skill_5,
	 Skill_6 = Pet#ets_pet.skill_6,
	 SkillList = [Skill_1,Skill_2,Skill_3,Skill_4,Skill_5,Skill_6],
	 if
		 Skill2 == <<>> ->
			 0;
		 true ->
			  [SkillId1, _SkillLevel1, SkillStep1, _SkillExp1] = util:string_to_term(tool:to_list(Skill1)),
			  [SkillId2, _SkillLevel2, SkillStep2, _SkillExp2] = util:string_to_term(tool:to_list(Skill2)),
			  if 
				  SkillId2 =/= SkillId1 ->
					  F = fun(Skill) ->
								  [SkillId6, _, _SkillStep6, _] = util:string_to_term(tool:to_list(Skill)),
								  if
									  SkillId1 == SkillId6 ->
										  if
											  SkillStep1 =< SkillStep2  ->
												  0;
											  true ->
												  1
										  end;
									  true ->
										  0
								  end
						  end,
					  ResultList = [F(Skill) || Skill <- SkillList],
					  lists:sum(ResultList);
				  %%相同则可以合并技能
				  true ->
					  0
			  end
	end.

%%判断灵兽还是否可以学习此种技能
find_pet_can_skill(Pet,Skill0) ->
	[SkillId0, _, _, _] = util:string_to_term(tool:to_list(Skill0)),
	Skill_1 = Pet#ets_pet.skill_1,
	Skill_2 = Pet#ets_pet.skill_2,
	Skill_3 = Pet#ets_pet.skill_3,
	Skill_4 = Pet#ets_pet.skill_4,
	Skill_5 = Pet#ets_pet.skill_5,
	Skill_6 = Pet#ets_pet.skill_6,
	SkillList = [Skill_1,Skill_2,Skill_3,Skill_4,Skill_5,Skill_6],
	F = fun(Skill) ->
				[SkillId1, _, _, _] = util:string_to_term(tool:to_list(Skill)),
				if 
					SkillId0 == SkillId1 ->
						1;
					true ->
						0
				end				
		end,
	ResultList = [F(Skill) || Skill <- SkillList],
	lists:sum(ResultList).

%%判断灵兽共学习多少种技能
sum_pet_can_skill(Pet) ->
	Skill_1 = Pet#ets_pet.skill_1,
	Skill_2 = Pet#ets_pet.skill_2,
	Skill_3 = Pet#ets_pet.skill_3,
	Skill_4 = Pet#ets_pet.skill_4,
	Skill_5 = Pet#ets_pet.skill_5,
	Skill_6 = Pet#ets_pet.skill_6,
	SkillList = [Skill_1,Skill_2,Skill_3,Skill_4,Skill_5,Skill_6],
	F = fun(Skill) ->
				[SkillId1, _, _, _] = util:string_to_term(tool:to_list(Skill)),
				if 
					SkillId1 > 0 ->
						1;
					true ->
						0
				end				
		end,
	ResultList = [F(Skill) || Skill <- SkillList],
	lists:sum(ResultList).

%%判断灵兽还可以学习多少种技能(共6种)
find_pet_can_skill(Pet) ->
	Skill_1 = Pet#ets_pet.skill_1,
	Skill_2 = Pet#ets_pet.skill_2,
	Skill_3 = Pet#ets_pet.skill_3,
	Skill_4 = Pet#ets_pet.skill_4,
	Skill_5 = Pet#ets_pet.skill_5,
	Skill_6 = Pet#ets_pet.skill_6,
	SkillList = [Skill_1,Skill_2,Skill_3,Skill_4,Skill_5,Skill_6],
	F = fun(Num,Skill) ->
				if 
					Skill == <<"[0,0,0,0]">> ->
						Num;
					true ->
						0
				end				
		end,
	ResultList = [F(Num,lists:nth(Num, SkillList)) || Num <- lists:seq(1, length(SkillList))],
	lists:filter(fun(N) -> N > 0 end, ResultList).
	

%%查找角色的

%%灵兽一键合成所有闲置技能
merge_all_split_skill(PlayerId) ->
	MaxLevel = lib_pet:get_max_pet_level(PlayerId),
	EtsSplitSkillList = get_all_split_skill(PlayerId),
	Now = util:unixtime(),
	if 
		EtsSplitSkillList == [] ->
		   2;%%没有可合成的闲置技能
		true ->
			F =fun(EtsSplitSkill) ->
					   Pet_skill = EtsSplitSkill#ets_pet_split_skill.pet_skill,
					   Id0 = EtsSplitSkill#ets_pet_split_skill.id,
					   Pet_id0 = EtsSplitSkill#ets_pet_split_skill.pet_id,
					   [SkillId0, SkillLevel0, SkillStep0, SkillExp0] = util:string_to_term(tool:to_list(Pet_skill)),
					   [Id0,Pet_id0,SkillId0, SkillLevel0, SkillStep0, SkillExp0]
			   end,
			ResultList = [F(EtsSplitSkill) || EtsSplitSkill <- EtsSplitSkillList],
			ResultList1 = lists:sort(fun([_Id1,_Pet_id1,_SkillId1, _SkillLevel1, SkillStep1, _SkillExp1],[_Id2,_Pet_id2,_SkillId2, _SkillLevel2, SkillStep2, _SkillExp2]) -> 
						   SkillStep1 >= SkillStep2
						end ,
				   ResultList),
			[H | RestList] = ResultList1,
			[Id, Pet_id,SkillId, SkillLevel, SkillStep, SkillExp] = H,
			AllSplitSkillExp = sum_splitskill_exp(RestList,0),
			%%合成后技能升级
			[NewLevel4,NewStep4,NewExp4] = update_skill_level(SkillLevel,SkillStep,SkillExp+AllSplitSkillExp),
			%%不能超过灵兽最高等级10级
			if  NewLevel4 > (MaxLevel + 10) ->
					3;
				true ->
					PetSplitSkillIdList = [Id3|| [Id3,_Pet_id3,_SkillId3, _SkillLevel3, _SkillStep3, _SkillExp3] <- RestList],
					%%删除内存中的所有闲置技能
					delete_all_pet_split_skill(PlayerId),
					%%删除数据库中指定id闲置技能
					delete_pet_split_skill(PetSplitSkillIdList),
					NewSkill = util:term_to_string([SkillId, NewLevel4, NewStep4, NewExp4]),
					F5 = fun([_Id5,_Pet_id5,SkillId5, SkillLevel5, SkillStep5, SkillExp5],Skill5) ->
								 NewSkill5 = util:term_to_string(tool:to_list([SkillId5, SkillLevel5, SkillStep5, SkillExp5])),
								 lists:concat([Skill5,NewSkill5])
						 end,
					BeforeSkill = lists:foldl(F5, [], ResultList1),
					spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(PlayerId,0, BeforeSkill, NewSkill, 2, Now)) end),
					PetSplitSkillInfo = #ets_pet_split_skill{id=Id,player_id=PlayerId,pet_id=Pet_id,pet_skill=tool:to_binary(NewSkill),ct=Now},
					update_pet_split_skill(PetSplitSkillInfo),
					db_agent:update_pet_split_skill(Id,tool:to_binary(NewSkill),Now),
					1
			end
	end.

%%灵兽购买面板(两天内的购买记录)
pet_buy_list(PlayerId) ->
	Now = util:unixtime(), 
	MS = ets:fun2ms(fun(T) when T#ets_pet_buy.player_id == PlayerId andalso T#ets_pet_buy.ct > Now-2*24*60*60 -> T end),
	EtsPetBuyList = ets:select(?ETS_PET_BUY, MS),
	[[EtsPetBuy#ets_pet_buy.goods_id,EtsPetBuy#ets_pet_buy.ct] || EtsPetBuy <- EtsPetBuyList].

%%刷新灵兽购买面板
flush_pet_buy_list(Player_Id) ->
	db_agent:delete_pet_buy(Player_Id),
	delete_all_pet_buy(Player_Id).

%%技能合成或升级,分离Oper (1为技能合并预览，2为正式技能合并)
drag_skill(PlayerId,PetId,Type,Oper,Skill1,Skill2) ->
	case Oper of
		2 -> %%正式技能合并
			drag_skill_normal(PlayerId,PetId,Type,Skill1,Skill2);
		_ -> %%技能合并预览
			drag_skill_preview(PlayerId,PetId,Type,Skill1,Skill2)
	end.

drag_skill_normal(PlayerId,PetId,Type,Skill1,Skill2) ->
	Now = util:unixtime(),
	if
		Type == 1 ->
			Pet = lib_pet:get_pet_info(PetId),
			%%计算灵兽已经技能
			Sum = sum_pet_can_skill(Pet),
			Aptitude = Pet#ets_pet.aptitude,
			Skill_1 = Pet#ets_pet.skill_1,
			Skill_2 = Pet#ets_pet.skill_2,
			Skill_3 = Pet#ets_pet.skill_3,
			Skill_4 = Pet#ets_pet.skill_4,
			Skill_5 = Pet#ets_pet.skill_5,
			Skill_6 = Pet#ets_pet.skill_6,
			%%匹配查出相等的技能
			Skill_Order = 
			if  
				Skill1 == Skill_1  ->
					1;
				Skill1 == Skill_2  ->
					2;
				Skill1 == Skill_3  ->
					3;
				Skill1 == Skill_4  ->
					4;
				Skill1 == Skill_5  ->
					5;
				Skill1 == Skill_6  ->
					6;
				true ->
					0
			end,
			%%查对对应的闲置技能
			EtsSplitSkillList = find_split_skill(PlayerId,Skill2),
			if
				%%没有匹配的闲置技能
				Skill2 =/= <<>> andalso EtsSplitSkillList == [] ->
					[4,<<>>];
				Skill2 == <<>> andalso Aptitude < 20 ->
					[7,<<>>];%%资质不够
				Skill2 == <<>> andalso Aptitude < 35 andalso  Sum > 1 ->
					[7,<<>>];%%资质不够
				Skill2 == <<>> andalso Aptitude < 45 andalso  Sum > 2 ->
					[7,<<>>];%%资质不够
				Skill2 == <<>> andalso Aptitude < 55 andalso  Sum > 3 ->
					[7,<<>>];%%资质不够
				Skill2 == <<>> andalso Aptitude < 65 andalso  Sum > 4 ->
					[7,<<>>];%%资质不够
				Skill2 == <<>> andalso Aptitude < 80 andalso  Sum > 5 andalso Pet#ets_pet.grow < 60  andalso Pet#ets_pet.chenge == 0 ->
					[7,<<>>];%%资质不够
				Skill2 == <<>> andalso Aptitude < 100 andalso  Sum >= 6 andalso Pet#ets_pet.grow < 80  andalso Pet#ets_pet.chenge =/= 2 ->
					[7,<<>>];%%资质不够
				Skill_Order =/= 0 ->
					case Skill_Order of
						1 ->
							NewPet = Pet#ets_pet{skill_1 = <<"[0,0,0,0]">>};
						2 ->
							NewPet = Pet#ets_pet{skill_2 = <<"[0,0,0,0]">>};
						3 ->
							NewPet = Pet#ets_pet{skill_3 = <<"[0,0,0,0]">>};
						4 ->
							NewPet = Pet#ets_pet{skill_4 = <<"[0,0,0,0]">>};
						5 ->
							NewPet = Pet#ets_pet{skill_5 = <<"[0,0,0,0]">>};
						6 ->
							NewPet = Pet#ets_pet{skill_6 = <<"[0,0,0,0]">>}
					end,
					if
						%%拉入主技能到闲置技能面板空格处(生成闲置技能信息)
						Skill2 == <<>> ->
							Id = db_agent:save_pet_split_skill(PlayerId,Pet#ets_pet.id,Skill1,Now),
							PetSplitSkillInfo = #ets_pet_split_skill{id=Id,player_id=PlayerId,pet_id=Pet#ets_pet.id,pet_skill=Skill1,ct=Now},
							update_pet_split_skill(PetSplitSkillInfo),
							%%更新灵兽信息
							lib_pet:update_pet(NewPet),
							save_pet(NewPet);
						%%拉入主技能到闲置技能面板的闲置技能上面(更新闲置技能信息)
						true ->
							EtsPetSplitSkill = lists:nth(1, EtsSplitSkillList),
							[Skill_Id1,Level1,Step1,SkillExp1] = util:string_to_term(tool:to_list(Skill1)),
							[Skill_Id2,Level2,Step2,SkillExp2] = util:string_to_term(tool:to_list(Skill2)),
							if
								%%高阶闲置技能吞噬低阶主技能
								Step2 >= Step1 ->
									StepSkillExp1 = data_pet:get_step_exp(Step1),
									NewExp = SkillExp2+SkillExp1+StepSkillExp1,
									[NewLevel2,NewStep2,NewExp2] = update_skill_level(Level2,Step2,NewExp),
									NewSkill2 = util:term_to_string([Skill_Id2,NewLevel2,NewStep2,NewExp2]),
									Id = EtsPetSplitSkill#ets_pet_split_skill.id,
									PetSplitSkillInfo = EtsPetSplitSkill#ets_pet_split_skill{pet_skill=tool:to_binary(NewSkill2),ct=Now},
									db_agent:update_pet_split_skill(Id,tool:to_binary(NewSkill2),Now),
									update_pet_split_skill(PetSplitSkillInfo),
									%%更新灵兽信息
									lib_pet:update_pet(NewPet),
									save_pet(NewPet);
								%%高阶主技能吞噬低阶闲置技能
								true ->
									StepSkillExp2 = data_pet:get_step_exp(Step2),
									NewExp = SkillExp1+SkillExp2+StepSkillExp2,
									[NewLevel1,NewStep1,NewExp1] = update_skill_level(Level1,Step1,NewExp),
									NewSkill1 = util:term_to_string([Skill_Id1,NewLevel1,NewStep1,NewExp1]),
									Id = EtsPetSplitSkill#ets_pet_split_skill.id,
									PetSplitSkillInfo = EtsPetSplitSkill#ets_pet_split_skill{pet_skill=tool:to_binary(NewSkill1),ct=Now},
									db_agent:update_pet_split_skill(Id,tool:to_binary(NewSkill1),Now),
									update_pet_split_skill(PetSplitSkillInfo),
									%%更新灵兽信息
									lib_pet:update_pet(NewPet),
									save_pet(NewPet)
							end
					end,
					spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(PlayerId,Pet#ets_pet.id, Skill1, Skill2, 3, Now)) end),
					[1,<<>>];
				%%没有匹配的主技能
				true ->
					[3,<<>>]
			end;
		%%灵兽学习技能或升级(2从下面拉到上面)
		Type == 2 ->
			Pet = lib_pet:get_pet_info(PetId),
			%%查询对应的闲置技能
			EtsSplitSkillList = find_split_skill(PlayerId,Skill1),
			Skill_Order = find_pet_skill(Pet,Skill2),
			HasStudy = find_pet_can_skill(Pet,Skill1),
			HasStudy2 = find_pet_can_skill(Pet,Skill1,Skill2),
			if
				%%没有匹配的闲置技能
				Skill1 =/= <<>> andalso EtsSplitSkillList == [] ->
					[4,<<>>];
				%%该技能已学
				Skill2 == <<>> andalso HasStudy =/= 0 ->
					[5,<<>>];
				HasStudy2 =/= 0 ->
					[5,<<>>];
				Skill2 =/= <<>> andalso Skill_Order == 0 ->
					[3,<<>>];
				true ->
					if
						%%拉入闲置技能到主技能面板空格处(生成主技能信息)
						Skill2 == <<>> ->
							Grid = lists:nth(1, find_pet_can_skill(Pet)),
							case Grid of
								1 ->
									NewPet = Pet#ets_pet{skill_1 = Skill1};
								2 ->
									NewPet = Pet#ets_pet{skill_2 = Skill1};
								3 ->
									NewPet = Pet#ets_pet{skill_3 = Skill1};
								4 ->
									NewPet = Pet#ets_pet{skill_4 = Skill1};
								5 ->
									NewPet = Pet#ets_pet{skill_5 = Skill1};
								6 ->
									NewPet = Pet#ets_pet{skill_6 = Skill1};
								0 ->
									NewPet = Pet
							end,
							EtsPetSplitSkill = lists:nth(1, EtsSplitSkillList),
							Id = EtsPetSplitSkill#ets_pet_split_skill.id,
							%%删除内存中的闲置技能
							delete_pet_split_skill([Id]),
							%%删除数据库中的闲置技能
							delete_ets_pet_split_skill(Id),
							lib_pet:update_pet(NewPet),
							save_pet(NewPet);
						true ->
							[Skill_Id1,Level1,Step1,SkillExp1] = util:string_to_term(tool:to_list(Skill1)),
							[Skill_Id2,Level2,Step2,SkillExp2] = util:string_to_term(tool:to_list(Skill2)),
							EtsPetSplitSkill = lists:nth(1, EtsSplitSkillList),
							%%闲置技能阶数不等于主技能阶数
							if
								%%高阶闲置技能吞噬低阶主技能
								Step2 >= Step1 ->
									StepSkillExp1 = data_pet:get_step_exp(Step1),
									NewExp = SkillExp2+SkillExp1+StepSkillExp1,
									[NewLevel2,NewStep2,NewExp2] = update_skill_level(Level2,Step2,NewExp),
									NewSkill2 = util:term_to_string([Skill_Id2,NewLevel2,NewStep2,NewExp2]),
									case Skill_Order of
										1 ->
											NewPet = Pet#ets_pet{skill_1 = tool:to_binary(NewSkill2)};
										2 ->
											NewPet = Pet#ets_pet{skill_2 = tool:to_binary(NewSkill2)};
										3 ->
											NewPet = Pet#ets_pet{skill_3 = tool:to_binary(NewSkill2)};
										4 ->
											NewPet = Pet#ets_pet{skill_4 = tool:to_binary(NewSkill2)};
										5 ->
											NewPet = Pet#ets_pet{skill_5 = tool:to_binary(NewSkill2)};
										6 ->
											NewPet = Pet#ets_pet{skill_6 = tool:to_binary(NewSkill2)}
									end,
									EtsPetSplitSkill = lists:nth(1, EtsSplitSkillList),
									Id = EtsPetSplitSkill#ets_pet_split_skill.id,
									%%删除内存中的闲置技能
									delete_pet_split_skill([Id]),
									%%删除数据库中的闲置技能
									delete_ets_pet_split_skill(Id),
									lib_pet:update_pet(NewPet),
									save_pet(NewPet);
								%%高阶主技能吞噬低阶闲置技能
								true ->
									StepSkillExp2 = data_pet:get_step_exp(Step2),
									NewExp = SkillExp1+SkillExp2+StepSkillExp2,
									[NewLevel1,NewStep1,NewExp1] = update_skill_level(Level1,Step1,NewExp),
									NewSkill1 = util:term_to_string([Skill_Id1,NewLevel1,NewStep1,NewExp1]),
									case Skill_Order of
										1 ->
											NewPet = Pet#ets_pet{skill_1 = tool:to_binary(NewSkill1)};
										2 ->
											NewPet = Pet#ets_pet{skill_2 = tool:to_binary(NewSkill1)};
										3 ->
											NewPet = Pet#ets_pet{skill_3 = tool:to_binary(NewSkill1)};
										4 ->
											NewPet = Pet#ets_pet{skill_4 = tool:to_binary(NewSkill1)};
										5 ->
											NewPet = Pet#ets_pet{skill_5 = tool:to_binary(NewSkill1)};
										6 ->
											NewPet = Pet#ets_pet{skill_6 = tool:to_binary(NewSkill1)}
									end,
									EtsPetSplitSkill = lists:nth(1, EtsSplitSkillList),
									Id = EtsPetSplitSkill#ets_pet_split_skill.id,
									%%删除内存中的闲置技能
									delete_pet_split_skill([Id]),
									%%删除数据库中的闲置技能
									delete_ets_pet_split_skill(Id),
									lib_pet:update_pet(NewPet),
									save_pet(NewPet)
							end
					end,
					spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(PlayerId,Pet#ets_pet.id, Skill1, Skill2, 4, Now)) end),
					[1,<<>>]
			end;
		%%灵兽学习技能或升级(3为左右拖动)
		Type == 3 ->
			[Skill_Id1,Level1,Step1,SkillExp1] = util:string_to_term(tool:to_list(Skill1)),
			[Skill_Id2,Level2,Step2,SkillExp2] = util:string_to_term(tool:to_list(Skill2)),
			if
				%%闲置技能左右拖动
				PetId == 0 ->
					%%查询对应的闲置技能
					EtsSplitSkillList1 = find_split_skill(PlayerId,Skill1),
					EtsSplitSkillList2 = find_split_skill(PlayerId,Skill2),
					if EtsSplitSkillList1 == [] orelse EtsSplitSkillList2 == [] ->
						   [0,<<>>];
					   true ->
						   EtsPetSplitSkill1= lists:nth(1, EtsSplitSkillList1),
						   EtsPetSplitSkill2New = lists:nth(1, EtsSplitSkillList2),
						   if 
							   %%有两条重复的闲置技能，第二条要重新取，否则两个id一样)
								EtsPetSplitSkill2New == EtsPetSplitSkill1 ->
									EtsPetSplitSkill2 = lists:nth(2, EtsSplitSkillList2);
								true ->
									EtsPetSplitSkill2 = EtsPetSplitSkill2New
						   end,
						   if
							   %%高阶闲置技能吞噬低阶闲置技能
								Step2 >= Step1 ->
									StepSkillExp1 = data_pet:get_step_exp(Step1),
									NewExp = SkillExp2+SkillExp1+StepSkillExp1,
									[NewLevel2,NewStep2,NewExp2] = update_skill_level(Level2,Step2,NewExp),
									NewSkill2 = util:term_to_string([Skill_Id2,NewLevel2,NewStep2,NewExp2]),
									%%更新第二个闲置技能
									Id2 = EtsPetSplitSkill2#ets_pet_split_skill.id,
									PetSplitSkillInfo = EtsPetSplitSkill2#ets_pet_split_skill{pet_skill=tool:to_binary(NewSkill2),ct=Now},
									db_agent:update_pet_split_skill(Id2,tool:to_binary(NewSkill2),Now),
									update_pet_split_skill(PetSplitSkillInfo),
									%%删除第一个闲置技能
									Id1 = EtsPetSplitSkill1#ets_pet_split_skill.id,
									%%删除内存中的闲置技能
									delete_pet_split_skill([Id1]),
									%%删除数据库中的闲置技能
									delete_ets_pet_split_skill(Id1);
									%%高阶闲置技能等于低阶闲置技能
								true ->
									StepSkillExp2 = data_pet:get_step_exp(Step2),
									NewExp = SkillExp1+SkillExp2+StepSkillExp2,
									[NewLevel1,NewStep1,NewExp1] = update_skill_level(Level1,Step1,NewExp),
									NewSkill1 = util:term_to_string([Skill_Id1,NewLevel1,NewStep1,NewExp1]),
									%%更新第二个闲置技能
									Id1 = EtsPetSplitSkill2#ets_pet_split_skill.id,
									PetSplitSkillInfo = EtsPetSplitSkill1#ets_pet_split_skill{pet_skill=tool:to_binary(NewSkill1),ct=Now},
									db_agent:update_pet_split_skill(Id1,tool:to_binary(NewSkill1),Now),
									update_pet_split_skill(PetSplitSkillInfo),
									%%删除第一个闲置技能
									Id2 = EtsPetSplitSkill2#ets_pet_split_skill.id,
									%%删除内存中的闲置技能
									delete_pet_split_skill([Id2]),
									%%删除数据库中的闲置技能
									delete_ets_pet_split_skill(Id2)
						   end,
						   spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(PlayerId,0, Skill1, Skill2, 5, Now)) end),
						   [1,<<>>]
					end;
				%%主技能左右拖动
				true ->
					Pet = lib_pet:get_pet_info(PetId),
					Skill_Order1 = find_pet_skill(Pet,Skill1),
					Skill_Order2 = find_pet_skill(Pet,Skill2),
					if
						%%高阶主技能吞噬低阶主技能
						Step2 >= Step1 ->
							StepSkillExp1 = data_pet:get_step_exp(Step1),
							NewExp = SkillExp2+SkillExp1+StepSkillExp1,
							[NewLevel2,NewStep2,NewExp2] = update_skill_level(Level2,Step2,NewExp),
							NewSkill2 = util:term_to_string([Skill_Id2,NewLevel2,NewStep2,NewExp2]),
							case Skill_Order1 of
								1 ->
									NewPet1 = Pet#ets_pet{skill_1 = <<"[0,0,0,0]">>};
								2 ->
									NewPet1 = Pet#ets_pet{skill_2 = <<"[0,0,0,0]">>};
								3 ->
									NewPet1 = Pet#ets_pet{skill_3 = <<"[0,0,0,0]">>};
								4 ->
									NewPet1 = Pet#ets_pet{skill_4 = <<"[0,0,0,0]">>};
								5 ->
									NewPet1 = Pet#ets_pet{skill_5 = <<"[0,0,0,0]">>};
								6 ->
									NewPet1 = Pet#ets_pet{skill_6 = <<"[0,0,0,0]">>};
								0 ->
									NewPet1 = Pet								
							end,
							case Skill_Order2 of
								1 ->
									NewPet2 = NewPet1#ets_pet{skill_1 = tool:to_binary(NewSkill2)};
								2 ->
									NewPet2 = NewPet1#ets_pet{skill_2 = tool:to_binary(NewSkill2)};
								3 ->
									NewPet2 = NewPet1#ets_pet{skill_3 = tool:to_binary(NewSkill2)};
								4 ->
									NewPet2 = NewPet1#ets_pet{skill_4 = tool:to_binary(NewSkill2)};
								5 ->
									NewPet2 = NewPet1#ets_pet{skill_5 = tool:to_binary(NewSkill2)};
								6 ->
									NewPet2 = NewPet1#ets_pet{skill_6 = tool:to_binary(NewSkill2)};
								0 ->
									NewPet2 = NewPet1
							end,
							lib_pet:update_pet(NewPet2),
							save_pet(NewPet2);
						%%高阶主技能等于低阶主技能
						true ->
							StepSkillExp2 = data_pet:get_step_exp(Step2),
							NewExp = SkillExp1+SkillExp2+StepSkillExp2,
							[NewLevel1,NewStep1,NewExp1] = update_skill_level(Level1,Step1,NewExp),
							NewSkill1 = util:term_to_string([Skill_Id1,NewLevel1,NewStep1,NewExp1]),
							case Skill_Order1 of
								1 ->
									NewPet1 = Pet#ets_pet{skill_1 = tool:to_binary(NewSkill1)};
								2 ->
									NewPet1 = Pet#ets_pet{skill_2 = tool:to_binary(NewSkill1)};
								3 ->
									NewPet1 = Pet#ets_pet{skill_3 = tool:to_binary(NewSkill1)};
								4 ->
									NewPet1 = Pet#ets_pet{skill_4 = tool:to_binary(NewSkill1)};
								5 ->
									NewPet1 = Pet#ets_pet{skill_5 = tool:to_binary(NewSkill1)};
								6 ->
									NewPet1 = Pet#ets_pet{skill_6 = tool:to_binary(NewSkill1)};
								0 ->
									NewPet1 = Pet								
							end,
							case Skill_Order2 of
								1 ->
									NewPet2 = NewPet1#ets_pet{skill_1 = <<"[0,0,0,0]">>};
								2 ->
									NewPet2 = NewPet1#ets_pet{skill_2 = <<"[0,0,0,0]">>};
								3 ->
									NewPet2 = NewPet1#ets_pet{skill_3 = <<"[0,0,0,0]">>};
								4 ->
									NewPet2 = NewPet1#ets_pet{skill_4 = <<"[0,0,0,0]">>};
								5 ->
									NewPet2 = NewPet1#ets_pet{skill_5 = <<"[0,0,0,0]">>};
								6 ->
									NewPet2 = NewPet1#ets_pet{skill_6 = <<"[0,0,0,0]">>};
								0 ->
									NewPet2 = NewPet1
							end,
							lib_pet:update_pet(NewPet2),	
							save_pet(NewPet2)					
					end,
					spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(PlayerId,Pet#ets_pet.id, Skill1, Skill2, 5, Now)) end),
					[1,<<>>]
			end;			
		true ->
			[0,<<>>]
	end.

drag_skill_preview(PlayerId,PetId,Type,Skill1,Skill2) ->
	if
		Type == 1 ->
			Pet = lib_pet:get_pet_info(PetId),
			Skill_1 = Pet#ets_pet.skill_1,
			Skill_2 = Pet#ets_pet.skill_2,
			Skill_3 = Pet#ets_pet.skill_3,
			Skill_4 = Pet#ets_pet.skill_4,
			Skill_5 = Pet#ets_pet.skill_5,
			Skill_6 = Pet#ets_pet.skill_6,
			%%匹配查出相等的技能
			Skill_Order = 
			if  
				Skill1 == Skill_1  ->
					1;
				Skill1 == Skill_2  ->
					2;
				Skill1 == Skill_3  ->
					3;
				Skill1 == Skill_4  ->
					4;
				Skill1 == Skill_5  ->
					5;
				Skill1 == Skill_6  ->
					6;
				true ->
					0
			end,
			%%查对对应的闲置技能
			EtsSplitSkillList = find_split_skill(PlayerId,Skill2),
			if
				%%没有匹配的闲置技能
				Skill2 =/= <<>> andalso EtsSplitSkillList == [] ->
					[4,<<>>];
				Skill_Order =/= 0 ->
					if
						%%拉入主技能到闲置技能面板空格处(生成闲置技能信息)
						Skill2 == <<>> ->
							Content = io_lib:format("确定分离此技能？",[]);
						%%拉入主技能到闲置技能面板的闲置技能上面
						true ->
							[Skill_Id1,Level1,Step1,SkillExp1] = util:string_to_term(tool:to_list(Skill1)),
							[Skill_Id2,Level2,Step2,SkillExp2] = util:string_to_term(tool:to_list(Skill2)),
							if
								%%高阶闲置技能吞噬低阶主技能
								Step2 >= Step1 ->
									StepSkillExp1 = data_pet:get_step_exp(Step1),
									NewExp = SkillExp2+SkillExp1+StepSkillExp1,
									[NewLevel2,_NewStep2,_NewExp2] = update_skill_level(Level2,Step2,NewExp),
									if 
										%%高阶吞噬低阶
										Step2 > Step1 ->
											if
												NewLevel2 == Level2 ->
													Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1]);
												true ->
													Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,升至~p级 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1,NewLevel2])
											end;
										%%阶数一致
										true ->
											if
												NewLevel2 == Level2 ->
													Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1]);
												true ->
													Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,升至~p级 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1,NewLevel2])
											end
									end;
								%%高阶主技能吞噬低阶闲置技能
								true ->
									StepSkillExp2 = data_pet:get_step_exp(Step2),
									NewExp = SkillExp1+SkillExp2+StepSkillExp2,
									[NewLevel1,_NewStep1,_NewExp1] = update_skill_level(Level1,Step1,NewExp),
									if
										NewLevel1 == Level1 ->
											Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),SkillExp2+StepSkillExp2]);
										true ->
											Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,升至~p级 ",[data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),SkillExp2+StepSkillExp2,NewLevel1])
									end
							end	
					end,
					[1,Content];
				%%没有匹配的主技能
				true ->
					[3,<<>>]
			end;
		%%灵兽学习技能或升级(2从下面拉到上面)
		Type == 2 ->
			Pet = lib_pet:get_pet_info(PetId),
			%%查询对应的闲置技能
			EtsSplitSkillList = find_split_skill(PlayerId,Skill1),
			HasStudy = find_pet_can_skill(Pet,Skill1),
			HasStudy2 = find_pet_can_skill(Pet,Skill1,Skill2),
			if
				%%没有匹配的闲置技能
				Skill1 =/= <<>> andalso EtsSplitSkillList == [] ->
					[4,<<>>];
				%%该技能已学
				Skill2 == <<>> andalso HasStudy =/= 0 ->
					[5,<<>>];
				HasStudy2 =/= 0 ->
					[5,<<>>];
				true ->
					if
						%%拉入闲置技能到主技能面板空格处(生成主技能信息)
						Skill2 == <<>> ->
							Content = io_lib:format("确定让灵兽学习该技能？",[]);
						true ->
							[Skill_Id1,Level1,Step1,SkillExp1] = util:string_to_term(tool:to_list(Skill1)),
							[Skill_Id2,Level2,Step2,SkillExp2] = util:string_to_term(tool:to_list(Skill2)),
							%%闲置技能阶数不等于主技能阶数
							if
								%%高阶闲置技能吞噬低阶主技能
								Step2 >= Step1 ->
									StepSkillExp1 = data_pet:get_step_exp(Step1),
									NewExp = SkillExp2+SkillExp1+StepSkillExp1,
									[NewLevel2,_NewStep2,_NewExp2] = update_skill_level(Level2,Step2,NewExp),
									if 
										%%高阶吞噬低阶
										Step2 > Step1 ->
											if
												NewLevel2 == Level2 ->
													Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1]);
												true ->
													Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,升至~p级 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1,NewLevel2])
											end;
										%%阶数一致
										true ->
											if
												NewLevel2 == Level2 ->
													Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1]);
												true ->
													Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,升至~p级 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1,NewLevel2])
											end
									end;
								%%高阶主技能吞噬低阶闲置技能
								true ->
									StepSkillExp2 = data_pet:get_step_exp(Step2),
									NewExp = SkillExp1+SkillExp2+StepSkillExp2,
									[NewLevel1,_NewStep1,_NewExp1] = update_skill_level(Level1,Step1,NewExp),
									if
										NewLevel1 == Level1 ->
											Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),SkillExp2+StepSkillExp2]);
										true ->
											Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,升至~p级 ",[data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),SkillExp2+StepSkillExp2,NewLevel1])
									end
							end
					end,
					[1,Content]
			end;
		%%灵兽学习技能或升级(3为左右拖动)
		Type == 3 ->
			[Skill_Id1,Level1,Step1,SkillExp1] = util:string_to_term(tool:to_list(Skill1)),
			[Skill_Id2,Level2,Step2,SkillExp2] = util:string_to_term(tool:to_list(Skill2)),
			if
				%%闲置技能左右拖动
				PetId == 0 ->
					%%查询对应的闲置技能
					if
						%%高阶闲置技能吞噬低阶闲置技能
						Step2 >= Step1 ->
							StepSkillExp1 = data_pet:get_step_exp(Step1),
							NewExp = SkillExp2+SkillExp1+StepSkillExp1,
							[NewLevel2,_NewStep2,_NewExp2] = update_skill_level(Level2,Step2,NewExp),
							if
								%%高阶吞噬低阶
								Step2 > Step1 ->
									if
										NewLevel2 == Level2 ->
											Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1]);
										true ->
											Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,升至~p级 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1,NewLevel2])
									end;
								%%阶数一致
								true ->
									if
										NewLevel2 == Level2 ->
											Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1]);
										true ->
											Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,升至~p级 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1,NewLevel2])
									end
							end;
						%%高阶闲置技能等于低阶闲置技能
						true ->
							StepSkillExp2 = data_pet:get_step_exp(Step2),
							NewExp = SkillExp1+SkillExp2+StepSkillExp2,
							[NewLevel1,_NewStep1,_NewExp1] = update_skill_level(Level1,Step1,NewExp),
							if
								NewLevel1 == Level1 ->
									Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),SkillExp2+StepSkillExp2]);
								true ->
									Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,升至~p级 ",[data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),SkillExp2+StepSkillExp2,NewLevel1])
							end
					end,
					[1,Content];
				%%主技能左右拖动
				true ->
					if
						%%高阶主技能吞噬低阶主技能
						Step2 >= Step1 ->
							StepSkillExp1 = data_pet:get_step_exp(Step1),
							NewExp = SkillExp2+SkillExp1+StepSkillExp1,
							[NewLevel2,_NewStep2,_NewExp2] = update_skill_level(Level2,Step2,NewExp),
							if 
								%%高阶吞噬低阶
								Step2 > Step1 ->
									if
										NewLevel2 == Level2 ->
											Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1]);
										true ->
											Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,升至~p级 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1,NewLevel2])
									end;
								%%阶数一致
								true ->
									if
										NewLevel2 == Level2 ->
											Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1]);
										true ->
											Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,升至~p级 ",[data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),SkillExp1+StepSkillExp1,NewLevel2])
									end
							end;
						%%高阶主技能等于低阶主技能
						true ->
							StepSkillExp2 = data_pet:get_step_exp(Step2),
							NewExp = SkillExp1+SkillExp2+StepSkillExp2,
							[NewLevel1,_NewStep1,_NewExp1] = update_skill_level(Level1,Step1,NewExp),
							if
								NewLevel1 == Level1 ->
									Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验 ",[data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),SkillExp2+StepSkillExp2]);
								true ->
									Content = io_lib:format("<font color='~s'>【~p阶~s】</font>将吞噬<font color='~s'>【~p阶~s】</font>获得~p经验,升至~p级 ",[data_pet:get_skill_name_color(Step1),Step1,data_pet:get_skill_name(Skill_Id1),data_pet:get_skill_name_color(Step2),Step2,data_pet:get_skill_name(Skill_Id2),SkillExp2+StepSkillExp2,NewLevel1])
							end
					end,
					[1,Content]
			end;			
		true ->
			[0,<<>>]
	end.

%%=========================================================================
%% 工具函数
%%=========================================================================
sum_splitskill_exp([],Exp) ->
	Exp;
sum_splitskill_exp([H | Rest],Exp) ->
	[_Id,_Pet_id,_SkillId, _SkillLevel, SkillStep, SkillExp] = H,
	%%阶数对应的经验
	StepSkillExp = data_pet:get_step_exp(SkillStep),
	NewExp = Exp+SkillExp+StepSkillExp,
	sum_splitskill_exp(Rest,NewExp).

%%技能升级(不消耗经验)
update_skill_level(Level,Step,Exp) ->
	if Level >= 60 ->
		   [Level,Step,Exp];
	   true ->
		   NexpLevelExp = data_pet:get_pet_skill_exp(Level,Step),
		   loop_update_skill_level(Level,Step,Exp,NexpLevelExp)
	end.

loop_update_skill_level(Level,Step,Exp,NexpLevelExp) ->
	if
		Exp =< NexpLevelExp ->
			[Level,Step,Exp];
		true ->
			NexpLevelExp1 = data_pet:get_pet_skill_exp(Level+1,Step),
			if
				Exp < NexpLevelExp1 ->
					[Level,Step,Exp];
				true ->
					if Level >= 60 ->
						   [Level,Step,Exp];
					   true ->
						   loop_update_skill_level(Level+1,Step,Exp,NexpLevelExp1)
					end
			end
	end. 
	
%%添加灵兽所有的技能经验并自动升级
add_pet_skill_exp(Pet,Exp) ->
	if
		Pet =/= [] ->
			SkillList = [{1,Pet#ets_pet.skill_1},{2,Pet#ets_pet.skill_2},{3,Pet#ets_pet.skill_3},{4,Pet#ets_pet.skill_4},{5,Pet#ets_pet.skill_5}],
			F = fun(Skill_Order,Skill) ->
						[Skill_Id,Level,Step,SkillExp] = util:string_to_term(tool:to_list(Skill)),
						if Skill_Id == 0 ->
							   NewPet = Pet;
						   true ->
							   [NewLevel,Step,NewExp] = update_skill_level(Level,Step,Exp+SkillExp),
							   NewSkill1 = util:term_to_string([Skill_Id,NewLevel,Step,NewExp]),
							   case Skill_Order of
								   1 ->
									   NewPet = Pet#ets_pet{skill_1 = tool:to_binary(NewSkill1)};
								   2 ->
									   NewPet = Pet#ets_pet{skill_2 = tool:to_binary(NewSkill1)};
								   3 ->
									   NewPet = Pet#ets_pet{skill_3 = tool:to_binary(NewSkill1)};
								   4 ->
									   NewPet = Pet#ets_pet{skill_4 = tool:to_binary(NewSkill1)};
								   5 ->
									   NewPet = Pet#ets_pet{skill_5 = tool:to_binary(NewSkill1)};
								   6 ->
									   NewPet = Pet#ets_pet{skill_6 = tool:to_binary(NewSkill1)};
								   0 ->
									   NewPet = Pet
							   end
						end,
						lib_pet:update_pet(NewPet),
						lib_pet:save_pet(NewPet)
				end,
			[F(Skill_Order,Skill) || {Skill_Order,Skill} <- SkillList];
		true ->
			skip
	end.

%% -----------------------------------------------------------------
%% 广播消息给进程
%% -----------------------------------------------------------------
send_to_all(MsgType, Bin) ->
   	MS = ets:fun2ms(fun(T) -> 
						[T#player.other#player_other.pid] 
						end),
   	Pids = ets:select(?ETS_ONLINE, MS),		
    F = fun([P]) ->
        gen_server:cast(P, {MsgType, Bin})
    end,
    [F(Pid) || Pid <- Pids].



%% -----------------------------------------------------------------
%% 通用函数
%% -----------------------------------------------------------------
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

%% -----------------------------------------------------------------
%% 灵兽操作
%% -----------------------------------------------------------------
get_out_pet(PlayerId) ->
	match_one(?ETS_PET,#ets_pet{player_id = PlayerId,status = 1,_='_'}).

get_pet(PlayerId, PetId) ->
    match_one(?ETS_PET, #ets_pet{id=PetId, player_id=PlayerId, _='_'}).

get_pet(PetId) ->
    lookup_one(?ETS_PET, PetId).

get_pet_extra(PlayerId) ->
	Ets_pet_extra = match_one(?ETS_PET_EXTRA,#ets_pet_extra{player_id = PlayerId,_='_'}),
	Now = util:unixtime(),
	%%清0时间
	DefineTime = 3600*0+10,
	TodaySecond = util:get_today_current_second(),
	{TodayTime, _NextDayYime} = util:get_midnight_seconds(Now), 
	LastTime = Ets_pet_extra#ets_pet_extra.last_time,
	%%零晨0点幸运值清0
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
			Ets_pet_extra1 = Ets_pet_extra#ets_pet_extra{lucky_value = 0,free_flush = 0,batt_free_flush = 0,last_time = Now},
			update_pet_extra(Ets_pet_extra1),
			Ets_pet_extra1;
		false ->
			Ets_pet_extra
	end.

get_pet_extra_value(PlayerId) ->
	match_one(?ETS_PET_EXTRA_VALUE,#ets_pet_extra_value{player_id = PlayerId,_='_'}).

%%按id排序
get_all_pet(PlayerId) ->
    PetList = match_all(?ETS_PET, #ets_pet{player_id=PlayerId, _='_'}),
	case length(PetList) =< 1 of
		true -> PetList;
		_ ->
			lists:sort(fun(Pet1,Pet2) -> Pet1#ets_pet.id =< Pet2#ets_pet.id end, PetList)
	end.

%%根据等级查找角色所有休息状态的灵兽
get_all_pet(PlayerId,Level) ->
   match_all(?ETS_PET, #ets_pet{player_id=PlayerId, level=Level, status=0, _='_'}).

%%根据等级,资质，技能查找角色所有休息状态的灵兽
get_all_pet(PlayerId,Level,Aptitude) ->
	MS = ets:fun2ms(fun(T) when T#ets_pet.player_id == PlayerId andalso T#ets_pet.level == Level andalso T#ets_pet.status == 0 andalso T#ets_pet.aptitude =< Aptitude andalso T#ets_pet.skill_1 == <<"[0,0,0,0]">> -> T end),
	ets:select(?ETS_PET, MS).

get_pet_count(PlayerId) ->
    length(match_all(?ETS_PET, #ets_pet{player_id=PlayerId, _='_'})).

update_time(Pet,Time) ->
	PetNew = Pet#ets_pet{time = Time},
	update_pet(PetNew).

update_pet(Pet) ->
	if Pet#ets_pet.chenge > 2 ->
		   Pet1 = Pet#ets_pet{chenge =1};
	   true ->
		   Pet1 = Pet
	end,
    ets:insert(?ETS_PET, Pet1).

update_pet_buy(PetBuyInfo) ->
    ets:insert(?ETS_PET_BUY, PetBuyInfo).

update_pet_split_skill(PetSplitSkillInfo) ->
    ets:insert(?ETS_PET_SPLIT_SKILL, PetSplitSkillInfo).

insert_pet_extra(PetExtraInfo) ->
	ets:insert(?ETS_PET_EXTRA, PetExtraInfo).

save_pet_extra_value(PetExtraValue) ->
	ets:insert(?ETS_PET_EXTRA_VALUE, PetExtraValue).

update_pet_extra(PetExtraInfo) ->
	Lucky_value = PetExtraInfo#ets_pet_extra.lucky_value,
	Batt_lucky_value = PetExtraInfo#ets_pet_extra.batt_lucky_value,
	 Now = util:unixtime(),
	if Lucky_value > 1000 andalso Batt_lucky_value > 1000->
		   PetExtraInfo1 = PetExtraInfo#ets_pet_extra{lucky_value = 1000,batt_lucky_value=1000};
	   Lucky_value > 1000 ->
		   PetExtraInfo1 = PetExtraInfo#ets_pet_extra{lucky_value = 1000};
	   Batt_lucky_value > 1000->
		   PetExtraInfo1 = PetExtraInfo#ets_pet_extra{batt_lucky_value=1000};
	   true ->
		   PetExtraInfo1 = PetExtraInfo
	end,		
	PetExtraInfo2 = PetExtraInfo1#ets_pet_extra{last_time = Now},
	ets:insert(?ETS_PET_EXTRA, PetExtraInfo2),
	spawn(fun()-> update_db_pet_extra(PetExtraInfo2) end),
	PetExtraInfo1.

update_db_pet_extra(PetExtraInfo) ->
	db_agent:update_pet_extra(PetExtraInfo#ets_pet_extra.player_id,PetExtraInfo#ets_pet_extra.skill_exp,PetExtraInfo#ets_pet_extra.lucky_value,PetExtraInfo#ets_pet_extra.batt_lucky_value,PetExtraInfo#ets_pet_extra.auto_step,PetExtraInfo#ets_pet_extra.free_flush,PetExtraInfo#ets_pet_extra.batt_free_flush,PetExtraInfo#ets_pet_extra.last_time).
	

delete_pet(PetId) ->
    ets:delete(?ETS_PET, PetId).

delete_all_pet(PlayerId) ->
    ets:match_delete(?ETS_PET, #ets_pet{player_id=PlayerId, _='_'}).

delete_all_pet_split_skill(PlayerId) ->
	ets:match_delete(?ETS_PET_SPLIT_SKILL,#ets_pet_split_skill{player_id=PlayerId, _='_'}).

delete_all_pet_buy(PlayerId) ->
	ets:match_delete(?ETS_PET_BUY,#ets_pet_buy{player_id=PlayerId, _='_'}).

delete_pet_split_skill(PetSplitSkillIdList) ->
	db_agent:delete_pet_split_skill(PetSplitSkillIdList).

delete_ets_pet_split_skill(Id) ->
	ets:delete(?ETS_PET_SPLIT_SKILL, Id).

%% 灵兽道具
%% -----------------------------------------------------------------
get_base_pet(GoodsId) ->
    lookup_one(?ETS_BASE_PET, GoodsId).

update_base_pet(BasePet) ->
    ets:insert(?ETS_BASE_PET, BasePet).

update_base_pet_skill_effect(BasePetSkillEffectInfo) ->
	 ets:insert(?ETS_BASE_PET_SKILL_EFFECT, BasePetSkillEffectInfo).

%%到内存表查找
get_base_pet_skill_effect(SkillId,SkillLevel,SkillStep) ->
	MS = ets:fun2ms(fun(T) when T#ets_base_pet_skill_effect.skill_id == SkillId andalso T#ets_base_pet_skill_effect.lv == SkillLevel andalso T#ets_base_pet_skill_effect.step == SkillStep ->
			T
	end),
	ets:select(?ETS_BASE_PET_SKILL_EFFECT, MS).

%% -----------------------------------------------------------------
%% 背包物品
%% -----------------------------------------------------------------
get_goods(GoodsId) ->
    match_one(?ETS_GOODS_ONLINE, #goods{id=GoodsId, location=4, _='_'}).

%% -----------------------------------------------------------------
%% 物品类型
%% -----------------------------------------------------------------
get_goods_type(GoodsId) ->
    lookup_one(?ETS_BASE_GOODS,GoodsId).

%%------------------------测试接口-----------------------------------
test_update_pet_exp(PidSend,Lv,Pet,Exp)->
	NewExp = Pet#ets_pet.exp+Exp,
	NewPet=Pet#ets_pet{exp=NewExp},
	Now = util:unixtime(),
	test_update_pet(PidSend,NewPet,Now,Lv).

test_update_pet_apt(PidSend,Lv,Pet,Apt)->
	NewApt = Pet#ets_pet.aptitude+Apt,
	NewPet=Pet#ets_pet{aptitude=NewApt},
	Now = util:unixtime(),
	test_update_pet(PidSend,NewPet,Now,Lv).

test_update_pet_grow(Pet,Grow)->
	NewGrow = Pet#ets_pet.grow+Grow,
	NewPet=Pet#ets_pet{grow=NewGrow},
	lib_pet:update_pet(NewPet),
	save_pet(NewPet).

test_update_pet_level(PidSend,Lv,Pet,Level)->
	NewLevel = Pet#ets_pet.level+Level,
	NewPet=Pet#ets_pet{level=NewLevel},
	Now = util:unixtime(),
	NewPet1 = test_update_pet(PidSend,NewPet,Now,Lv),
	lib_pet:update_pet(NewPet1),
	save_pet(NewPet1).

test_update_pet_train(Status,Pet,TrainTime) ->
	NowTime = util:unixtime(),
	Total = TrainTime+NowTime,
	RestPet = lib_pet:rest_pet(Pet),
	NewPet = RestPet#ets_pet{status=2,goods_num=1,money_type=10,money_num=1,auto_up=1,train_start=NowTime,train_end=Total},
	lib_pet:update_pet(NewPet),
	db_agent:pet_train(NewPet#ets_pet.id,2,1,10,1,1,NowTime,TrainTime+NowTime),
%% 	{ok, BinData} = pt_41:write(41016,[1,NewPet#ets_pet.id,NewPet#ets_pet.status]),
%% 	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	mod_pet:pet_attribute_effect(Status,NewPet),
	pp_pet:handle(41007, Status, [NewPet#ets_pet.id]).
	

test_update_pet(PidSend,Pet,Now,Lv)->
	NewPet = upgrade_pet(PidSend,Pet,Lv,Now,1),
	NextLevelExp = data_pet:get_upgrade_exp(NewPet#ets_pet.level),
	if NewPet#ets_pet.level<Lv ->
		if 
			Pet#ets_pet.exp >= NextLevelExp  andalso NewPet#ets_pet.level=<14 ->
				test_update_pet(PidSend,NewPet,Now,Lv);
			true->
				NewPet
		end;
		true->
			NewPet
	end.

test_update_pet_happy(Pet,Happy)->
	NewPet=Pet#ets_pet{happy=Happy},
	lib_pet:update_pet(NewPet),
	save_pet(NewPet).

	
%%判断角色灵兽的最高等级
get_max_pet_level(PlayerId) ->
	PetList = match_all(?ETS_PET, #ets_pet{player_id = PlayerId, _='_'}),
	NewPetList = 
	case length(PetList) =< 1 of
		true -> PetList;
		_ ->
			lists:sort(fun(Pet1,Pet2) -> Pet1#ets_pet.level > Pet2#ets_pet.level end, PetList)
	end,
	case NewPetList of
		[] -> 
			0;
		_ ->
			[Pet |_] = NewPetList,
			Pet#ets_pet.level
	end.

%%技能批量分离
batch_oper(PlayerId,Type) ->
	if
		Type == 1 -> 
			PET_MAX_GRID = mod_pet:get_pet_max_grid(),
			PetSplitSkillListLenth = length(lib_pet:get_all_split_skill(PlayerId)),
			AllPetList = lib_pet:get_all_pet(PlayerId,1),
			%% 超过最大分离技能格数
			if 
				PetSplitSkillListLenth >= PET_MAX_GRID ->
					2;
				AllPetList == [] ->
					3;
				true ->
					loop_batch_oper(AllPetList,(PET_MAX_GRID - PetSplitSkillListLenth)),
					1
			end;
		Type == 2 ->
			AllPetList = get_all_pet(PlayerId,1,30),
			if
				AllPetList == [] ->
					4;
				true ->
					[free_pet(Pet#ets_pet.id) || Pet <- AllPetList],
					1
			end;
		true -> %%操作类型不对
			0
	end.

%%循环分离技能(1级灵兽最多只有skill_1为有效技能)
loop_batch_oper([],Num) ->
	Num;
loop_batch_oper([Pet|Rest],Num) ->
	if 
		Num > 0 ->
			Skill_1 =  Pet#ets_pet.skill_1,
			if Skill_1 =/= <<"[0,0,0,0]">> ->
				   %%分离技能
				   split_skill(Pet),
				   loop_batch_oper(Rest,Num - 1);
			   true ->
				   loop_batch_oper(Rest,Num)
			end;
	true -> 
		Num
	end.

%%判断灵兽是否有技能
judge_pet_has_skill(Pet) ->
	if
		Pet == [] ->
			false;
		Pet#ets_pet.skill_1 == <<"[0,0,0,0]">> andalso Pet#ets_pet.skill_2 == <<"[0,0,0,0]">> andalso Pet#ets_pet.skill_3 == <<"[0,0,0,0]">> andalso Pet#ets_pet.skill_4 == <<"[0,0,0,0]">> andalso Pet#ets_pet.skill_5 == <<"[0,0,0,0]">> andalso Pet#ets_pet.skill_6 == <<"[0,0,0,0]">>->
			false;
		true ->
			true
	end.

%%设置灵兽自动萃取的阶数
set_auto_step(Player_Id,Auto_Step) ->
	if Auto_Step >= 4 ->
		   Auto_Step1 = 4;
	   Auto_Step < 0 ->
		   Auto_Step1 = 0;
	   true ->
		   Auto_Step1 = Auto_Step
	end,		
	Ets_Pet_Extra = lib_pet:get_pet_extra(Player_Id),
	Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{auto_step = Auto_Step1},
	lib_pet:update_pet_extra(Ets_Pet_Extra1),
	1.

%%生成随机灵兽或灵兽技能经验丹
general_random_pet(Lucky_value,Num) ->
	F = fun([Type,Step]) ->
				Skill_Id = data_pet:get_grab_pet_skill_id(),
				PetTypeId = data_pet:get_random_type_id(),
				if Type == 1 ->%%表示灵兽
					   [PetTypeId,Skill_Id,Step];
				   true ->%%表示技能经验丹
					   [0,0,24107]
				end
		end,
	AllRandomPetOrGoods = [F(data_pet:get_data_by_lucky_value(Lucky_value)) || _ <- lists:seq(1, Num)],
	%%批量购买时如果幸运值达1千时只出现一个非攻击的5阶技能
	NewResult = 
	if Lucky_value >= 1000 ->
		   F1 = fun([PetTypeId1,Skill_Id1,Step1]) ->
						if Step1 == 5 ->
							   [PetTypeId1,Skill_Id1,4];
						   true ->
							   [PetTypeId1,Skill_Id1,Step1]
						end
				end,
		   NewAllRandomPetOrGoods = [F1([PetTypeId1,Skill_Id1,Step1]) || [PetTypeId1,Skill_Id1,Step1] <- AllRandomPetOrGoods],
		   NewAllRandomPetOrGoods2 = loop_random_pet_skill(NewAllRandomPetOrGoods,0),
		   util:random_list(NewAllRandomPetOrGoods2);
	   true ->
		   AllRandomPetOrGoods
	end,
	loop_filter_random_pet_skill(NewResult,0,0,[]).

%%生成随机灵兽或灵兽技能经验丹
general_random_pet_free(Lucky_value,Num) ->
	F = fun([Type,Step]) ->
				Skill_Id = data_pet:get_grab_pet_skill_id(),
				PetTypeId = data_pet:get_random_type_id(),
				if Type == 1 ->%%表示灵兽
					   [PetTypeId,Skill_Id,Step];
				   true ->%%表示技能经验丹
					   [0,0,24107]
				end
		end,
	AllRandomPetOrGoods = [F(data_pet:get_data_by_lucky_value_flush(Lucky_value)) || _ <- lists:seq(1, Num)],
	%%批量购买时如果幸运值达1千时只出现一个非攻击的5阶技能
	NewResult = 
	if Num == 6 andalso Lucky_value >= 1000 ->
		   F1 = fun([PetTypeId1,Skill_Id1,Step1]) ->
						if Step1 == 5 ->
							   [PetTypeId1,Skill_Id1,4];
						   true ->
							   [PetTypeId1,Skill_Id1,Step1]
						end
				end,
		   NewAllRandomPetOrGoods = [F1([PetTypeId1,Skill_Id1,Step1]) || [PetTypeId1,Skill_Id1,Step1] <- AllRandomPetOrGoods],
		   NewAllRandomPetOrGoods2 = loop_random_pet_skill(NewAllRandomPetOrGoods,0),
		   util:random_list(NewAllRandomPetOrGoods2);
	   true ->
		   AllRandomPetOrGoods
	end,
	loop_filter_random_pet_skill(NewResult,0,0,[]).

%%对批量购买和批量刷新随机结果进行处理，保证同时至多只有一个5阶和一个4阶技能
handle_random_result(AllRandomPetOrGoods) ->
	if length(AllRandomPetOrGoods) >= 6 ->%%批量随机
		   F = fun([_PetTypeId,_Skill_Id,Step],[FoutStep,FiveStep]) ->
					   if Step == 4 -> [FoutStep+1,FiveStep];
						  Step == 5 -> [FoutStep,FiveStep+1];
						  true ->[FoutStep,FiveStep]
					   end
			   end,
		   [FoutStepNum,FiveStepNum] = lists:foldl(F, [0,0], AllRandomPetOrGoods),
		   if FoutStepNum > 1 ->ok;
			  FiveStepNum > 1 -> ok;
			  true -> ok
		   end;
	   true ->
		   AllRandomPetOrGoods
	 end.


%%免费刷新出来的3阶及以下的技能
general_random_free(Num) ->
	F = fun([Type,Step]) ->
				Skill_Id = data_pet:get_grab_pet_skill_id(),
				PetTypeId = data_pet:get_random_type_id(),
				if Type == 1 ->%%表示灵兽
					   [PetTypeId,Skill_Id,Step];
				   true ->%%表示技能经验丹
					   [0,0,24107]
				end
		end,
	AllRandomPetOrGoods = [F(data_pet:get_data_by_free()) || _ <- lists:seq(1, Num)],
	AllRandomPetOrGoods.

loop_random_pet_skill(AllRandomPetOrGoods,1) ->
	AllRandomPetOrGoods;
loop_random_pet_skill([H | Rest],0) ->
	[PetTypeId,Skill_Id,Step] = H, 
	if Step =< 4 ->
		   loop_random_pet_skill([[PetTypeId,Skill_Id,5] | Rest],1);
	   true ->
		   loop_random_pet_skill(Rest,0)
	end.

%%只允许至多出现一个5阶和4阶的技能
loop_filter_random_pet_skill([],_FourStepNum,_FiveStepNum,AllRandomPetOrGoods) ->
	AllRandomPetOrGoods;
loop_filter_random_pet_skill([H | Rest],FourStepNum,FiveStepNum,AllRandomPetOrGoods) ->
	[PetTypeId,Skill_Id,Step] = H, 
	if Step == 4 ->
		   if FourStepNum < 1 ->
				  loop_filter_random_pet_skill(Rest,FourStepNum+1,FiveStepNum,[[PetTypeId,Skill_Id,Step] | AllRandomPetOrGoods]);
			  true ->
				  loop_filter_random_pet_skill(Rest,FourStepNum,FiveStepNum,[[PetTypeId,Skill_Id,2] | AllRandomPetOrGoods])
		   end;
	   Step == 5 ->
		   if FiveStepNum < 1 ->
				  loop_filter_random_pet_skill(Rest,FourStepNum,FiveStepNum+1,[[PetTypeId,Skill_Id,Step] | AllRandomPetOrGoods]);
			  true ->
				  loop_filter_random_pet_skill(Rest,FourStepNum,FiveStepNum,[[PetTypeId,Skill_Id,3] | AllRandomPetOrGoods])
		   end;
	   true ->
		   loop_filter_random_pet_skill(Rest,FourStepNum,FiveStepNum,[[PetTypeId,Skill_Id,Step] | AllRandomPetOrGoods])
	end.

%%随机批量购买面板列表
get_random_pet_buy_list(Player_Id) ->
	Ets_Pet_Extra = lib_pet:get_pet_extra(Player_Id),
	Ets_pet_extra_value = get_pet_extra_value(Player_Id),
	AfterValueList2 = 
	if Ets_pet_extra_value == [] ->
		   AfterValueList = general_random_pet(Ets_Pet_Extra#ets_pet_extra.lucky_value,6),
		   %%开到5阶幸运人值清0
		   handle_random_pet_5_step(Player_Id,AfterValueList),
		   Id = db_agent:insert_random_pet(Player_Id,tool:to_binary(util:term_to_string([])),tool:to_binary(util:term_to_string(AfterValueList)),tool:to_binary(util:term_to_string([])),tool:to_binary(util:term_to_string([])),tool:to_binary(util:term_to_string([])),tool:to_binary(util:term_to_string([])),0,0),
		   Ets_pet_extra_value1 = #ets_pet_extra_value{
													 		id = Id,
													 		player_id = Player_Id,
													  		before_value = tool:to_binary(util:term_to_string([])),
													  	    after_value = tool:to_binary(util:term_to_string(AfterValueList)),
															before_value1 = tool:to_binary(util:term_to_string([])),
													  	    after_value1 = tool:to_binary(util:term_to_string([])),
													  	    order = 0,
													  	    ct = 0 },
		   save_pet_extra_value(Ets_pet_extra_value1),
		   AfterValueList;
	   true ->
		   AfterValueList = util:string_to_term(tool:to_list(Ets_pet_extra_value#ets_pet_extra_value.after_value)),
		   if AfterValueList == [] ->
				  AfterValueList1 = general_random_pet(Ets_Pet_Extra#ets_pet_extra.lucky_value,6),
		   		  NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   before_value = Ets_pet_extra_value#ets_pet_extra_value.after_value,
													  	   after_value = tool:to_binary(util:term_to_string(AfterValueList1)),
													  	   order = 6,ct = util:unixtime()},
				  save_pet_extra_value(NewEts_pet_extra_value),
				  spawn(fun()-> update_pet_extra_value_db(NewEts_pet_extra_value) end),		  
				  AfterValueList1;
			  true ->
				  AfterValueList
		   end
	end,
	[AfterValueList2] ++ [Ets_Pet_Extra#ets_pet_extra.free_flush,lib_pet:get_max_free_flush()].
	
%%随机批量购买面板购买动作Order为顺序号，为0是购买所有,单个购买顺序号1-6
buy_random_pet(Status,Order) ->
	NowTime = util:unixtime(),
	%%NullCellNum = length(gen_server:call(Status#player.other#player_other.pid_goods,{'null_cell'})), 
	IsWarServer  = lib_war:is_war_server(),
	PetSplitSkillListLenth = length(lib_pet:get_all_split_skill(Status#player.id)),
	PET_MAX_GRID = mod_pet:get_pet_max_grid(),
	if Order == 0 ->
		   Num = 6;
	   Order >= 1 andalso Order =< 6 ->
		   Num = 1;
	   true ->
		   Num = 0
	end,
	if Num == 0 ->
		   2;
	   Num == 6 andalso Status#player.gold  < ?BATCHRANDOM_PET_PRICE ->
		   3;
	   Num =/= 6 andalso Status#player.gold  < ?RANDOM_PET_PRICE ->
		   3;
	   IsWarServer -> 
		   6;
	   true ->
		   Ets_pet_extra_value = get_pet_extra_value(Status#player.id),
		   AfterValueList = util:string_to_term(tool:to_list(Ets_pet_extra_value#ets_pet_extra_value.after_value)),
		   Ets_Pet_Extra = lib_pet:get_pet_extra(Status#player.id),
		   if Num == 6 ->
				  TotalGoldNum = ?BATCHRANDOM_PET_PRICE,
				  AllRandomPetOrGoods = AfterValueList,
				  RandomPetCount = find_random_buy_pet(Ets_Pet_Extra,AllRandomPetOrGoods),
				  %%RandomExpCount = find_random_exp_dan(AllRandomPetOrGoods),
				  if (PetSplitSkillListLenth + RandomPetCount) > PET_MAX_GRID ->
						 4;
					 true ->
						 Status1 = lib_goods:cost_money(Status, TotalGoldNum, gold, 4106),
						 gen_server:cast(Status1#player.other#player_other.pid, {'SET_PLAYER', Status1}),
						 lib_player:send_player_attribute(Status1,2),
						 random_final_buy(Status1,AllRandomPetOrGoods),
						 %%重新在进程字典中生成数据(全部刷新)
						 NewAllRandomPetOrGoods = general_random_pet(Ets_Pet_Extra#ets_pet_extra.lucky_value,6),
						 handle_random_pet_5_step(Status#player.id,NewAllRandomPetOrGoods),
						 NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   before_value = Ets_pet_extra_value#ets_pet_extra_value.after_value,
													  	   after_value = tool:to_binary(util:term_to_string(NewAllRandomPetOrGoods)),
													  	   order = Order,
													  	   ct = NowTime},
						 save_pet_extra_value(NewEts_pet_extra_value),
						 spawn(fun()-> update_pet_extra_value_db(NewEts_pet_extra_value) end),
						 1
				  end;
			  true ->
				  TotalGoldNum = ?RANDOM_PET_PRICE,
				  ResultAllRandomPetOrGoods = lists:nth(Order, AfterValueList),
				  RandomPetCount = find_random_buy_pet(Ets_Pet_Extra,[ResultAllRandomPetOrGoods]),
				  %%RandomExpCount = find_random_exp_dan(ResultAllRandomPetOrGoods),
				  if (PetSplitSkillListLenth + RandomPetCount) > PET_MAX_GRID ->
						 4;
					 true ->
						 Status1 = lib_goods:cost_money(Status, TotalGoldNum, gold, 4106),
						 gen_server:cast(Status1#player.other#player_other.pid, {'SET_PLAYER', Status1}),
						 lib_player:send_player_attribute(Status1,2),
						 random_final_buy(Status1,[ResultAllRandomPetOrGoods]),
						 %%生成一条新的数据代替玩家刚刚购买的灵兽,并保持位置顺序(指定位置刷新)
						 [RandomPetOrGoods] = general_random_pet(Ets_Pet_Extra#ets_pet_extra.lucky_value,1),
						 handle_random_pet_5_step(Status#player.id,[RandomPetOrGoods]),
						 NewRandomPetOrGoods = util:replace_list_emement(AfterValueList,Order,RandomPetOrGoods),
						 NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   before_value = Ets_pet_extra_value#ets_pet_extra_value.after_value,
													  	   after_value = tool:to_binary(util:term_to_string(NewRandomPetOrGoods)),
													  	   order = Order,
													  	   ct = NowTime},
						 save_pet_extra_value(NewEts_pet_extra_value),
						 spawn(fun()-> update_pet_extra_value_db(NewEts_pet_extra_value) end),
						 1
				  end
		   end
	end.

%%最终购买处理(幸运值，经验值)
random_final_buy(Status,AllRandomPetOrGoods) ->
	Now = util:unixtime(),
	NameColor = data_agent:get_realm_color(Status#player.realm),
	F = fun([PetTypeId,Skill_Id,Step]) ->
				%%放在循环里面是确保Ets_Pet_Extra为最新数据
				Ets_Pet_Extra = lib_pet:get_pet_extra(Status#player.id),
				%%随机到技能经验丹
				if PetTypeId == 0 andalso Skill_Id == 0 ->
					   Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{skill_exp = Ets_Pet_Extra#ets_pet_extra.skill_exp + 20000*1,lucky_value = Ets_Pet_Extra#ets_pet_extra.lucky_value + ?PET_LUCKY_VALUE},
					   lib_pet:update_pet_extra(Ets_Pet_Extra1),
					   {ok,BinData} = pt_41:write(41038,[?PET_LUCKY_VALUE,20000*1]),
					   lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
					   %%添加日志
  			  		  spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(Status#player.id,0, <<>>, 20000, 11, Now)) end);
				   %%随机到灵兽,直接产生分离技能
				   true ->
						Auto_step = Ets_Pet_Extra#ets_pet_extra.auto_step,
						if Auto_step > 0 andalso Auto_step =< 4 andalso Step =< Auto_step -> %%符合自动萃取条件
							  StepSkillExp = data_pet:get_step_exp(Step),
							  Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{skill_exp = Ets_Pet_Extra#ets_pet_extra.skill_exp + StepSkillExp,lucky_value = Ets_Pet_Extra#ets_pet_extra.lucky_value + ?PET_LUCKY_VALUE},
							  lib_pet:update_pet_extra(Ets_Pet_Extra1),
							  {ok,BinData} = pt_41:write(41038,[?PET_LUCKY_VALUE,StepSkillExp]),
							  lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
							  %%添加日志
  			  		  		  spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(Status#player.id,0, <<>>, StepSkillExp, 11, Now)) end);
						   true ->%%生成新的分离技能
							   Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{lucky_value = Ets_Pet_Extra#ets_pet_extra.lucky_value + ?PET_LUCKY_VALUE},
							   lib_pet:update_pet_extra(Ets_Pet_Extra1),
							   {ok,BinData} = pt_41:write(41038,[?PET_LUCKY_VALUE,0]),
							   lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
							   %%产生新的分离技能
							   NewSkill = tool:to_binary(util:term_to_string([Skill_Id, 1, Step, 0])),
							   Id = db_agent:save_pet_split_skill(Status#player.id,0,NewSkill,Now),
							   PetSplitSkillInfo = #ets_pet_split_skill{id=Id,player_id=Status#player.id,pet_id=0,pet_skill=NewSkill,ct=Now},
							   update_pet_split_skill(PetSplitSkillInfo),
							   %%添加日志
						       spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(Status#player.id,0, <<>>, NewSkill, 9, Now)) end)
						end,
					   case Step of
						   0 -> SkillId = 0;
						   _-> SkillId = Skill_Id
					   end,
					   %%批量购买到4或5阶才全服广播
					    if
							Step == 4 ->
								Msg1 = io_lib:format("【<font color='~s'>~s</font>】含辛茹苦，终于获得<font color='#FEDB4F'>【~p阶~s】</font>！",[NameColor,Status#player.nickname,Step,data_pet:get_skill_name(SkillId)]),
								spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg1)end);
							Step == 5 ->
								%%活动送神兽蛋
								lib_act_interf:get_god_pet(Status#player.other#player_other.pid, Status#player.nickname, 1, data_pet:get_skill_name(SkillId)),
								lib_achieve:check_achieve_finish_cast(Status#player.other#player_other.pid, 529, [1]),%%获得第一个五阶灵兽技能
								Msg1 = io_lib:format("【<font color='~s'>~s</font>】十年一剑，感动上苍，终于获得<font color='#FEDB4F'>【~p阶~s】</font>！",[NameColor,Status#player.nickname,Step,data_pet:get_skill_name(SkillId)]),
								spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg1)end);
							true ->
								skip
					   end
				end	,
				Lukcy_value = 
					case Step == 5 of
						true -> 0;
						false ->
							?PET_LUCKY_VALUE
					end,
				db_agent:insert_random_pet_buy(Status#player.id,tool:to_binary(util:term_to_string([PetTypeId,Skill_Id,Step])),Lukcy_value)
		end,
	[F([PetTypeId,Skill_Id,Step]) ||[PetTypeId,Skill_Id,Step] <- AllRandomPetOrGoods].
	

%%查看随机灵兽面板中会有几只灵兽
find_random_buy_pet(Ets_Pet_Extra,AllRandomPetOrGoods) ->
	Auto_step = Ets_Pet_Extra#ets_pet_extra.auto_step,
	F = fun([PetTypeId,_Skill_Id,Step]) ->
				%%生成的是灵兽(可以在自动萃取范围内的不计算在灵兽内)
				if PetTypeId =/= 0 ->
					   if Auto_step > 0 andalso Auto_step =< 4 andalso Step =< Auto_step ->
							  0;
						  true ->
							  1
					   end;
					true ->
						0
				end
		end,
	lists:sum([F([PetTypeId,Skill_Id,Step]) ||[PetTypeId,Skill_Id,Step] <- AllRandomPetOrGoods]).

%%查看随机灵兽面板中会有几个技能经验丹
find_random_exp_dan(AllRandomPetOrGoods) ->
	F = fun([PetTypeId,_Skill_Id,_Step]) ->
				%%生成的是灵兽(可以在自动萃取范围内的不计算在灵兽内)
				if PetTypeId == 0 ->
					   1;
					true ->
						0
				end
		end,
	lists:sum([F([PetTypeId,Skill_Id,Step]) ||[PetTypeId,Skill_Id,Step] <- AllRandomPetOrGoods]).

%%查看随机灵兽面板中会有没有5阶灵兽，有则幸运值清0
handle_random_pet_5_step(Player_Id,AllRandomPetOrGoods) ->
	Ets_Pet_Extra = lib_pet:get_pet_extra(Player_Id),
	F = fun([_PetTypeId,_Skill_Id,Step]) ->
				%%生成的是灵兽(可以在自动萃取范围内的不计算在灵兽内)
				if Step == 5 ->
					   1;
					true ->
						0
				end
		end,
	Sum = lists:sum([F([PetTypeId,Skill_Id,Step]) ||[PetTypeId,Skill_Id,Step] <- AllRandomPetOrGoods]),
	if Sum > 0 ->
		   Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{lucky_value = 0},
		   lib_pet:update_pet_extra(Ets_Pet_Extra1),
		   Ets_Pet_Extra1;
		true ->
			Ets_Pet_Extra
	end.

%%自动萃取灵兽经验
auto_fetch_pet_exp(Status,PetId,Step) ->
	Ets_Pet_Extra = lib_pet:get_pet_extra(Status#player.id),
	Auto_step = Ets_Pet_Extra#ets_pet_extra.auto_step,
	%%设置了自动萃取
	if Auto_step > 0 andalso Auto_step =< 4 andalso Step =< Auto_step ->
		   %%加技能经验和放生灵兽
		   NewSkillExp = data_pet:get_step_exp(Step),
		   Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{skill_exp = Ets_Pet_Extra#ets_pet_extra.skill_exp + NewSkillExp},
		   lib_pet:update_pet_extra(Ets_Pet_Extra1),
		   {ok,BinData} = pt_41:write(41038,[0,NewSkillExp]),
		   lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
		   Msg=io_lib:format("萃取成功，灵兽消失。技能经验槽获得经验：~p",[NewSkillExp]),
		   {ok,MyBin} = pt_15:write(15055,[Msg]),
		   lib_send:send_to_sid(Status#player.other#player_other.pid_send,MyBin),
		   mod_pet:free_pet(Status, [PetId,3]);
	   %%没有设置自动萃取
	   true ->
		   skip
	end.

%%查询玩家的幸运值和经验槽经验值
query_lucky_exp(Player_Id) ->
	Ets_Pet_Extra = lib_pet:get_pet_extra(Player_Id),
	[Ets_Pet_Extra#ets_pet_extra.lucky_value,Ets_Pet_Extra#ets_pet_extra.skill_exp,Ets_Pet_Extra#ets_pet_extra.auto_step].

%%通过经验槽经验值提升技能等级
update_skill_level_by_exp(Status,Pet,Skill) ->
	Ets_Pet_Extra = lib_pet:get_pet_extra(Status#player.id),
	Skill_Order = lib_pet:find_pet_skill(Pet,Skill),
	[Skill_Id,Level,Step,SkillExp]  = util:string_to_term(tool:to_list(Skill)),
	NexpLevelExp = data_pet:get_pet_skill_exp(Level+1,Step),
	%%当技能经验超过下一级技能的时候升级不用经验槽的经验
	if SkillExp >= NexpLevelExp ->
		   %%不用经验槽的经验
		   NeedExp = 0,
		   NewSkill = util:term_to_string([Skill_Id,Level+1,Step,NexpLevelExp]);
	   true ->
		   %%需要用经验槽的经验
		   NeedExp = NexpLevelExp - SkillExp,
		   NewSkill = util:term_to_string([Skill_Id,Level+1,Step,NexpLevelExp])
	end,
	case Skill_Order of
		1 ->
			NewPet = Pet#ets_pet{skill_1 = tool:to_binary(NewSkill)};
		2 ->
			NewPet = Pet#ets_pet{skill_2 = tool:to_binary(NewSkill)};
		3 ->
			NewPet = Pet#ets_pet{skill_3 = tool:to_binary(NewSkill)};
		4 ->
			NewPet = Pet#ets_pet{skill_4 = tool:to_binary(NewSkill)};
		5 ->
			NewPet = Pet#ets_pet{skill_5 = tool:to_binary(NewSkill)};
		6 ->
			NewPet = Pet#ets_pet{skill_6 = tool:to_binary(NewSkill)};
		0 ->
			NewPet = Pet
	end,
	%%保存灵兽信息
	lib_pet:update_pet(NewPet),
	save_pet(NewPet),
	%%更新经验槽经验值
	if NeedExp > 0 ->
		   Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{skill_exp = Ets_Pet_Extra#ets_pet_extra.skill_exp - NeedExp},
		   {ok,BinData} = pt_41:write(41038,[0,-NeedExp]),
		   lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
		   lib_pet:update_pet_extra(Ets_Pet_Extra1);
	   true ->
		   skip
	end,
	1.
	
%%使用灵兽技能经验丹
use_random_exp_dan(Status,_GoodsTypeId,GoodsNum) ->
	Ets_Pet_Extra = lib_pet:get_pet_extra(Status#player.id),
	Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{skill_exp = Ets_Pet_Extra#ets_pet_extra.skill_exp + 20000*GoodsNum},
	lib_pet:update_pet_extra(Ets_Pet_Extra1),
	{ok,BinData} = pt_41:write(41038,[0,20000*GoodsNum]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData).

%%灵兽一键萃取所有闲置技能
fetch_all_split_skill(Status) ->
	PlayerId = Status#player.id,
	Ets_Pet_Extra = lib_pet:get_pet_extra(PlayerId),
	EtsSplitSkillList = get_all_split_skill(PlayerId),
	Now = util:unixtime(),
	if 
		EtsSplitSkillList == [] ->
		   2;%%没有可合成的闲置技能
		true ->
			F =fun(EtsSplitSkill) ->
					   Pet_skill = EtsSplitSkill#ets_pet_split_skill.pet_skill,
					   Id0 = EtsSplitSkill#ets_pet_split_skill.id,
					   Pet_id0 = EtsSplitSkill#ets_pet_split_skill.pet_id,
					   [SkillId0, SkillLevel0, SkillStep0, SkillExp0] = util:string_to_term(tool:to_list(Pet_skill)),
					   [Id0,Pet_id0,SkillId0, SkillLevel0, SkillStep0, SkillExp0]
			   end,
			ResultList = [F(EtsSplitSkill) || EtsSplitSkill <- EtsSplitSkillList],
			AllSplitSkillExp = sum_splitskill_exp(ResultList,0),
			PetSplitSkillIdList = [Id3|| [Id3,_Pet_id3,_SkillId3, _SkillLevel3, _SkillStep3, _SkillExp3] <- ResultList],
			%%删除内存中的所有闲置技能
			delete_all_pet_split_skill(PlayerId),
			%%删除数据库中指定id闲置技能
			delete_pet_split_skill(PetSplitSkillIdList),
			F5 = fun([_Id5,_Pet_id5,SkillId5, SkillLevel5, SkillStep5, SkillExp5],Skill5) ->
						 NewSkill5 = util:term_to_string(tool:to_list([SkillId5, SkillLevel5, SkillStep5, SkillExp5])),
						 lists:concat([Skill5,NewSkill5])
				 end,
			BeforeSkill = lists:foldl(F5, [], ResultList),
			spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(PlayerId,0, BeforeSkill, AllSplitSkillExp, 7, Now)) end),
			Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{skill_exp = Ets_Pet_Extra#ets_pet_extra.skill_exp + AllSplitSkillExp},
			lib_pet:update_pet_extra(Ets_Pet_Extra1),
			{ok,BinData} = pt_41:write(41038,[0,AllSplitSkillExp]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
			Msg=io_lib:format("萃取成功，闲置技能消失。技能经验槽获得经验：~p",[AllSplitSkillExp]),
			{ok,MyBin} = pt_15:write(15055,[Msg]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send,MyBin),
			1
	end.


%%修改原来的灵兽的技能格式为"[SkillId,Level,Exp,Step]"
change_pet_skill_format() -> 
	List = db_agent:query_all_pet(),
	case List of
		[] -> skip;
		_ ->
			PetList = [list_to_tuple([ets_pet]++PetInfo) || PetInfo <- List],
			F = fun(Pet) ->
						Level = Pet#ets_pet.level,
						Skill_1 =  Pet#ets_pet.skill_1,
						Skill_2 =  Pet#ets_pet.skill_2,
						Skill_3 =  Pet#ets_pet.skill_3,
						Skill_4 =  Pet#ets_pet.skill_4,
						Skill_5 =  Pet#ets_pet.skill_5,
						Skill_6 =  Pet#ets_pet.skill_6,
						%%原有技能转换时技能等级等于灵兽等级，阶数为4阶
						Step = 4,
						SkillExp = data_pet:get_pet_skill_exp(Level,Step),
						NewSkill_1 = 
							if 
								Skill_1 == "[0,0,0,0]" ->
									util:term_to_string([0,0,0,0]);
								Skill_1 > 0 -> 
									util:term_to_string([Skill_1,Level,Step,SkillExp]);
								true ->
									util:term_to_string([0,0,0,0])
							end,
						NewSkill_2 = 
							if 
								Skill_2 == "[0,0,0,0]" ->
									util:term_to_string([0,0,0,0]);
								Skill_2 > 0 ->
									util:term_to_string([Skill_2,Level,Step,SkillExp]);
								true ->
									util:term_to_string([0,0,0,0])
							end,
						NewSkill_3 = 
							if 
								Skill_3 == "[0,0,0,0]" ->
									util:term_to_string([0,0,0,0]);
								Skill_3 > 0 ->
									util:term_to_string([Skill_3,Level,Step,SkillExp]);
								true ->
									util:term_to_string([0,0,0,0])
							end,
						NewSkill_4 = 
							if 
								Skill_4 == "[0,0,0,0]" ->
									util:term_to_string([0,0,0,0]);
								Skill_4 > 0 ->
									util:term_to_string([Skill_4,Level,Step,SkillExp]);
								true ->
									util:term_to_string([0,0,0,0])
							end,
						NewSkill_5 = 
							if 
								Skill_5 == "[0,0,0,0]" ->
									util:term_to_string([0,0,0,0]);
								Skill_5 > 0 ->
									util:term_to_string([Skill_5,Level,Step,SkillExp]);
								true ->
									util:term_to_string([0,0,0,0])
							end,
						NewSkill_6 = 
							if 
								Skill_6 == "[0,0,0,0]" ->
									util:term_to_string([0,0,0,0]);
								Skill_6 > 0 ->
									util:term_to_string([Skill_6,Level,Step,SkillExp]);
								true ->
									util:term_to_string([0,0,0,0])
							end,
						db_agent:update_pet_skill(Pet#ets_pet.id,[NewSkill_1,NewSkill_2,NewSkill_3,NewSkill_4,NewSkill_5,NewSkill_6])
				end,
			[F(Pet) || Pet <- PetList]
	end.


%%修改原来的灵兽的技能经验=10*经验值
change_pet_skill_exp() -> 
	List = db_agent:query_all_pet(),
	case List of
		[] -> skip;
		_ ->
			PetList = [list_to_tuple([ets_pet]++PetInfo) || PetInfo <- List],
			F = fun(Pet) ->
						Skill_1 =  Pet#ets_pet.skill_1,
						Skill_2 =  Pet#ets_pet.skill_2,
						Skill_3 =  Pet#ets_pet.skill_3,
						Skill_4 =  Pet#ets_pet.skill_4,
						Skill_5 =  Pet#ets_pet.skill_5,
						Skill_6 =  Pet#ets_pet.skill_6,
						[SkillId1, SkillLevel1, SkillStep1, SkillExp1] = util:string_to_term(tool:to_list(Skill_1)),
						[SkillId2, SkillLevel2, SkillStep2, SkillExp2] = util:string_to_term(tool:to_list(Skill_2)),
						[SkillId3, SkillLevel3, SkillStep3, SkillExp3] = util:string_to_term(tool:to_list(Skill_3)),
						[SkillId4, SkillLevel4, SkillStep4, SkillExp4] = util:string_to_term(tool:to_list(Skill_4)),
						[SkillId5, SkillLevel5, SkillStep5, SkillExp5] = util:string_to_term(tool:to_list(Skill_5)),
						[SkillId6, SkillLevel6, SkillStep6, SkillExp6] = util:string_to_term(tool:to_list(Skill_6)),
						NewSkill_1 = 
						if
							SkillId1 == 0 ->
								util:term_to_string([SkillId1, SkillLevel1, SkillStep1, SkillExp1]);
							true ->
								util:term_to_string([SkillId1, SkillLevel1, SkillStep1, SkillExp1*10])
						end,
						NewSkill_2 = 
						if
							SkillId2 == 0 ->
								util:term_to_string([SkillId2, SkillLevel2, SkillStep2, SkillExp2]);
							true ->
								util:term_to_string([SkillId2, SkillLevel2, SkillStep2, SkillExp2*10])
						end,
						NewSkill_3 = 
						if
							SkillId3 == 0 ->
								util:term_to_string([SkillId3, SkillLevel3, SkillStep3, SkillExp3]);
							true ->
								util:term_to_string([SkillId3, SkillLevel3, SkillStep3, SkillExp3*10])
						end,
						NewSkill_4 = 
						if
							SkillId4 == 0 ->
								util:term_to_string([SkillId4, SkillLevel4, SkillStep4, SkillExp4]);
							true ->
								util:term_to_string([SkillId4, SkillLevel4, SkillStep4, SkillExp4*10])
						end,
						NewSkill_5 = 
						if
							SkillId5 == 0 ->
								util:term_to_string([SkillId5, SkillLevel5, SkillStep5, SkillExp5]);
							true ->
								util:term_to_string([SkillId5, SkillLevel5, SkillStep5, SkillExp5*10])
						end,
						NewSkill_6 = 
						if
							SkillId6 == 0 ->
								util:term_to_string([SkillId6, SkillLevel6, SkillStep6, SkillExp6]);
							true ->
								util:term_to_string([SkillId6, SkillLevel6, SkillStep6, SkillExp6*10])
						end,
						db_agent:update_pet_skill(Pet#ets_pet.id,[NewSkill_1,NewSkill_2,NewSkill_3,NewSkill_4,NewSkill_5,NewSkill_6])
				end,
			[F(Pet) || Pet <- PetList]
	end.
	
%%查询灵兽有多少技能达到指定的除数(包括相等或大于)
get_count_step_skill(Pet,Step) ->
	if 
		is_record(Pet,ets_pet) ->
			SLilllist = [util:string_to_term(tool:to_list(Pet#ets_pet.skill_1)),util:string_to_term(tool:to_list(Pet#ets_pet.skill_2)),util:string_to_term(tool:to_list(Pet#ets_pet.skill_3)),util:string_to_term(tool:to_list(Pet#ets_pet.skill_4)),util:string_to_term(tool:to_list(Pet#ets_pet.skill_5))],
			F = fun([_SkillId1, _SkillLevel1, SkillStep1, _SkillExp1]) ->
						%%生成的是灵兽(可以在自动萃取范围内的不计算在灵兽内)
						if SkillStep1 >= Step ->
							   1;
						   true ->
							   0
						end
				end,
			lists:sum([F([SkillId1, SkillLevel1, SkillStep1, SkillExp1]) ||[SkillId1, SkillLevel1, SkillStep1, SkillExp1] <- SLilllist]);
		true ->
			0
	end.
	
%%  灵兽神兽蛋预览	
egg_view(PlayerId) ->
	EggNum = goods_util:get_goods_num(PlayerId, 24800,4),
	Ets_Pet_Extra = lib_pet:get_pet_extra(PlayerId),
	Ets_pet_extra_value = get_pet_extra_value(PlayerId),
	[_New_PetTypeId,New_Skill_Id,New_Step] = 
		if
			EggNum =< 0 ->
				Ets_Pet_Extra1 = Ets_Pet_Extra,
				[0,0,0];%%物品不存在
			true ->%%有神兽蛋且没有随机生机灵兽技能的情况
				if Ets_pet_extra_value =/= [] ->
					   AfterValueList1 = util:string_to_term(tool:to_list(Ets_pet_extra_value#ets_pet_extra_value.after_value1)),
					   if AfterValueList1 == [] orelse AfterValueList1 == undefined ->
							  [[_PetTypeId,Skill_Id,Step]] = general_random_pet(Ets_Pet_Extra#ets_pet_extra.lucky_value,1),
							  %%开到5阶幸运人值清0
					   		  Ets_Pet_Extra1 = handle_random_pet_5_step(PlayerId, [[_PetTypeId,Skill_Id,Step]]),
							  NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   before_value1 = Ets_pet_extra_value#ets_pet_extra_value.after_value1,
													  	   after_value1 = tool:to_binary(util:term_to_string([[_PetTypeId,Skill_Id,Step]]))},
							  save_pet_extra_value(NewEts_pet_extra_value),
							  spawn(fun()-> update_pet_extra_value_db(NewEts_pet_extra_value) end),
							  [_PetTypeId,Skill_Id,Step];
						  true ->
							  Ets_Pet_Extra1 = Ets_Pet_Extra,
							  [_PetTypeId,Skill_Id,Step] = lists:flatten(AfterValueList1),
							  [_PetTypeId,Skill_Id,Step]
					   end;					   
				   true ->
					   AfterValueList = general_random_pet(Ets_Pet_Extra#ets_pet_extra.lucky_value,1),
					   %%开到5阶幸运人值清0
					   Ets_Pet_Extra1 = handle_random_pet_5_step(PlayerId,AfterValueList),
		   			   Id = db_agent:insert_random_pet(PlayerId,tool:to_binary(util:term_to_string([])),tool:to_binary(util:term_to_string([])),tool:to_binary(util:term_to_string([])),tool:to_binary(util:term_to_string([AfterValueList])),tool:to_binary(util:term_to_string([])),tool:to_binary(util:term_to_string([])),0,0),
		               Ets_pet_extra_value1 = #ets_pet_extra_value{
													 		id = Id,
													 		player_id = PlayerId,
															before_value = tool:to_binary(util:term_to_string([])),
													  	    after_value = tool:to_binary(util:term_to_string([])),
													  		before_value1 = tool:to_binary(util:term_to_string([])),
													  	    after_value1 = tool:to_binary(util:term_to_string([lists:flatten(AfterValueList)]))},
					   save_pet_extra_value(Ets_pet_extra_value1),
					   [[_PetTypeId,Skill_Id,Step]] = AfterValueList,
					   [_PetTypeId,Skill_Id,Step]
				end
	 end,
	[Ets_Pet_Extra1#ets_pet_extra.lucky_value,New_Skill_Id,New_Step,Ets_Pet_Extra1#ets_pet_extra.free_flush,?FREE_FLUSH_TIMES].

%% 神兽蛋获取技能Type 1为技能技取,2为萃取经验
fetch_egg_skill(Status,EggNum,Ets_Pet_Extra,Type) ->
	PlayerId = Status#player.id,
	Ets_pet_extra_value = get_pet_extra_value(PlayerId),
	AfterValueList1 = util:string_to_term(tool:to_list(Ets_pet_extra_value#ets_pet_extra_value.after_value1)),
	if AfterValueList1 == [] ->
		  {fail,4,Ets_Pet_Extra};%% 神兽蛋随机技能异常
	  true ->
		  Now = util:unixtime(),
		  %%扣除物品
		  Result = 
		  case gen_server:call(Status#player.other#player_other.pid_goods,{'DELETE_MORE_BIND_PRIOR',24800,1}) of 
			   1 ->
				   1;
			  Code ->
				  Code
		   end,
		  if Result == 1 ->
				%%产生新的分离技能
		  		[_PetTypeId,Skill_Id,Step] = lists:flatten(AfterValueList1),
				if _PetTypeId == 0 ->%%如果是经验丹,无论是获取技能还是萃取经验，都萃取成经验
					   Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{skill_exp = Ets_Pet_Extra#ets_pet_extra.skill_exp + 20000*1,lucky_value = Ets_Pet_Extra#ets_pet_extra.lucky_value + ?PET_LUCKY_VALUE},
					   {ok,BinData} = pt_41:write(41038,[?PET_LUCKY_VALUE,20000*1]);
				   true ->%%如果是技能,则区分获取技能和萃取经验
						NameColor = data_agent:get_realm_color(Status#player.realm),
					   %%批量购买到4或5阶才全服广播
					    if
							Step == 4 ->
								Msg1 = io_lib:format("【<font color='~s'>~s</font>】含辛茹苦，终于获得<font color='#FEDB4F'>【~p阶~s】</font>！",[NameColor,Status#player.nickname,Step,data_pet:get_skill_name(Skill_Id)]),
								spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg1)end);
							Step == 5 ->
								%%活动送神兽蛋
								lib_act_interf:get_god_pet(Status#player.other#player_other.pid, Status#player.nickname, 1, data_pet:get_skill_name(Skill_Id)),
								lib_achieve:check_achieve_finish_cast(Status#player.other#player_other.pid, 529, [1]),%%获得第一个五阶灵兽技能
								Msg1 = io_lib:format("【<font color='~s'>~s</font>】十年一剑，感动上苍，终于获得<font color='#FEDB4F'>【~p阶~s】</font>！",[NameColor,Status#player.nickname,Step,data_pet:get_skill_name(Skill_Id)]),
								spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg1)end);
							true ->
								skip
					   end,
					   if Type == 1 ->%%获取技能
							  Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{lucky_value = Ets_Pet_Extra#ets_pet_extra.lucky_value + ?PET_LUCKY_VALUE},
							  {ok,BinData} = pt_41:write(41038,[?PET_LUCKY_VALUE,0]),
							  %%产生新的分离技能
							  NewSkill = tool:to_binary(util:term_to_string([Skill_Id, 1, Step, 0])),
							  Id = db_agent:save_pet_split_skill(PlayerId,0,NewSkill,Now),
							  PetSplitSkillInfo = #ets_pet_split_skill{id=Id,player_id=PlayerId,pet_id=0,pet_skill=NewSkill,ct=Now},
							  update_pet_split_skill(PetSplitSkillInfo),
							  %%添加日志
		  			  		  spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(PlayerId,0, <<>>, NewSkill, 8, Now)) end);
						  true ->%%萃取经验
							  StepSkillExp = data_pet:get_step_exp(Step),
							  Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{skill_exp = Ets_Pet_Extra#ets_pet_extra.skill_exp + StepSkillExp,lucky_value = Ets_Pet_Extra#ets_pet_extra.lucky_value + ?PET_LUCKY_VALUE},
							  {ok,BinData} = pt_41:write(41038,[?PET_LUCKY_VALUE,StepSkillExp]),
							  %%添加日志
		  			  		  spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(PlayerId,0, <<>>, StepSkillExp, 10, Now)) end)
					   end
				end,
				lib_pet:update_pet_extra(Ets_Pet_Extra1),
				lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
				%%如果还有神兽蛋则继续产生随机技能
				if EggNum > 1 ->
					   %%产生新的随机技能
						[[_PetTypeId2,Skill_Id2,Step2]] = general_random_pet(Ets_Pet_Extra1#ets_pet_extra.lucky_value,1),
						handle_random_pet_5_step(PlayerId, [[_PetTypeId2,Skill_Id2,Step2]]),
						NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   before_value1 = Ets_pet_extra_value#ets_pet_extra_value.after_value1,
													  	   after_value1 = tool:to_binary(util:term_to_string([[_PetTypeId2,Skill_Id2,Step2]]))};
				   true ->
					   [[_PetTypeId2,Skill_Id2,Step2]] = [[0,0,6]],
					   NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   before_value1 = Ets_pet_extra_value#ets_pet_extra_value.after_value1,
													  	   after_value1 = tool:to_binary(util:term_to_string([]))}
				end,
				save_pet_extra_value(NewEts_pet_extra_value),
				spawn(fun()-> update_pet_extra_value_db(NewEts_pet_extra_value) end),
				{ok,[Ets_Pet_Extra1#ets_pet_extra.lucky_value,Skill_Id2,Step2,Ets_Pet_Extra1#ets_pet_extra.free_flush,?FREE_FLUSH_TIMES]};
			 true ->
				 {fail,5,Ets_Pet_Extra}%% 扣除神兽蛋异常
			end
	end.

%% 1神兽蛋面板免费刷新,2批量购买面板免费刷新,2批量购买面板批量元宝刷新
free_flush(Status,Ets_Pet_Extra,Order,Type,FlushCost) ->
	PlayerId = Status#player.id,
	Ets_pet_extra_value = get_pet_extra_value(PlayerId),
	Now = util:unixtime(),
	if FlushCost > 0 ->%%元宝刷新
			if Type == 3 -> %%批量购买元宝批量刷新
			   	   RandomPetOrGoods = general_random_pet_free(Ets_Pet_Extra#ets_pet_extra.lucky_value,6);
			   true ->
				   RandomPetOrGoods = general_random_pet_free(Ets_Pet_Extra#ets_pet_extra.lucky_value,1)
			end,						  
		   %%开到5阶幸运人值清0
		   Ets_Pet_Extra1 = handle_random_pet_5_step(PlayerId,RandomPetOrGoods),
		   Status1 = lib_goods:cost_money(Status, FlushCost, gold, 4109),
		   gen_server:cast(Status1#player.other#player_other.pid, {'SET_PLAYER', Status1}),
		   lib_player:send_player_attribute(Status1,2);
	   true ->%%免费刷新
		   RandomPetOrGoods = general_random_free(1),
		   Ets_Pet_Extra1 = Ets_Pet_Extra
	end,
	if Type == 1 ->%%神兽蛋面板刷新
			%%先删除物品再生成新的绑定物品
			%%gen_server:call(Status#player.other#player_other.pid_goods,{'DELETE_MORE_BIND_PRIOR',24800,1}),
			%%gen_server:call(Status#player.other#player_other.pid_goods, {'give_goods',Status,24800,1,2}),
			NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   before_value1 = Ets_pet_extra_value#ets_pet_extra_value.after_value1,
													  	   after_value1 = tool:to_binary(util:term_to_string(RandomPetOrGoods))};			
	   Type == 2 ->%%批量购买面板刷新
		    AfterValueList = util:string_to_term(tool:to_list(Ets_pet_extra_value#ets_pet_extra_value.after_value)),
		    [RandomPetOrGoods1] = RandomPetOrGoods,
			NewRandomPetOrGoods = util:replace_list_emement(AfterValueList,Order,RandomPetOrGoods1),
			NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   before_value = Ets_pet_extra_value#ets_pet_extra_value.after_value,
													  	   after_value = tool:to_binary(util:term_to_string(NewRandomPetOrGoods)),
													  	   order = Order,ct = Now};
	   true ->%%批量购买面板批量元宝刷新
			NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   before_value = Ets_pet_extra_value#ets_pet_extra_value.after_value,
													  	   after_value = tool:to_binary(util:term_to_string(RandomPetOrGoods)),
													  	   order = 6,ct = Now}
	end,
	save_pet_extra_value(NewEts_pet_extra_value),
	spawn(fun()-> update_pet_extra_value_db(NewEts_pet_extra_value) end),
	if FlushCost > 0 ->%%元宝刷新不计算次数
		   if Type == 3 -> %%批量购买元宝批量刷新
			   	   Ets_Pet_Extra2 = Ets_Pet_Extra1#ets_pet_extra{lucky_value = Ets_Pet_Extra1#ets_pet_extra.lucky_value + 6};
			   true ->
				   Ets_Pet_Extra2 = Ets_Pet_Extra1#ets_pet_extra{lucky_value = Ets_Pet_Extra1#ets_pet_extra.lucky_value + 1}
			end;	   
	   true ->%%免费刷新
		   Ets_Pet_Extra2 = Ets_Pet_Extra1#ets_pet_extra{lucky_value = Ets_Pet_Extra1#ets_pet_extra.lucky_value + 1,free_flush = Ets_Pet_Extra1#ets_pet_extra.free_flush+1}
	end,
	lib_pet:update_pet_extra(Ets_Pet_Extra2),		
	{ok,1}.



%%生成随机灵兽战斗技能
general_random_pet_batt_skill(Batt_lucky_value,Num) ->
	AllRandomPetOrGoods = [data_pet:get_random_batt_skill(Batt_lucky_value) || _ <- lists:seq(1, Num)],
	AllRandomPetOrGoods.


%%战魂石随机生成战斗技能预览	
batt_stone_view(PlayerId) ->
	Ets_Pet_Extra = lib_pet:get_pet_extra(PlayerId),
	Ets_pet_extra_value = get_pet_extra_value(PlayerId),
	if Ets_pet_extra_value =/= [] ->
		   AfterValueList1 = util:string_to_term(tool:to_list(Ets_pet_extra_value#ets_pet_extra_value.batt_after_value)),
		   if AfterValueList1 == [] orelse AfterValueList1 == undefined ->
				  [[Skill_Id]] =  general_random_pet_batt_skill(Ets_Pet_Extra#ets_pet_extra.batt_lucky_value,1),
				  NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   batt_before_value = Ets_pet_extra_value#ets_pet_extra_value.batt_after_value,
													  	   batt_after_value = tool:to_binary(util:term_to_string([[Skill_Id]]))},
				  save_pet_extra_value(NewEts_pet_extra_value),
				  spawn(fun()-> update_pet_extra_value_db(NewEts_pet_extra_value) end),
				  Skill_Id;
			  true ->
				  [Skill_Id] = lists:nth(length(AfterValueList1), AfterValueList1),
				  Skill_Id
		   end;
	   true ->
		   AfterValueList = general_random_pet_batt_skill(Ets_Pet_Extra#ets_pet_extra.batt_lucky_value,1),
		   Id = db_agent:insert_random_pet(PlayerId,tool:to_binary(util:term_to_string([])),tool:to_binary(util:term_to_string([])),tool:to_binary(util:term_to_string([])),tool:to_binary(util:term_to_string([])),tool:to_binary(util:term_to_string([])),tool:to_binary(util:term_to_string(AfterValueList)),0,0),
		   Ets_pet_extra_value1 = #ets_pet_extra_value{
													 		id = Id,
													 		player_id = PlayerId,
															before_value = tool:to_binary(util:term_to_string([])),
													  	    after_value = tool:to_binary(util:term_to_string([])),
													  		before_value1 = tool:to_binary(util:term_to_string([])),
													  	    after_value1 = tool:to_binary(util:term_to_string([])),
															batt_before_value = tool:to_binary(util:term_to_string([])),
															batt_after_value = tool:to_binary(util:term_to_string(AfterValueList))
															},
		   save_pet_extra_value(Ets_pet_extra_value1),
		   [[Skill_Id]] = AfterValueList,
		   Skill_Id
	end,
	[1,Ets_Pet_Extra#ets_pet_extra.batt_lucky_value,Skill_Id,Ets_Pet_Extra#ets_pet_extra.batt_free_flush].


%%查看战斗技能批量刷新面板	
get_batch_batt_skill_list(Player_Id) ->
	Ets_Pet_Extra = lib_pet:get_pet_extra(Player_Id),
	Ets_pet_extra_value = get_pet_extra_value(Player_Id),
	if Ets_pet_extra_value == [] -> [1,Ets_Pet_Extra#ets_pet_extra.batt_lucky_value,[]];
	   true ->
		   [1,Ets_Pet_Extra#ets_pet_extra.batt_lucky_value,util:string_to_term(tool:to_list(Ets_pet_extra_value#ets_pet_extra_value.batt_after_value))]
	end.

%%战斗技能刷新Type 1为战魂石免费刷新　2为战魂石元宝刷新　3为战魂石批量刷新 4为灵水刷新单个技能 5为灵水批量刷新技能
fluse_batt_skill(Status,_GoodsInfo,Ets_Pet_Extra,Type,Cost,NeedGoodsNum) ->
	PlayerId = Status#player.id,
	Ets_pet_extra_value = get_pet_extra_value(PlayerId),
	%%类型2,3扣元宝
	if Type == 2 ->
		   Status1 = lib_goods:cost_money(Status, Cost, gold, 4110),
		   gen_server:cast(Status1#player.other#player_other.pid, {'SET_PLAYER', Status1}),
		   lib_player:send_player_attribute(Status1,2);
	   Type == 3 ->
		   Status1 = lib_goods:cost_money(Status, Cost, gold, 4111),
		   gen_server:cast(Status1#player.other#player_other.pid, {'SET_PLAYER', Status1}),
		   lib_player:send_player_attribute(Status1,2);
	   true ->
		   skip
	end,
	%%类型4,5扣灵水物品
	if Type == 5->
		   gen_server:call(Status#player.other#player_other.pid_goods,{'DELETE_MORE_BIND_PRIOR',24025,NeedGoodsNum}),
		   Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{batt_lucky_value = Ets_Pet_Extra#ets_pet_extra.batt_lucky_value + 12},
		   AfterValueList = general_random_pet_batt_skill(Ets_Pet_Extra#ets_pet_extra.batt_lucky_value,12),
		   NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   batt_before_value = Ets_pet_extra_value#ets_pet_extra_value.batt_after_value,
													  	   batt_after_value = tool:to_binary(util:term_to_string(AfterValueList))};	
		Type == 4->
		  gen_server:call(Status#player.other#player_other.pid_goods,{'DELETE_MORE_BIND_PRIOR',24025,NeedGoodsNum}),
		  Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{batt_lucky_value = Ets_Pet_Extra#ets_pet_extra.batt_lucky_value + 1},
		  AfterValueList = general_random_pet_batt_skill(Ets_Pet_Extra#ets_pet_extra.batt_lucky_value,1),
		  NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   batt_before_value = Ets_pet_extra_value#ets_pet_extra_value.batt_after_value,
													  	   batt_after_value = tool:to_binary(util:term_to_string(AfterValueList))};
		Type == 3->
		   Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{batt_lucky_value = Ets_Pet_Extra#ets_pet_extra.batt_lucky_value + 12},
		   AfterValueList = general_random_pet_batt_skill(Ets_Pet_Extra#ets_pet_extra.batt_lucky_value,12),
		   NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   batt_before_value = Ets_pet_extra_value#ets_pet_extra_value.batt_after_value,
													  	   batt_after_value = tool:to_binary(util:term_to_string(AfterValueList))};		   
	  Type == 2 ->
		  Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{batt_lucky_value = Ets_Pet_Extra#ets_pet_extra.batt_lucky_value + 1},
		  AfterValueList = general_random_pet_batt_skill(Ets_Pet_Extra#ets_pet_extra.batt_lucky_value,1),
		  NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   batt_before_value = Ets_pet_extra_value#ets_pet_extra_value.batt_after_value,
													  	   batt_after_value = tool:to_binary(util:term_to_string(AfterValueList))};
	   true ->
		  %%类型1扣免费刷新次数
		  %%lib_goods:bind_goods(GoodsInfo),
		  %%gen_server:cast(Status#player.other#player_other.pid_goods, {'info_15000', GoodsInfo#goods.id, []})
		   Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{batt_lucky_value = Ets_Pet_Extra#ets_pet_extra.batt_lucky_value + 1,batt_free_flush = 1},
		   AfterValueList = general_random_pet_batt_skill(Ets_Pet_Extra#ets_pet_extra.batt_lucky_value,1),
		   NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
														   batt_before_value = Ets_pet_extra_value#ets_pet_extra_value.batt_after_value,
													  	   batt_after_value = tool:to_binary(util:term_to_string(AfterValueList))}
	end,
	save_pet_extra_value(NewEts_pet_extra_value),
	spawn(fun()-> update_pet_extra_value_db(NewEts_pet_extra_value) end),
	lib_pet:update_pet_extra(Ets_Pet_Extra1),
	Now = util:unixtime(),
	Skill1 = util:term_to_string(tool:to_list(Ets_pet_extra_value#ets_pet_extra_value.batt_after_value)),
	Skill2 = util:term_to_string(tool:to_list(NewEts_pet_extra_value#ets_pet_extra_value.batt_after_value)),
	spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(PlayerId,0, Skill1, Skill2, 12, Now)) end),
	[1,Type,Ets_Pet_Extra1#ets_pet_extra.batt_lucky_value,Ets_Pet_Extra1#ets_pet_extra.batt_free_flush,AfterValueList].

batt_skill_fetch(Status,GoodsInfo,Ets_pet_extra_value,Order) ->
	Ets_Pet_Extra = lib_pet:get_pet_extra(Status#player.id),
	%%扣除忆魂石
	case gen_server:call(Status#player.other#player_other.pid_goods,{'delete_one',GoodsInfo#goods.id,1}) of 
		[1,_] ->
			AfterValueList1 = util:string_to_term(tool:to_list(Ets_pet_extra_value#ets_pet_extra_value.batt_after_value)),
			if Order ==  0 ->
				   Order1 = 1;
			   true ->
				   Order1 = Order
			end,
			[Skill_Id] = lists:nth(Order1, AfterValueList1),
			%%给技能书
			lib_goods:give_pet_batt_skill_goods({Skill_Id, 1}, Status#player.id),			
			NewEts_pet_extra_value = Ets_pet_extra_value#ets_pet_extra_value{
										   batt_before_value = Ets_pet_extra_value#ets_pet_extra_value.batt_after_value,
										   batt_after_value = tool:to_binary(util:term_to_string([]))},
			save_pet_extra_value(NewEts_pet_extra_value),
			spawn(fun()-> update_pet_extra_value_db(NewEts_pet_extra_value) end),	
			Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{batt_lucky_value = 0},
			lib_pet:update_pet_extra(Ets_Pet_Extra1),
			1;
		[_Code,_] ->
			5
	end.

%%战斗技能学习 Type 1为学习新技能，2为升级技能
learn_batt_skill(Status,GoodsInfo,Pet,Type,Batt_skill,HasStudySkillId) ->
	case gen_server:call(Status#player.other#player_other.pid_goods,{'delete_one',GoodsInfo#goods.id,1}) of 
		[1,_] ->
			NewStatus = lib_goods:cost_money(Status,1000,coin,4101),
			%%给技能书
			SkillId = GoodsInfo#goods.goods_id,
			if Type == 1  ->
				   NewBatt_skill = util:term_to_string(Batt_skill++[SkillId]);
			   true ->
				   NewBatt_skill = util:term_to_string(lists:delete(HasStudySkillId, Batt_skill)++[SkillId])
			end,
			NewPet = Pet#ets_pet{batt_skill=tool:to_binary(NewBatt_skill)},
			Now = util:unixtime(),
			Skill1 = util:term_to_string(Batt_skill),
			Skill2 = util:term_to_string(NewBatt_skill),
			spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(Status#player.id,Pet#ets_pet.id, Skill1, Skill2, 13, Now)) end),
			%%更新灵兽信息
			lib_pet:update_pet(NewPet),
			save_pet(NewPet),
			[1,NewStatus];
		[_Code,_] ->
			[8,Status]
	end.

%%删除技能书
del_batt_skill(Status,GoodsInfo) ->
	case gen_server:call(Status#player.other#player_other.pid_goods,{'delete_one',GoodsInfo#goods.id,1}) of 
		[1,_] ->
			[17,Status];
		[_Code,_] ->
			[8,Status]
	end.

%%战斗技能遗忘
forget_batt_skill(Pet,Batt_skill,SkillId) ->
	NewBatt_skill = util:term_to_string(lists:delete(SkillId, Batt_skill)),
	NewPet = Pet#ets_pet{batt_skill=tool:to_binary(NewBatt_skill)},
	%%更新灵兽信息
	lib_pet:update_pet(NewPet),
	save_pet(NewPet),
	Now = util:unixtime(),
	Skill1 = util:term_to_string(Batt_skill),
	Skill2 = util:term_to_string(NewBatt_skill),
	spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(Pet#ets_pet.player_id,Pet#ets_pet.id, Skill1, Skill2, 14, Now)) end),
	1.

%%战斗技能封印(将灵兽战斗技能转换为技能书)
transfer_batt_skill(Status,Pet,Batt_skill,SkillId,StoneType) ->
	case gen_server:call(Status#player.other#player_other.pid_goods,{'DELETE_MORE_BIND_PRIOR',StoneType,1}) of 
		1 ->
			NewBatt_skill = util:term_to_string(lists:delete(SkillId, Batt_skill)),
			NewPet = Pet#ets_pet{batt_skill=tool:to_binary(NewBatt_skill)},
			%%更新灵兽信息
			lib_pet:update_pet(NewPet),
			save_pet(NewPet),
			lib_goods:give_pet_batt_skill_goods({SkillId, 1}, Status#player.id),
			Now = util:unixtime(),
			Skill1 = util:term_to_string(Batt_skill),
			Skill2 = util:term_to_string(NewBatt_skill),
			spawn(fun()->catch(db_agent:insert_log_pet_skill_oper(Pet#ets_pet.player_id,Pet#ets_pet.id, Skill1, Skill2, 15, Now)) end),
			1;
		_Code ->
			6
	end.


	
test1() ->
	lib_goods:give_pet_batt_skill_goods({24215, 1}, 1).


	
	