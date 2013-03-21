%%%--------------------------------------
%%% @Module  : lib_goods_use
%%% @Author  : ygzj
%%% @Created : 2010.12.15
%%% @Description : 物品使用类 
%%%--------------------------------------
-module(lib_goods_use).
-include("common.hrl").
-include("record.hrl").
-include("hot_spring.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-compile(export_all).

%%节日道具使用检查
check_festivaltool(Player,GoodsStatus,GoodsId,GoodsNum,Nickname) ->
	GoodsInfo = goods_util:get_goods(GoodsId),
	if
		Player#player.hp =< 0 ->
			{fail,0};%%角色死亡
		is_record(GoodsInfo,goods) == false ->
			{fail,2};%%物品不存在
		GoodsInfo#goods.player_id /= GoodsStatus#goods_status.player_id ->
			{fail,3};%%物品不属于你
		GoodsInfo#goods.location /= 4 ->
			{fail,4};%%物品不在背包
		GoodsInfo#goods.num < GoodsNum ->
			{fail,5};%%物品数量不足
		true ->
			%%新年烟花
			IsFireWork = lists:member(GoodsInfo#goods.goods_id, [28014,28015,28016,28017]),
			IsValentine = lists:member(GoodsInfo#goods.goods_id,[28018,28019,28020]),
			IsMonTrans = lists:member(GoodsInfo#goods.goods_id, [28056]),
			case IsFireWork orelse IsValentine orelse IsMonTrans of
				true ->
					To_id = lib_player:get_role_id_by_name(Nickname),
					if
						To_id /= null andalso To_id /=[] ->
							case lib_player:get_online_info_fields(To_id,[scene,x,y,pid,turned]) of
								[Scene,X,Y,To_Pid, ToTurned] ->
									if
										IsFireWork -> 
											Type = 1,
											{ok,GoodsInfo,[Type,To_id,To_Pid,Scene,X,Y,Nickname]};
										IsValentine -> %%2情人节玫瑰
											Type = 2,
											{ok,GoodsInfo,[Type,To_id,To_Pid,Scene,X,Y,Nickname]};
										IsMonTrans -> %%3怪物变身卡
											Type = 3,
											case ToTurned =/= 0 of
												true ->
													{fail,11};%% 10目标已经变身了
												false ->
													{ok,GoodsInfo,[Type,To_id,To_Pid,Scene,X,Y,Nickname]}
											end;
										true -> 
											Type = 0,
											{ok,GoodsInfo,[Type,To_id,To_Pid,Scene,X,Y,Nickname]}%%1其他
									end;
								[] ->
			%%						?DEBUG("1111the player name is unexist:~p", [To_id]),
									{fail,7}%% 7目标玩家不在线 
							end;
						true ->
							if
								IsMonTrans ->
									Type = 3,
									case get_random_online_player(Player#player.id) of
										[] ->%%没有合适的玩家
											{fail, 12};
										{ToPlayerId, ToPid, PName, Scene, X, Y} ->
											{ok,GoodsInfo,[Type,ToPlayerId,ToPid,Scene,X,Y,PName]}
									end;
								true ->
			%%						?DEBUG("2222the player name is unexist:~p", [To_id]),
									{fail,10}%% 10 目标玩家不存在
							end
					end;
				false ->
					{fail,6}
			
			end
		end.

%%物品使用检查
check_use(PlayerStatus,GoodsStatus, GoodsId, GoodsNum) ->  
    GoodsInfo = goods_util:get_goods(GoodsId),
	CD = check_use_cd(GoodsStatus,GoodsInfo),
	TimeLimit = check_time_limit(GoodsInfo),
    if
		%%人物死亡
		PlayerStatus#player.hp =< 0 ->
			{fail,0};
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= GoodsStatus#goods_status.player_id ->
            {fail, 3};
        %% 物品不在背包
        GoodsInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品数量不正确
        GoodsInfo#goods.num < GoodsNum ->
            {fail, 6};
		GoodsNum =< 0 ->
			{fail,6};
        %% 冷却时间
        CD > 0 ->
           {fail, 7};
		%%物品过期
		TimeLimit == false ->
			{fail,35};
        %% 人物等级不足
        GoodsInfo#goods.level > PlayerStatus#player.lv ->
            {fail, 8};
        true ->
			%%数目限制判断
			CounterCheck = check_num_use(PlayerStatus#player.id, GoodsInfo),
			if 
				CounterCheck  =:= true ->%%超过使用次数 
					{fail, 24};
				true ->
					%%物品类型检查
			case [GoodsInfo#goods.type,GoodsInfo#goods.subtype] of
				%%仙玉
				[15,16] ->
					if
						GoodsInfo#goods.goods_id == 21601 ->
							{ok,GoodsInfo};
						GoodsInfo#goods.goods_id == 21603 ->
							{ok,GoodsInfo};
						true ->
							{fail,5}
					end;
				[25, 15] ->%%修为类
					IsCulture = lists:member(GoodsInfo#goods.goods_id,[28012, 23503, 23502, 23501,23500]),%%修为丹
					if
						IsCulture ->
							{ok, GoodsInfo};
						true ->
							{2, GoodsInfo}
					end;
				%%药品类
				[25, GoodsSubType] ->
					%% 竞技场不能使用血药
					case GoodsSubType == 10 andalso lib_coliseum:is_coliseum_scene(PlayerStatus#player.scene) of
						false ->
							%% 药品有长cd
							CDList = [23409, 23410, 23411, 23000,23001,23002,23100,23101,23102,23009,23109,23013,23014,23203,23306],
							case lists:member(GoodsInfo#goods.goods_id, CDList) of
								true ->
									case lib_goods:cd_check(PlayerStatus,GoodsInfo) of
										{ok,_} ->
											case lists:member(GoodsInfo#goods.goods_id, [23409, 23410, 23411]) of
												true ->%%只针对蟠桃进行判断
													case lib_peach:check_peach_use(GoodsInfo#goods.goods_id, PlayerStatus) of
														ok ->
															{ok, GoodsInfo};
														{fail, Res} ->
															{fail, Res}
													end;
												false ->%%直接跳过检查
													{ok, GoodsInfo}
											end;
										{fail} ->
											{fail,7}
									end;
								false ->
									{ok, GoodsInfo}
							end;
						true ->
							{fail, 73}
					end;
				%%灵兽食物类
				[30,10] ->
					if
						GoodsInfo#goods.goods_id =:= 24000 ->%%灵兽口粮
							Pet = lib_pet:get_out_pet(PlayerStatus#player.id),
							if
								is_record(Pet,ets_pet) =:= false ->
									{fail,11};
								true ->
									{ok,GoodsInfo}
							end;
						true ->
							{ok,GoodsInfo}
					end;
				%%灵兽成长类
				[30,11] -> 
					Pet = lib_pet:get_out_pet(PlayerStatus#player.id),
					if
						GoodsInfo#goods.goods_id =:= 24100 ->%%升级果						
							if
								is_record(Pet,ets_pet) =:= false ->
									{fail,11};
								true ->
									MaxExp = data_pet:get_upgrade_exp(Pet#ets_pet.level),
									if
										Pet#ets_pet.level < 15 ->
											{fail,17};
										Pet#ets_pet.exp =/= MaxExp ->
											{fail,18};
										true ->
											{ok,GoodsInfo}
									end
							end;
						GoodsInfo#goods.goods_id =:= 24101 ->%%洗点
							if
								is_record(Pet,ets_pet) =:= false ->
									{fail,11};
								true ->
									{ok,GoodsInfo}
							end;
						GoodsInfo#goods.goods_id =:= 24106 -> %%化形
							case mod_pet:judge_pet_chenge(PlayerStatus) of
								{fail,Error}->{fail,Error};
								_->{ok,GoodsInfo}
							end;
						true ->
							{ok,GoodsInfo}
					end;
				%%灵兽技能类
				[30,12] ->
					case mod_pet:check_learn_skill(GoodsStatus#goods_status.player_id,GoodsInfo#goods.goods_id) of
						{ok,_SkillId} ->
							{ok,GoodsInfo};
						{fail,Code} ->
							case Code of
								1 -> {fail,9};%%灵兽分离技能已满
								2 -> {fail,10};%%灵兽技能已学习
								3 -> {fail,11};%%没有出战的灵兽
								4 -> {fail,16};%%灵兽资质不够
								5-> {fail,20};%%灵兽等级不足
								6 -> {fail,39};%%未化形并且资质不到65
								_ -> {fail, 0}
							end
					end;
				%%灵兽变身卡
				[30,15] ->
					Pet = lib_pet:get_out_pet(PlayerStatus#player.id),
					if
						is_record(Pet,ets_pet) =:= false ->
							{fail,11};
						GoodsInfo#goods.goods_id =/= 24509 andalso Pet#ets_pet.chenge == 2 ->
							{fail,71};
						true ->
							{ok,GoodsInfo}
					end;
				%%捕兽索
				[30,17] ->
					Pet = lib_pet:get_out_pet(PlayerStatus#player.id),
					if
						is_record(Pet,ets_pet) =:= false ->
							{fail,11};
						true ->
							{ok,GoodsInfo}
					end;
				%%神兽蛋
				[30,18] ->
					PetIsFull = mod_pet:check_pet_is_full(PlayerStatus#player.id), 
					GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
					if
						PetIsFull == true ->
							{fail,50}; %%灵兽栏已满
						is_record(GoodsTypeInfo,ets_base_goods) ->
							NullcellsNum = length(GoodsStatus#goods_status.null_cells),
							case NullcellsNum >= 1 of
								true ->
									{ok,GoodsInfo};
								false ->
									{fail,19} %%背包空间不足
							end;
						true ->
							{fail,2}
					end;
				[30,20] ->
					ResultMountType = data_mount:get_mount_type_id(GoodsInfo#goods.goods_id),
					if PlayerStatus#player.mount =< 0 ->
						  {fail,58};%% 没有坐骑 
						ResultMountType == 0 ->
						  {fail,74};%%没有对应的坐骑类型
						%%GoodsInfo#goods.icon == 16011 ->
						 %% {fail,76};%%没有对应的坐骑类型
						true ->
							Mount = lib_mount:get_mount(PlayerStatus#player.mount),
							if is_record(Mount,ets_mount) andalso Mount#ets_mount.icon == ResultMountType->
								 {fail,75};%%您的坐骑已经是此种类型　
							  is_record(Mount,ets_mount) andalso Mount#ets_mount.icon == 0 andalso Mount#ets_mount.goods_id == ResultMountType->
								 {fail,75};%%您的坐骑已经是此种类型
								true ->
									{ok, GoodsInfo}	
							end
					end;
				%%技能书
				[40,10] ->
					case lib_skill:check_skill(PlayerStatus,GoodsInfo#goods.goods_id) of
						{fail,Code} ->
							case Code of
								2 -> {fail,13};%%技能已学习
								3-> {fail,14};%%技能学习条件不足
								4 -> {fail,15} %%技能不存在
							end;
						{ok} ->
							{ok,GoodsInfo}
					end;
				%%礼包类 
				[80,11] ->
					GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
					if
						is_record(GoodsTypeInfo,ets_base_goods) ->
							GiftList = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data,gift),
							GiftNum = length(GiftList),
							NullcellsNum = length(GoodsStatus#goods_status.null_cells),
							case NullcellsNum >= GiftNum of
								true ->
									{ok,GoodsInfo};
								false ->
									{fail,19} %%背包空间不足
							end;
						true ->
							{fail,2}
					end;
				%%随机礼包,黄金月饼
				[80,18] ->
					GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
					if
						is_record(GoodsTypeInfo,ets_base_goods) ->
							NullcellsNum = length(GoodsStatus#goods_status.null_cells),
							case NullcellsNum >= 1 of
								true ->
									{ok,GoodsInfo};
								false ->
									{fail,19} %%背包空间不足
							end;
						true ->
							{fail,2}
					end;
				%%新随机礼包 物品的绑定属性根据礼包绑定状态而定,火鸡
				[80,19] ->
					%%?DEBUG("GoodsTypeId:~p", [GoodsInfo#goods.goods_id]),
					GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
					if
						is_record(GoodsTypeInfo,ets_base_goods) ->
							NullcellsNum = length(GoodsStatus#goods_status.null_cells),
							case NullcellsNum >= 1 of
								true ->
									{ok,GoodsInfo};
								false ->
									{fail,19} %%背包空间不足
							end;
						true ->
							{fail,2}
					end;				
				%%传送类
				[80,12] ->
					CanNotUse = lists:member(GoodsInfo#goods.goods_id, [28201]),%%筋斗云
					if
						CanNotUse ->
							{fail,5};
						true ->
							case lib_goods:cd_check(PlayerStatus,GoodsInfo) of
								{ok,_} ->
									{ok,GoodsInfo};
								{fail} ->
									{fail,7}
							end
					end;
				[80,14] ->%%帮会道具
					IsGuildSkillToken = lists:member(GoodsInfo#goods.goods_id ,[28302, 28303]),%%氏族弹劾令，氏族技能令
					if
						IsGuildSkillToken ->
							if
								PlayerStatus#player.guild_id > 0 ->
									{ok, GoodsInfo};
								true ->
									{fail,30}
							end;
						true ->
							{fail,5}
					end;
				[80,13]->
					case lists:member(GoodsInfo#goods.goods_id,[28405,28403]) of
						true->{ok,GoodsInfo};
						false->{fail,5}
					end;
				%%vip卡类
				[80,16]->
					IsVIPCard = lists:member(GoodsInfo#goods.goods_id, [28600,28601,28602,28603,28604,28605]),
					if IsVIPCard ->
						   case check_vip_state(PlayerStatus,GoodsInfo#goods.goods_id) of
							   true->{ok,GoodsInfo};
							   false->{fail,52}
						   end;
					   true->{fail,5}
					end;
				%%和平运镖令
				[80,15]->
					IsPeaceCarry = lists:member(GoodsInfo#goods.goods_id, [28506]),
					if IsPeaceCarry -> 
						   case PlayerStatus#player.carry_mark > 0 andalso PlayerStatus#player.carry_mark <4 orelse (PlayerStatus#player.carry_mark >=20 andalso PlayerStatus#player.carry_mark<26) of
							   false->{fail,32};
							   true->
								   case PlayerStatus#player.carry_mark =:= 3 of
										true->{fail,33};
									   false->
								  		 case PlayerStatus#player.pk_mode =:= 1 of
											   true->{fail,31};
											   false->{ok,GoodsInfo}
										   end
								   end
						   end;
					   true->{fail,5}
					end;
				%%封神贴
				[80,20]->
					case lists:member(GoodsInfo#goods.goods_id,lib_goods:get_hero_card_list()) of
						true->
							case lib_hero_card:check_hero_card_use(PlayerStatus,GoodsInfo#goods.goods_id) of
								ok->{ok,GoodsInfo};
								{fail,ErrorCode}->
									{fail,ErrorCode}
							end;
						false->{fail,5}
					end;
				%%副本令
				[80,22]->
					case lists:member(GoodsInfo#goods.goods_id,lib_goods:get_dungeon_card_list()) of
						true->
							case catch gen_server:call(PlayerStatus#player.other#player_other.pid_task,{'check_dungeon_card_task_state',[PlayerStatus,GoodsInfo#goods.goods_id]}) of
								{false,Error}->
									{fail,Error};
								{true,1}->
									{ok,GoodsInfo};
								_->{fail,5}
							end;
						false->
							{fail,5}
					end;
				%% 其他 活动
				[80, 21] ->
					case lists:member(GoodsInfo#goods.goods_id,[31201,31202]) of %%月饼和黄金钥匙
						true->
							GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
							if
								is_record(GoodsTypeInfo,ets_base_goods) ->
									NullcellsNum = length(GoodsStatus#goods_status.null_cells),
									if NullcellsNum < 1 andalso GoodsInfo#goods.goods_id =:= 31202 ->
										   {fail,19}; %%黄金钥匙会生成物品，所以要判断空间，背包空间不足
									   true ->
										   {ok,GoodsInfo}
									end;
								true ->
									{fail,2}
							end;
						false->
							case lists:member(GoodsInfo#goods.goods_id,[31204]) of %%吉祥兔飞升丹
								true ->
									case length(goods_util:get_type_goods_list(PlayerStatus#player.id,16002,4)) > 0 of
										true ->
											{ok,GoodsInfo};
										false ->
											{fail,48}
									end;
								false ->
									case lists:member(GoodsInfo#goods.goods_id, [31203,31214,31215]) of %%中秋时装变化券\感恩时装变身券\时装升级券
										true ->
											case goods_util:get_cell_equip(PlayerStatus#player.id,13) of
												{} ->%% 身上没有穿戴时装
													{fail,49};
												_Fl ->
													{ok,GoodsInfo}
											end;
										false ->
 											%%国庆快乐物品，南瓜馅饼，鸡腿，远古大转盘，汤圆，希望之种,彩灯,诺亚方舟船票,如意面条,如意鸡蛋,如意饺子,小福袋,木之灵,马兰花,雨花石
											case lists:member(GoodsInfo#goods.goods_id,[31207,31208,31209,31210, 31213, 31212, 31229, 31232, 31233,31219, 
																						31220, 31221, 31222, 31223, 31231, 31234, 31235, 31236]) of 
												true ->
													{ok,GoodsInfo};
												false ->
															case lists:member(GoodsInfo#goods.goods_id,[31211]) of%%火种
																true ->
																	GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
																	if
																		is_record(GoodsTypeInfo,ets_base_goods) ->
																			NullcellsNum = length(GoodsStatus#goods_status.null_cells),
																			if NullcellsNum < 1 ->
																				   {fail,19}; %%火种会生成物品，所以要判断空间，背包空间不足
																			   true ->
																				 {ok, GoodsInfo}
																			end;
																		true ->
																			{fail,2}%%物品数据有问题
																	end;
																false -> 
																	case lists:member(GoodsInfo#goods.goods_id,[28048]) of%%冰炎石
																		true ->
																			case PlayerStatus#player.mount =< 0 of
																				true ->%% 没有坐骑
																					{fail,58};
																				false ->
																					GoodsInfo1 = goods_util:get_goods(PlayerStatus#player.mount),
																					Is_Turn_Type = lists:member(GoodsInfo1#goods.goods_id, [16004,16005]),
																					if GoodsInfo1 == [] orelse Is_Turn_Type =/= true ->
																						   {fail,60};
																					   true ->
																						   {ok, GoodsInfo}
																					end
																			end;
																		false ->
																			{fail,5}
																	end
															end
											end
									end
							end
					end;

				%%其他类的铜币卡,功德丸,奇异果,秘境令(新增秘境令牌),小礼券
				[80,10] ->
					IsMoneyCard = lists:member(GoodsInfo#goods.goods_id, [28000,28001,28002,28021,28022,28023,28039,28041]),
					IsMeritPill = lists:member(GoodsInfo#goods.goods_id,[28007,28008]),
					IsKiwifruit = lists:member(GoodsInfo#goods.goods_id,[28025,28026,28027]),
					IsSecretToken = lists:member(GoodsInfo#goods.goods_id,[28028,28029,28030, 28031]),
					IsCashTicket = lists:member(GoodsInfo#goods.goods_id, [28024,28053]),
					IsEventGoods = lists:member(GoodsInfo#goods.goods_id,[28032]),%%粽叶
					IsTurned = lists:member(GoodsInfo#goods.goods_id,[28043,28045,31216,28047]),
					IsGoleCard = lists:member(GoodsInfo#goods.goods_id,[28044]),
					IsChrMount = lists:member(GoodsInfo#goods.goods_id,[31217]),
					IsChrPet = lists:member(GoodsInfo#goods.goods_id,[31218]),
					IsMountTured = lists:member(GoodsInfo#goods.goods_id,[28048]),
					IsFireWorks = lists:member(GoodsInfo#goods.goods_id,[28049,28050,28051]),
					IsDivorce = lists:member(GoodsInfo#goods.goods_id,[28046]),
					IsWarHonor = lists:member(GoodsInfo#goods.goods_id,[28054]),
					
					if 
						IsMoneyCard orelse IsKiwifruit orelse IsCashTicket orelse IsEventGoods orelse IsGoleCard orelse IsWarHonor->
							{ok,GoodsInfo};
						IsTurned ->					
							%%变身符场景限制
							 case lib_spring:is_spring_scene(PlayerStatus#player.scene) of
												   false->
													   case lib_marry:is_wedding_love_scene(PlayerStatus#player.scene) of
														   false ->
															   {ok, GoodsInfo};
														   true ->
															    {fail,26}
													   end;
												   true ->
													   {fail,26}
							 end;
						%%圣诞时装
%% 						IsChrFash == true ->
%% 							case goods_util:get_cell_equip(PlayerStatus#player.id,13) of
%% 								{} ->%% 身上没有穿戴时装
%% 									{fail,49};
%% 								_Fl ->
%% 									{ok,GoodsInfo}
%% 							end;
						%%圣诞坐骑
						IsChrMount == true ->
							case PlayerStatus#player.mount =< 0 of
								true ->%% 没有坐骑
									{fail,58};
								false ->
									{ok,GoodsInfo}
							end;
						IsMountTured == true ->
							case PlayerStatus#player.mount =< 0 of
								true ->%% 没有坐骑
									{fail,58};
								false ->
									{ok,GoodsInfo}
							end;
						%%圣诞灵兽
						IsChrPet == true ->
							case lib_pet:get_out_pet(PlayerStatus#player.id) == [] of
								true ->%% 没有出战灵兽
									{fail,59};
								false ->
									{ok,GoodsInfo}
							end;
%% 							GoodsBuffs = lib_goods:get_player_goodsbuffs(),
%% 							F = fun(GoodsBuff) ->
%% 										{EBuffGid, _EData, _EExpireTime} = GoodsBuff,
%% 										if (GoodsInfo#goods.goods_id =:= 28043 andalso EBuffGid =:= 28045)
%% 											 orelse (GoodsInfo#goods.goods_id =:= 28045 andalso EBuffGid =:= 28043)->
%% 											    {fail,34};
%% 										   true->
%% 											   case lib_spring:is_spring_scene(PlayerStatus#player.scene) of
%% 												   false->
%% 													   {ok, GoodsInfo};
%% 												   true ->
%% 													   {fail,26}
%% 											   end								
%% 										end 
%% 								end,
%% 							lists:map(F,GoodsBuffs);				
						IsSecretToken -> %%秘境令有数量限制
							case lib_box_scene:time_check(PlayerStatus) of
								ok ->
									{ok, GoodsInfo};
								{fail, RetType} ->
									{fail, RetType}
							end;
						IsMeritPill ->%%功德丸有cd
							case lib_goods:cd_check(PlayerStatus,GoodsInfo) of
								{ok,_} ->
									{ok,GoodsInfo};
								{fail} ->
									{fail,7}
							end;
						IsFireWorks ->
							case lib_marry:is_wedding_love_scene(PlayerStatus#player.scene) of
								true ->
									{ok,GoodsInfo};
								false ->
									{fail,26}
							end;
						IsDivorce ->
							case lib_marry:check_can_divorce(PlayerStatus,1) of
								{false,Code} ->
									{fail,Code};
								{true,_} ->
									{ok,GoodsInfo}
							end;
						true ->
							{fail,5}
					end;
				%%神器类
				[83,10] ->
					case lists:member(GoodsInfo#goods.goods_id, [32000]) of %%神器技能
						true ->
							case lib_deputy:check_add_deputy_equip(PlayerStatus#player.id) of
								ok ->
									{ok,GoodsInfo};
								fail ->
									{fail,5}
							end;
						false ->
							{fail,5}
					end;
				[83,11] ->
					case lists:member(GoodsInfo#goods.goods_id,[32026]) of %%熟练丹
						true -> 
							case lib_deputy:check_add_deputy_equip(PlayerStatus#player.id) of %%借助检查是否有神器的方法
								fail -> 
									{ok,GoodsInfo};
								ok ->
									{fail,63}
							end;
						false ->
								case GoodsInfo#goods.goods_id == 32055 of
									true ->
										case lib_deputy:checkDownDeputyStep(PlayerStatus#player.id) of %%潜能降低
											{fail,Code} ->
												{fail,Code};
											{ok,1}->
												{ok,GoodsInfo}
										end;
									false ->
										{fail,5}
								end
					end;		
				_ ->
					{fail,5}
			end
			end
    end.

%%这个是防刷的基础cd 
check_use_cd(GoodsStatus,GoodsInfo) ->
	 		NowTime = util:unixtime(),
	 				F = fun(TL,Flag) ->
				 		[Type,Subtype,Time] = TL,
				 		if
					 		GoodsInfo#goods.type == Type andalso GoodsInfo#goods.subtype == Subtype andalso NowTime < Time ->
						 		Flag + 1;
					 		true ->
						 		Flag
				 		end
		 		end,
	 		lists:foldl(F,0,GoodsStatus#goods_status.cd_list).

%%使用时间限制
check_time_limit(GoodsInfo) ->
	NowTime = util:unixtime(),
	if
		%%劳动光荣礼包
		GoodsInfo#goods.goods_id == 28700 andalso NowTime > 1304524799 -> %%5月4日前时间戳
			false;
		true ->
			true
	end.

%%物品数量限制检查
check_num_use(PlayerId, GoodsInfo) ->
	[Type, NumLimit] = get_check_type(GoodsInfo#goods.goods_id),
	Now = util:unixtime(),
	case NumLimit =:= 0 of
		true ->%%不做数量的限制
			false;
		false ->
			case get(Type) of
				undefined ->
					case db_agent:get_use_numtime(log_goods_counter, PlayerId, Type) of
						[] ->
							false;
						[Num, FinalTime] ->
							check_num_use_1(Type, NumLimit, Now, FinalTime, Num)
					end;
				Value ->
					{Num, FinalTime} = Value,
					check_num_use_1(Type, NumLimit, Now, FinalTime, Num)
			end
	end.
							   
check_num_use_1(Type, NumLimit, Now, FinalTime, Num) ->
	IsOneDay = util:is_same_date(Now, FinalTime),%%判断是否同一天
	if
		IsOneDay =/= true ->%%不同一天，需要更新数目
			put(Type, {0, Now}),
			false;
		Num >= NumLimit  andalso IsOneDay ->%%同一天，超过4个了
			put(Type, {Num, FinalTime}),
			true;
		true ->%%同一天，未超过数目的
			put(Type, {Num, Now}),
			false
	end.
				
get_check_type(GoodsTypeId) ->
	PeachType = lists:member(GoodsTypeId, [23409, 23410,23411]),%%蟠桃
	if 
		PeachType =:= true ->
			[1, ?PEACH_NUM_LIMIT];
			%%测试
%% 			[1, 100];
		true ->
			[GoodsTypeId, 0]
	end.
						   
						   

%%物品使用
use_goods(PlayerStatus, Status, GoodsInfo, GoodsNum, GoodsBuffs) ->
	%%药品类型使用添加CD
	%%return record() #goods_status{} ----xiaomai
	Status1 = add_goods_cd_time(GoodsInfo,Status),
%%	?DEBUG("OCdList:~p, \nNCdList:~p", [Status#goods_status.cd_list, Status1#goods_status.cd_list]),
	%%每种情况都返回NewPlayerStatus NewStatus
    case [GoodsInfo#goods.type,GoodsInfo#goods.subtype] of
			%%仙玉
		[15,16] ->
			if
				GoodsInfo#goods.goods_id == 21601 orelse GoodsInfo#goods.goods_id == 21603  ->
					Status2 = use_jade(PlayerStatus,Status1,GoodsInfo#goods.goods_id,GoodsInfo#goods.bind);
				true ->
					Status2 = Status1
			end,
			Result = 1,
			NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
			NewPlayerStatus = PlayerStatus;
		[30,10] ->%%灵兽食物类
			if
				GoodsInfo#goods.goods_id =:= 24000 ->
					Pet = lib_pet:get_out_pet(PlayerStatus#player.id),
					lib_pet:feed_pet(PlayerStatus,Pet,GoodsNum);
				true ->
					skip
			end,
			NewPlayerStatus = PlayerStatus,
			Result = 1,
			NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
			Status2 = Status1;
		[30,11] ->%%灵兽成长类 
			Pet = lib_pet:get_out_pet(PlayerStatus#player.id),
			NewPlayerStatus = 
			if
				%%灵兽升级果
				GoodsInfo#goods.goods_id =:= 24100 ->
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
					case lib_pet:upgrade_by_using_only(PlayerStatus,Pet) of
						{ok,PetNew} ->
							mod_pet:pet_attribute_effect(PlayerStatus,PetNew),
							PlayerStatus;
						_ ->
							PlayerStatus
					end;
				%%洗点
				GoodsInfo#goods.goods_id =:= 24101 ->		
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
					case lib_pet:wash_pet(Pet,PlayerStatus) of
						{ok,PetNew} ->
							mod_pet:pet_attribute_effect(PlayerStatus,PetNew),
							PlayerStatus;
						{fail} ->
							PlayerStatus
					end;
				%%倍数经验buff
				GoodsInfo#goods.goods_id =:= 24102 orelse GoodsInfo#goods.goods_id =:= 24103 orelse GoodsInfo#goods.goods_id =:= 24108->
					{PlayerStatus1, NewGoodsBuffs} = buff_add(PlayerStatus,GoodsInfo,GoodsBuffs),
					PlayerStatus1;
				%%化形
				GoodsInfo#goods.goods_id =:= 24106->
					%%如果灵兽有圣诞变身buff则先去掉buff
					{ok,PlayerStatus1,NewGoodsBuffs} = lib_pet:chenge(PlayerStatus,Pet,GoodsBuffs),
					PlayerStatus1;
				GoodsInfo#goods.goods_id =:= 24107-> %%灵兽经验丹
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
					mod_pet:use_random_exp_dan(PlayerStatus,GoodsInfo#goods.goods_id,GoodsNum),
					PlayerStatus;
				true ->
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
					PlayerStatus
			end,	
			Result = 1,
			Status2 = Status1;		
		[30,12] ->%%灵兽技能书
			case mod_pet:check_learn_skill(PlayerStatus#player.id,GoodsInfo#goods.goods_id) of
				{ok,SkillId} ->
					lib_pet:learn_skill(PlayerStatus,SkillId);
%% 				mod_pet:pet_attribute_effect(PlayerStatus,PetNew);
				{fail,_} ->
					skip
			end,
			NewPlayerStatus = PlayerStatus,
			Result = 1,
			NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
			Status2 = Status1;
		[30,15] ->%%灵兽变身卡
			Pet = lib_pet:get_out_pet(PlayerStatus#player.id),
			{ok,NewPlayerStatus} = lib_pet:change_pet(PlayerStatus,Pet,GoodsInfo),
			Result = 1,
			NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
			Status2 = Status1;
		%%神兽蛋
		[30,18] ->
			[Type,StepOrGoodsTypeId] = data_pet:get_data_by_egg(PlayerStatus#player.id,GoodsInfo#goods.goods_id),
			if
				%%产生灵兽
				Type == 1 ->
					mod_pet:egg_pet(PlayerStatus,StepOrGoodsTypeId),
					Status2 = Status1 ;
				%%产生新物品　  
				Type == 2 ->
					Status2 = use_pet_egg(PlayerStatus,Status1,StepOrGoodsTypeId,0);
				true ->
					Status2 = Status1
			end,
			Result = 1,
			NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
			NewPlayerStatus = PlayerStatus;
		%%坐骑变身卡
		[30,20] ->
			ResultMountType = data_mount:get_mount_type_id(GoodsInfo#goods.goods_id),
			Mount = lib_mount:get_mount(PlayerStatus#player.mount),
			{NewPlayer,NewGoodsBuffs} = lib_mount:use_mount_card(PlayerStatus,GoodsBuffs,Mount,GoodsInfo,ResultMountType),
			Result = 1,
			NewPlayerStatus = NewPlayer,
			Status2 = Status1;
        [25,10] ->%%气血类
			%%是否有持续效果
			IsBuff =lists:member(GoodsInfo#goods.goods_id, [23003,23004,23005,23008,23011,23012]),
			{ok, NewPlayerStatus} =
			if
				IsBuff =:= true ->	
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
					GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
					if
						is_record(GoodsTypeInfo,ets_base_goods) ->
							OData = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data,buff),
							case OData of
								[buff,last_hp,V,T] ->
									Value =V,
									Time = T;
								_ ->
									Value =0,
									Time =0
							end,
							if
								Value > 0 ->
									F_0=fun(_T) ->
										spawn(fun()->timer:apply_after(_T * Time * 1000, lib_goods_use, buff_AddHPMP,[PlayerStatus,GoodsInfo,hp,Value]) end)
									end,
									lists:map(F_0, lists:seq(0, 4));
								true ->
									skip
							end,
							{ok,PlayerStatus};
						true ->
							{ok,PlayerStatus}
					end;
				true  ->
					Is_hppack = lists:member(GoodsInfo#goods.goods_id, [23006,23007,23010]),
					if Is_hppack ->%%气血包不直接使用
						   {_newPS, NewGoodsBuffs} = useHPMPPack(PlayerStatus, GoodsInfo, GoodsNum, GoodsBuffs),
						   {ok,_newPS};
					   true ->
						   NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
						   spawn(fun()->lib_goods:cd_add_ets(PlayerStatus,GoodsInfo)end),
             			   useHPMP(PlayerStatus, GoodsInfo, GoodsNum)
					end
			end,
			Result = 1,
			Status2 = Status1;
		[25,11] ->%%法力类
			%%是否有持续效果
			IsBuff =lists:member(GoodsInfo#goods.goods_id, [23103,23104,23105,23108]),
			{ok, NewPlayerStatus} =
			if
				IsBuff =:= true ->
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
					GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
					OData = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data,buff),
					case OData of
						[buff,last_mp,V,T] ->
							Value =V,
							Time = T;
						_ ->
							Value =0,
							Time =0
					end,
					if
						Value > 0 ->
							F_0=fun(_T) ->
								spawn(fun()->timer:apply_after(_T * Time * 1000, lib_goods_use, buff_AddHPMP,[PlayerStatus,GoodsInfo,mp,Value]) end)
							end,
							lists:map(F_0, lists:seq(0, 4));
						true ->
							skip
					end,
					{ok,PlayerStatus};		
				true ->
					Is_mppack = lists:member(GoodsInfo#goods.goods_id, [23106,23107,23110]),
					if Is_mppack ->%%法力包不直接使用
						   {_NewPS, NewGoodsBuffs}=useHPMPPack(PlayerStatus,GoodsInfo,GoodsNum, GoodsBuffs),
						   {ok,_NewPS};
					   true ->
						   NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
						   spawn(fun()->lib_goods:cd_add_ets(PlayerStatus,GoodsInfo)end),
             				useHPMP(PlayerStatus, GoodsInfo, GoodsNum)
					end
			end,
			Result = 1,
			Status2 = Status1;
        [25,12] ->%%经验类
			case lists:member(GoodsInfo#goods.goods_id, [23203,23204,23205]) of 
				true ->				
					{NewPlayerStatus, NewGoodsBuffs} = buff_add(PlayerStatus,GoodsInfo, GoodsBuffs);
				false ->
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
            		{ok, NewPlayerStatus} = useEXP(PlayerStatus, GoodsInfo, GoodsNum)
			end,
			Result = 1,
			Status2 = Status1;
		[25,13] ->%%灵力类		
			case lists:member(GoodsInfo#goods.goods_id, [23303,23304,23305]) of
				true ->					
					{NewPlayerStatus, NewGoodsBuffs} = buff_add(PlayerStatus,GoodsInfo, GoodsBuffs);
				false ->
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
					{ok, NewPlayerStatus} = useSPI(PlayerStatus,GoodsInfo,GoodsNum)
			end,
			Result = 1,
			Status2 = Status1;
		[25,14] ->%%增益类	
			case lists:member(GoodsInfo#goods.goods_id, [23409, 23410, 23411]) of
				true ->
					%%往玩家进程发信息
					[Type, _NumLimit] = get_check_type(GoodsInfo#goods.goods_id),
					Now = util:unixtime(),
					case get(Type) of
						undefined ->
							ValueList = [PlayerStatus#player.id, Type, 1, Now],
							FieldList = [player_id, type, num, fina_time],
							db_agent:insert_user_numtime(log_goods_counter, ValueList, FieldList),
							put(Type, {1, Now});
						KeyValue ->
							{Num, _FinalTime} = KeyValue,
							ValueList = [{num, Num+1},
										 {fina_time, Now}],
							WhereList = [{player_id, PlayerStatus#player.id},{type,Type}],
							db_agent:update_user_numtime(log_goods_counter, ValueList, WhereList),
							put(Type, {Num+1, Now})
					end,
					{NewPlayerStatus, NewGoodsBuffs} = buff_add(PlayerStatus,GoodsInfo, GoodsBuffs),
					%%加CD
%% 					spawn(fun()->lib_goods:cd_add(PlayerStatus,GoodsInfo)end),
					db_agent:update_join_data(PlayerStatus#player.id, peach),%%添加蟠桃参与度统计
					Result = 1,
					Status2 = Status1;	
				false ->
					{NewPlayerStatus, NewGoodsBuffs} = buff_add(PlayerStatus,GoodsInfo, GoodsBuffs),
					Result = 1,
					Status2 = Status1
			end;			
		[25, 15] ->%%修为类
			%% 修为丹
			NewPlayerStatus = 
				case lists:member(GoodsInfo#goods.goods_id, [28012, 23503, 23502, 23501, 23500]) of
					true ->
						if GoodsInfo#goods.goods_id == 23500 -> %%添加双倍修为丹的使用buff
							  {PlayerStatus1, NewGoodsBuffs} = buff_add(PlayerStatus,GoodsInfo,GoodsBuffs),
							  PlayerStatus1;
						   true ->
							   NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标
							   use_culture_pill(PlayerStatus,GoodsInfo,GoodsNum)
						end;
					false ->
						NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标
						PlayerStatus
				end,
			Result = 1,
			Status2 = Status1;
		[80,11] ->%%礼包类
			{ok,Status2} = open_gift(Status1,GoodsInfo),
			Result = 1,
			NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
			NewPlayerStatus = PlayerStatus;
		[80,18] ->%%随机礼包
			if
				GoodsInfo#goods.goods_id =:= 28704 -> %%黄金月饼
					{_,Result, Status2} = eat_goldmooncake_or_key(PlayerStatus, Status1, 31202);%%删除黄金钥匙
				true ->
					{ok,Status2} = open_rand_gift(PlayerStatus,Status1,GoodsInfo),
					Result = 1
			end,
			NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
			NewPlayerStatus = PlayerStatus;
		[80,19] ->%%新随机礼包
			if
				GoodsInfo#goods.goods_id == 28750 -> %%转盘
					{Result,Status2} = lib_anniversary:use_bigwheel([PlayerStatus,Status1,GoodsInfo#goods.goods_id]),
					NewGoodsBuffs = {no_update, GoodsBuffs},
					NewPlayerStatus =PlayerStatus;
				GoodsInfo#goods.goods_id =:= 28816 ->%%吃火鸡
					GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
					{_,Result, Status2} = eat_fire_or_turkey(PlayerStatus, Status1, 31211, GoodsTypeInfo#ets_base_goods.other_data),%%删除火种
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
					NewPlayerStatus =PlayerStatus;
				true ->
					{ok,Status2} = open_rand_gift_new(PlayerStatus,Status1,GoodsInfo),
					Result = 1,
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
					NewPlayerStatus = PlayerStatus
			end;
		[40,10] ->%%技能类
			case lists:member(GoodsInfo#goods.goods_id, data_skill:get_skill_id_list(PlayerStatus#player.career)) of
				true ->
					{ok,NewPlayerStatus} = lib_skill:upgrade_skill(PlayerStatus,GoodsInfo#goods.goods_id, 1);
				false ->
					{ok,NewPlayerStatus} = lib_skill:upgrade_passive_skill(PlayerStatus,GoodsInfo#goods.goods_id, 1)
			end,
			Result = 1,
			NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
			Status2 = Status1;
		[80,12] ->%%传送类
			spawn(fun()->lib_goods:cd_add(PlayerStatus,GoodsInfo)end),
			NewPlayerStatus = PlayerStatus,
			Result = 1,
			NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
			Status2 = Status1;
		[80,13] -> %%诛仙台碎片
			if
				GoodsInfo#goods.goods_id == 28405 ->
					NewPlayerStatus = use_zxt_pieces(PlayerStatus,GoodsInfo#goods.goods_id,GoodsNum),
					Result= 1,
					NewGoodsBuffs = {no_update, GoodsBuffs},       
					Status2 = Status1;
				true ->
					%%28403 封神台荣誉碎片
					NewPlayerStatus = use_fst_pieces(PlayerStatus,GoodsInfo#goods.goods_id,GoodsNum),
					Result= 1,
					NewGoodsBuffs = {no_update, GoodsBuffs},      
					Status2 = Status1
			end;
		[80,14] ->%%帮会道具
%% 			IsGuildSkillToken = lists:member(GoodsInfo#goods.goods_id ,[28303]),
			IsGuildSkillToken = 28303,%%氏族技能令
			IsGuildAccuse = 28302,%%氏族弹劾令
			case GoodsInfo#goods.goods_id of
				IsGuildSkillToken ->%%氏族技能令
					lib_guild_weal:add_guild_reputation(PlayerStatus#player.guild_id, GoodsNum, 
														 PlayerStatus#player.id,
														 PlayerStatus#player.nickname),
					NewPlayerStatus = PlayerStatus,
					Result = 1,
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
					Status2 = Status1;
				IsGuildAccuse ->%%氏族弹劾令
					{Result, NewPlayerStatus} = lib_guild:accuse_chief(PlayerStatus),
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
					Status2 = Status1;
				_ ->
					NewPlayerStatus = PlayerStatus,
					Result = 1,
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
					Status2 = Status1
			end;
		[80,15]->%%和平运镖令
			IsPeaceCarry = lists:member(GoodsInfo#goods.goods_id, [28506]),
			if IsPeaceCarry -> 
				   {ok,NewPlayerStatus} = use_carry_card(PlayerStatus,GoodsInfo,GoodsNum);
				    true->NewPlayerStatus = PlayerStatus
			end,
			Result = 1,
			NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
			Status2 = Status1;
		[80,16]->%%vip卡
			IsVIPCard = lists:member(GoodsInfo#goods.goods_id, [28600,28601,28602,28603,28604,28605]),
			if IsVIPCard ->
					{ok,NewPlayerStatus} = use_vip_card(PlayerStatus,GoodsInfo,GoodsNum);
			   true->NewPlayerStatus = PlayerStatus
			end,
			Result = 1,
			NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
			Status2 = Status1;
		[80,20]->%%封神帖
				case lists:member(GoodsInfo#goods.goods_id,lib_goods:get_hero_card_list()) of
					true->
						case use_hero_card(PlayerStatus,GoodsInfo#goods.goods_id) of
							{ok,NewPlayer}->
								Result = 1,
								NewPlayerStatus = NewPlayer;
							_->
								Result = 41,
								NewPlayerStatus = PlayerStatus
						end;
					false->
						Result = 0,
						NewPlayerStatus = PlayerStatus
				end,
				NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
				Status2 = Status1;						
		[80, 21] ->
			if
				%%南瓜馅饼吃了直接加经验5000
				GoodsInfo#goods.goods_id =:= 31213 ->
					Result = 1,
					NewPlayerStatus = eat_pumpkin(PlayerStatus, GoodsNum),
					Status2 = Status1;
				%%鸡腿吃了直接加经验1000
				GoodsInfo#goods.goods_id =:= 31212 ->
					Result = 1,
					NewPlayerStatus = eat_chicken_foot(PlayerStatus, GoodsNum),
					Status2 = Status1;
				%%吃火种
				GoodsInfo#goods.goods_id =:= 31211 ->%%火种
					GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
					{_,Result, Status2} = eat_fire_or_turkey(PlayerStatus, Status1, 28816, GoodsTypeInfo#ets_base_goods.other_data),%%删除火鸡
					NewPlayerStatus =PlayerStatus;
				%%吃汤圆,希望之种,木之灵可增加5000经验和5000灵力
				GoodsInfo#goods.goods_id =:= 31232 
				  orelse GoodsInfo#goods.goods_id =:= 31233 
				  orelse GoodsInfo#goods.goods_id =:=  31234 
				  orelse GoodsInfo#goods.goods_id =:=  31235 
				  orelse GoodsInfo#goods.goods_id =:= 31236->
					Result = 1,
					NewPlayerStatus = eat_riceball(PlayerStatus, GoodsNum),
					Status2 = Status1;
				%%月饼和黄金钥匙
				GoodsInfo#goods.goods_id =:= 31201 ->%%月饼直接加经验
					Result = 1,
					NewPlayerStatus = eat_mooncake(PlayerStatus, GoodsNum),
					Status2 = Status1;
				GoodsInfo#goods.goods_id =:= 31202 ->%%黄金钥匙
					{_,Result, Status2} = eat_goldmooncake_or_key(PlayerStatus, Status1, 28704),%%删除黄金月饼
					NewPlayerStatus =PlayerStatus;
				GoodsInfo#goods.goods_id == 31204 -> %%吉祥兔飞升丹
					Rabbits = goods_util:get_type_goods_list(PlayerStatus#player.id,16002,4),
					case length(Rabbits) > 0 of
						true ->
							Result = 1,
							NewPlayerStatus = change_moon_rabbit(PlayerStatus,hd(Rabbits));
						false ->
							Result = 0,
							NewPlayerStatus = PlayerStatus
					end,
					Status2 = Status1;
				GoodsInfo#goods.goods_id == 31203 -> %%中秋时装变化券
					Result = 1,
					[NewPlayerStatus,Status2] = change_mid_fashion(PlayerStatus,Status1,31203);
				
				GoodsInfo#goods.goods_id == 31214 -> %%感恩时装变化券
					Result = 1,
					[NewPlayerStatus,Status2] = change_mid_fashion(PlayerStatus,Status1,31214);
				
				GoodsInfo#goods.goods_id == 31215 -> %%时装升级券
					Result = 1,
					[NewPlayerStatus,Status2] = change_mid_fashion(PlayerStatus,Status1,31215);
				
				%% 国庆快乐
				GoodsInfo#goods.goods_id == 31207 orelse GoodsInfo#goods.goods_id == 31208 orelse GoodsInfo#goods.goods_id == 31209 orelse GoodsInfo#goods.goods_id == 31210 -> 
					Result = 1,
					Status2 = Status1,
					NewPlayerStatus = use_guoqingkuaile(PlayerStatus,GoodsNum);
				GoodsInfo#goods.goods_id =:= 28048 ->%%冰炎石
					Result = 1,
					[NewPlayerStatus,Status2] = use_ice_stone(PlayerStatus, Status1, GoodsInfo#goods.id);
				GoodsInfo#goods.goods_id =:= 31219 ->%%彩灯
					Result = 1,
					NewPlayerStatus = use_lantern(PlayerStatus, GoodsNum),
					Status2 = Status1;
				GoodsInfo#goods.goods_id =:= 31220 ->%%诺亚方舟船票
					{Result, Status2} = use_noah_ark(PlayerStatus, Status1, GoodsInfo),
					NewPlayerStatus = PlayerStatus;
				GoodsInfo#goods.goods_id =:= 31221 
				  orelse GoodsInfo#goods.goods_id =:= 31222 
				  orelse GoodsInfo#goods.goods_id =:= 31223 -> %%如意面条,如意鸡蛋,如意饺子,直接加经验
					Result = 1,
					NewPlayerStatus = use_wishful_food(PlayerStatus, GoodsNum),
					Status2 = Status1;
				GoodsInfo#goods.goods_id =:= 31229 ->%%远古大转盘
					Result = lib_anniversary:use_bigwheel([PlayerStatus,GoodsInfo#goods.goods_id]),
					NewPlayerStatus =PlayerStatus,
					Status2 = Status1;
				GoodsInfo#goods.goods_id =:= 31231 -> %%小福袋
					Result = 1,
					NewPlayerStatus = use_xiaofudai(PlayerStatus, GoodsNum),
					Status2 = Status1;
				true ->
					Status2 = Status1,
					Result = 0,
					NewPlayerStatus =PlayerStatus
			end,
			NewGoodsBuffs = {no_update, GoodsBuffs};      %%buff没有更新，做标识
		[80,22]->%%副本令
			case lists:member(GoodsInfo#goods.goods_id,lib_goods:get_dungeon_card_list()) of
				true->
					Result = 1,
					gen_server:cast(PlayerStatus#player.other#player_other.pid_task,{'finish_dungeon_card_task',[PlayerStatus,GoodsInfo#goods.goods_id]});
				false->
					Result = 0
			end,	
			Status2 = Status1,
			NewPlayerStatus =PlayerStatus,
			NewGoodsBuffs = {no_update, GoodsBuffs};      %%buff没有更新，做标识
		[80,10] ->%%其他类
			case lists:member(GoodsInfo#goods.goods_id, [28043,28045,31216,31217,31218,28047]) of
				false ->
						NewPlayerStatus = 
						%% 铜币卡
						case lists:member(GoodsInfo#goods.goods_id, [28000,28001,28002,28023,28039,28041,28044]) of
							true ->
								use_money_card(PlayerStatus,GoodsInfo,GoodsNum);
							false ->
								%% 功德丸
								case lists:member(GoodsInfo#goods.goods_id,[28007,28008]) of
									true ->
										spawn(fun()->lib_goods:cd_add(PlayerStatus,GoodsInfo)end),
										use_merit_pill(PlayerStatus,GoodsInfo);
									false ->
										%% 奇异果
										case lists:member(GoodsInfo#goods.goods_id,[28025,28026,28027]) of
											true ->
												use_kiwifruit(PlayerStatus,GoodsInfo,GoodsNum);
											false ->
												%% 秘境令(新增秘境)
												case lists:member(GoodsInfo#goods.goods_id,[28028,28029,28030, 28031]) of
													true ->
														mod_box_scene:handle_box_scene(PlayerStatus, GoodsInfo#goods.goods_id);
													false ->
														%% 小礼券
														case GoodsInfo#goods.goods_id == 28024 orelse GoodsInfo#goods.goods_id == 28053 of
															true ->
																use_cash_ticket(PlayerStatus,GoodsInfo,GoodsNum);
															false ->
																%% 粽叶
																case lists:member(GoodsInfo#goods.goods_id,[28032]) of
																	true ->
																		use_ma_lan_hua(PlayerStatus,GoodsInfo,GoodsNum);
																	false ->
																		%%放婚宴烟花
																		case GoodsInfo#goods.goods_id =:= 28049 orelse GoodsInfo#goods.goods_id =:= 28050
																																		   orelse GoodsInfo#goods.goods_id =:= 28051 of
																			true ->
																				lit_fireworks(PlayerStatus, GoodsNum, GoodsInfo#goods.goods_id)	;																				
																			false ->
																				case GoodsInfo#goods.goods_id =:= 28046 of
																					true ->
																						lib_marry:divorce(1,PlayerStatus);
																					false ->
																						case lists:member(GoodsInfo#goods.goods_id,[28054]) of
																							true->
																								lib_war2:add_war_honor(PlayerStatus, 1*GoodsNum);
																							false->
																								PlayerStatus
																						end
																				end
																		end
																end
														end
												end
										end
								end
						end,
					Result = 1,
					NewGoodsBuffs = {no_update, GoodsBuffs},       %%buff没有更新，做标识
					Status2 = Status1;
				true ->
					{NewPlayerStatus, NewGoodsBuffs} = buff_add(PlayerStatus,GoodsInfo, GoodsBuffs),
					Result = 1,
					Status2 = Status1
			end;
		[83,10] -> %%神器
			case GoodsInfo#goods.goods_id == 32000 of
				true -> 
					NewPlayerStatus = lib_deputy:add_deputy_equip(PlayerStatus);
				false ->
					NewPlayerStatus = PlayerStatus
			end,
			Result = 1,
			NewGoodsBuffs = {no_update, GoodsBuffs},
			Status2 = Status1;
		[83,11] -> %%神器道具
			case GoodsInfo#goods.goods_id == 32026 of
				true ->
					lib_deputy:add_deputy_equip_prof_val(PlayerStatus#player.id,GoodsNum * 50),
					NewPlayerStatus = PlayerStatus,
					ok;
				false ->
					case GoodsInfo#goods.goods_id == 32055 of
						true ->
							lib_deputy:downDeputyStep(PlayerStatus),
							NewPlayerStatus = PlayerStatus;
						false ->
							NewPlayerStatus = PlayerStatus
					end
			end,
			Result = 1,
			NewGoodsBuffs = {no_update, GoodsBuffs},
			Status2 = Status1
	end,
	case Result of
		1 ->
			{ok, NewStatus, NewNum} = lib_goods:delete_one(Status2, GoodsInfo, GoodsNum);
		_ ->
			NewStatus = Status2,
			NewNum = GoodsNum
	end,
    {ok, Result, NewPlayerStatus, NewStatus, NewNum, NewGoodsBuffs}.

%%基础cd
%%return record() #goods_status{}
add_goods_cd_time(GoodsInfo,Status) ->
	case [GoodsInfo#goods.type,GoodsInfo#goods.subtype] of
		[25,_]->Addcd = true;
		[80,11]->Addcd = true;
		[80,18]->Addcd = true;
		[_,_]->Addcd = false
	end,
	case Addcd of
		true ->
			CdTime = util:unixtime() + 1,%%这里是物品使用最短cd，没有分类。
			Type_cd = [GoodsInfo#goods.type,GoodsInfo#goods.subtype,CdTime],
			F = fun(TL, AccIn) ->
						[Type,Subtype,_] = TL,
						if 
							GoodsInfo#goods.type == Type andalso GoodsInfo#goods.subtype == Subtype ->
								AccIn;
							true ->
								[TL|AccIn]
						end
				end,
			NCdList = lists:foldl(F,[],Status#goods_status.cd_list),
			Status#goods_status{cd_list = [Type_cd|NCdList]};
		false ->
			Status
	end.

%%使用仙玉
use_jade(PlayerStatus,GoodsStatus,GoodsType,Bind) ->
	Career = PlayerStatus#player.career,
	case GoodsType of
		21601 -> 
			Lt = 70,
			Ll = 60;
		21603 ->
			Lt =80,
			Ll = 70
	end,
	BaseGoodsType = goods_util:get_goods_type(GoodsType),
	MS = ets:fun2ms(fun(T) when T#ets_base_goods.type == 10 andalso 
													 T#ets_base_goods.subtype > 13 andalso
													 T#ets_base_goods.color ==4 andalso 
													 T#ets_base_goods.career == Career andalso 
													 T#ets_base_goods.level >= Ll andalso 
													 T#ets_base_goods.level < Lt -> 
			T 
		end),
	BaseGoodsList = ets:select(ets_base_goods,MS),
	%%过滤出诛邪套 防具 15开头以下
	F = fun(Ginfo) ->
			Ginfo#ets_base_goods.goods_id div 1000 =< 15
		end,
	FilterList = lists:filter(F, BaseGoodsList),
	Len = length(FilterList),
	RandGoodsInfo = lists:nth(util:rand(1,Len), FilterList), 
	{ok,NewGoodsStatus} = lib_goods:give_goods({RandGoodsInfo#ets_base_goods.goods_id, 1 ,Bind}, GoodsStatus),
	Nickname = PlayerStatus#player.nickname,
	Player_id = PlayerStatus#player.id,
	Goods_id = RandGoodsInfo#ets_base_goods.goods_id,
	GoodsName = RandGoodsInfo#ets_base_goods.goods_name,
	BaseGoodsName = BaseGoodsType#ets_base_goods.goods_name,
	Color = goods_util:get_color_hex_value(RandGoodsInfo#ets_base_goods.color),
	RealmName = goods_util:get_realm_to_name(PlayerStatus#player.realm),
	GiveGoodsInfo = goods_util:get_new_goods_by_type(Goods_id,Player_id),
	NameColor = data_agent:get_realm_color(PlayerStatus#player.realm),
	Msg = io_lib:format("恭喜【<font color='~s'>~s</font>】玩家<font color='~s'>~s</font>打开了精心淬炼而成的~s，获得了极品装备【 <a href='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a>】",["#FF0000",RealmName,NameColor,Nickname,BaseGoodsName,GiveGoodsInfo#goods.id,Player_id,Color,GoodsName]),
	spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end),
	NewGoodsStatus.

%%使用灵兽蛋
use_pet_egg(PlayerStatus,GoodsStatus,GoodsTypeId,Bind) ->
	GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
	{ok,NewGoodsStatus} = lib_goods:give_goods({GoodsTypeId, 1 ,Bind}, GoodsStatus),
	GoodsName = GoodsTypeInfo#ets_base_goods.goods_name,
	Msg = io_lib:format("只见神兽瞬影遁失，只留下【<font color='#00FF33'>~s</font>】来不及带走！",[GoodsName]),
	{ok, BinData1} = pt_11:write(11080, 2, Msg),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1),
	%%spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end),
	NewGoodsStatus.
	
%%使用礼券 ,小礼券
use_cash_ticket(PlayerStatus,GoodsInfo,GoodsNum) ->
	_OtherData = goods_util:get_goods_other_data(GoodsInfo#goods.goods_id),
	_Ovalue = goods_util:parse_goods_other_data(_OtherData,value),
	Num = tool:to_integer(_Ovalue),
	Total = Num * GoodsNum,
	if
		Num > 0 ->
			NewPlayerStatus = lib_goods:add_money(PlayerStatus,Total,cash,1505),
			spawn(fun()->lib_player:send_player_attribute2(NewPlayerStatus,3)end),
			NewPlayerStatus;
		true ->
			PlayerStatus
	end.

%%物品使用类型
%%使用奇异果
use_kiwifruit(PlayerStatus,GoodsInfo,GoodsNum) ->
	case GoodsInfo#goods.goods_id of
		28025 ->
			Value = 500;
		28026 ->
			Value = 750;
		28027 ->
			Value = 1000;
		_ ->
			Value = 0
	end,
	NewValue = Value * GoodsNum,
	NewPlayerStatus = lib_player:add_exp(PlayerStatus, NewValue, NewValue,2),
	NewPlayerStatus.

%%使用马兰花
use_ma_lan_hua(PlayerStatus,_GoodsInfo,GoodsNum) ->
	Value = GoodsNum * 5000,
	NewPlayerStatus = lib_player:add_exp(PlayerStatus, Value, Value,2),
	NewPlayerStatus.

%%功德丸使用减少罪恶值
use_merit_pill(PlayerStatus,GoodsInfo) ->
	_OtherData = goods_util:get_goods_other_data(GoodsInfo#goods.goods_id),
	_Ovalue = goods_util:parse_goods_other_data(_OtherData,value),
	Evil = PlayerStatus#player.evil,
	if
		_Ovalue >= Evil ->
			NewEvil = 0;
		true ->
			NewEvil = Evil -_Ovalue
	end,
	NewPlayerStatus=PlayerStatus#player{evil = NewEvil},
	spawn(fun()->lib_player:send_player_attribute(NewPlayerStatus,3)end),
	NewPlayerStatus.

%%货币卡的使用
use_money_card(PlayerStatus,GoodsInfo,GoodsNum) ->
	_OtherData = goods_util:get_goods_other_data(GoodsInfo#goods.goods_id),
	_Ovalue = goods_util:parse_goods_other_data(_OtherData,value),
	Num = tool:to_integer(_Ovalue),
	Total = Num * GoodsNum,
	IsCoin = lists:member(GoodsInfo#goods.goods_id,[28000,28001,28002]),
	IsBcoin = lists:member(GoodsInfo#goods.goods_id, [28039,28041,28023,28044]),
	if
		IsCoin ->
			Type = coin;
		IsBcoin ->
			Type = bcoin;
		true ->
			Type = bcoin
	end,
	if
		Num > 0 ->
			NewPlayerStatus = lib_goods:add_money(PlayerStatus,Total,Type,1511),
			spawn(fun()->lib_player:send_player_attribute2(NewPlayerStatus,3)end),
			NewPlayerStatus;
		true ->
			PlayerStatus
	end.

%%修为丹使用
use_culture_pill(PlayerStatus,GoodsInfo,GoodsNum) ->
	_OtherData = goods_util:get_goods_other_data(GoodsInfo#goods.goods_id),
	_Ovalue = goods_util:parse_goods_other_data(_OtherData,value),
	Num = tool:to_integer(_Ovalue),
	Total = Num * GoodsNum,
	if
		Num > 0 ->
			NewPlayerStatus = lib_player:add_culture(PlayerStatus,Total),
			spawn(fun()->lib_player:send_player_attribute(NewPlayerStatus,3)end),
			NewPlayerStatus;
		true ->
			PlayerStatus
	end.
	
	
%%礼包使用 [{28101,1,bind},{28102,1,nobind},{128103,1,bind}]
open_gift(GoodsStatus,GoodsInfo) ->
	GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
	One = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data,gift),
	if
		length(One) > 0 ->
			case (catch goods_util:list_handle(fun lib_goods:give_goods/2, GoodsStatus, One)) of
        		{ok, NewStatus} ->
					F = fun(TupleInfo) ->
								{Goods_id,Num,_BindType} = TupleInfo,
								[Goods_id,Num]
						end,
					GoodsListInfo = lists:map(F, One),
					{ok,BinData} = pt_15:write(15018,[GoodsListInfo]),
					lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
            		%%lib_player:refresh_client(PlayerStatus#player.id, 2),
					{ok,NewStatus};
        		{fail, _Error, _Status} ->
					?ERROR_MSG("OPEN_GIFT_ERR:[~p] player_id:[~p] goods_id:[~p] ~n",[_Error,GoodsInfo#goods.player_id,GoodsInfo#goods.goods_id]),
            		{ok,GoodsStatus}		
    		end;
		true ->
			{ok,GoodsStatus}
	end.

%%使用新随机礼包 %%没有紫装生成
open_rand_gift_new(PlayerStatus,GoodsStatus,GoodsInfo)->
	GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
	One = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data,rgift),
	NameColor = data_agent:get_realm_color(PlayerStatus#player.realm),
	F_get = fun(Other,DataInfo)->
				{_Goods_id,_n,_bind,_Ratio} = Other,
				NewOther = {_Goods_id,_n,GoodsInfo#goods.bind,_Ratio},
					lists:duplicate(_Ratio, NewOther) ++ DataInfo
		end,
	DuplicateGoods = lists:foldl(F_get, [], One),
	Len = length(DuplicateGoods),
	if
		Len > 0 ->
			R = util:rand(1,Len),
			Rgoods = lists:nth(R, DuplicateGoods),
			{Goods_id,N,Bind,_} = Rgoods,
			case lib_goods:give_goods({Goods_id,N,Bind},GoodsStatus) of
				{ok,NewStatus} ->
					#player{nickname = NickName,
							id = PlayerId,
							career = PCareer,
							sex = PSex} = PlayerStatus,
					RandGoodsInfo = goods_util:get_goods_type(Goods_id),
					GoodsName = RandGoodsInfo#ets_base_goods.goods_name,
					Color = goods_util:get_color_hex_value(RandGoodsInfo#ets_base_goods.color),
					
					%%匹配需要播报的物品类型Id
					BroadcastGid = GoodsTypeInfo#ets_base_goods.goods_id,%%使用的礼包的物品类型Id
					if
						BroadcastGid =:= 28808 orelse BroadcastGid =:= 28809 orelse BroadcastGid =:= 28810 ->
							RealmName = goods_util:get_realm_to_name(PlayerStatus#player.realm),
							GiveGoodsInfo = goods_util:get_new_goods_by_type(Goods_id,PlayerId),							
							Msg = io_lib:format("[<font color='~s'>~s</font>]玩家<font color='~s'>~s</font>打开了~s获得了~p个[<a href='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a>]",
												["#FF0000",RealmName,NameColor,NickName,GoodsTypeInfo#ets_base_goods.goods_name,N,GiveGoodsInfo#goods.id,PlayerId,Color,GoodsName]),
							spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
						BroadcastGid =:= 28817 ->%%感恩节礼包
							CastList = [22007,24401,24800,28802,28019],%%获得经脉保护符、灵兽保护符、神兽蛋、3级宝石袋、99朵玫瑰的时候进行公告
							case lists:member(Goods_id, CastList) of
								true ->
									Msg = 
										io_lib:format("哗~~[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]打开充值赠送的感恩礼包，意外发现了其中的[<font color='~s'>~s</font></a>]!",
													  [PlayerId, NickName, PCareer, PSex, NameColor, NickName, Color,GoodsName]),
									spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
								false ->
									skip
							end;
						BroadcastGid =:= 28811 ->
							if RandGoodsInfo#ets_base_goods.color >= 3->
								   GiveGoodsInfo = goods_util:get_new_goods_by_type(Goods_id,PlayerId),
								    Msg = io_lib:format("玩家[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]小心翼翼地打开跨服礼包礼包，惊喜地在里面发现了~p个【 <a href='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a>】。",
														[PlayerId, NickName, PCareer, PSex, NameColor, NickName, N,GiveGoodsInfo#goods.id,PlayerId,Color,GoodsName]),
							   		spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
							   true->skip
							end;
						BroadcastGid =:= 28819 orelse BroadcastGid =:= 28818 ->%%四级紫玉袋,四级紫水晶袋
							Msg = io_lib:format("玩家[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]打开【<font color='#8800FF'><u>~s</u></font>】发现里面居然有~p个【 <a href='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a>】!真是捡到宝啊!",
													  [PlayerId, NickName, PCareer, PSex, NameColor, NickName, GoodsTypeInfo#ets_base_goods.goods_name,N,Goods_id,PlayerId,Color,GoodsName]),
							spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
%% 						BroadcastGid =:= 28821 ->%%圣诞袜播报
%% 							Msg = 
%% 								io_lib:format("哇，[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]小心翼翼地打开<font color='#8800FF'>~s</font>，意外收到圣诞老人的[<font color='~s'>~s</font></a>]*~p,真的是羡煞旁人啊！",
%% 											  [PlayerStatus#player.id, PlayerStatus#player.nickname, PCareer, PlayerStatus#player.sex, NameColor, PlayerStatus#player.nickname, GoodsTypeInfo#ets_base_goods.goods_name, Color, GoodsName, N]),
%% 							spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
						BroadcastGid =:= 28822 ->%%幸运神袋
							CastList = [31215,24105,24401,24800,28404,28409,21023],
							case lists:member(Goods_id, CastList) of
								true ->
									RealmName = goods_util:get_realm_to_name(PlayerStatus#player.realm),
									Msg = 
										io_lib:format("【<font color='~s'>~s</font>】的[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]打开了幸运神袋中，里面居然有~p个[<font color='~s'>~s</font></a>]宝物！真是太幸运了！",
													  ["#FF0000",RealmName,PlayerId, NickName, PCareer, PSex, NameColor,NickName, N,Color,GoodsName]),
									spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
								false ->
									skip
							end;
						BroadcastGid =:= 28823 ->%%如意礼包
							%%如意礼包广播物品
							WishfulGB = [31215, 21600, 24105, 24401, 22007, 21501, 23306],
							case lists:member(Goods_id, WishfulGB) of
								true ->
									Msg = 
										io_lib:format("我滴神啊！恭喜[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]打开如意礼包，获得了[<font color='~s'>~s</font></a>]*~p，真令人羡慕！！！",
													  [PlayerId, NickName, PCareer, PSex, NameColor, NickName, Color,GoodsName,N]),
									spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
								false ->
									skip
							end;
%% 						BroadcastGid =:= 28825 ->%%远古周年活动礼包
%% 							YGZNGB = [24105, 21023, 21801, 21500, 21501, 21700, 20306, 24800, 22007, 24401, 28019, 28020],
%% 							case lists:member(Goods_id, YGZNGB) of
%% 								true ->
%% 									Msg = 
%% 										io_lib:format("我滴神啊！恭喜[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]打开远古周年礼包！发现了里面的[<font color='~s'>~s</font></a>]！真是太幸运了！",
%% 													  [PlayerId, NickName, PCareer, PSex, NameColor, NickName, Color,GoodsName]),
%% 									spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
%% 								false ->
%% 									skip
%% 							end;
%% 						BroadcastGid =:= 28824 ->
%% 							%%五福临门广播物品
%% 							WuFuLinMenGB = [24105,21801, 21023, 28409,21501, 21500,21701, 20306, 24800,22007,24401],
%% 							case lists:member(Goods_id, WuFuLinMenGB) of
%% 								true ->
%% 									Msg = 
%% 										io_lib:format("[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]人品大爆发，五福临门，获得了[<font color='~s'>~s</font></a>]*~p！乐得合不拢嘴！",
%% 													  [PlayerId, NickName, PCareer, PSex, NameColor, NickName, Color,GoodsName,N]),
%% 									spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
%% 								false ->
%% 									skip
%% 							end;
						BroadcastGid =:= 28830 -> %%巧克力礼包
							Qkl_goods = [21600,28019,21500,24401,21700,22007,28409,21023,31216,24800],
							case lists:member(Goods_id, Qkl_goods) of
								true ->
									Msg = 
										io_lib:format("[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]掰开甜甜的巧克力,意外地发现了[<font color='~s'>~s</font></a>]*~p！乐得合不拢嘴！",
													  [PlayerId, NickName, PCareer, PSex, NameColor, NickName, Color,GoodsName,N]),
									spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
								false ->
									skip
							end;
						BroadcastGid =:= 28837 -> %%坐骑大福袋
%% 							?DEBUG("ZQDFD",[]),
							ZQDFDGoods = [24850, 24851, 24852, 24853, 24854, 24855, 24856, 24857],
							case lists:member(Goods_id, ZQDFDGoods) of
								true ->
									Msg = 
										io_lib:format("[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]打开坐骑大福袋，幸运地获得了[<font color='~s'>~s</font></a>]*~p！真是羡煞旁人呀..！",
													  [PlayerId, NickName, PCareer, PSex, NameColor, NickName, Color,GoodsName,N]),
									spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
								false ->
									skip
							end;
						BroadcastGid =:= 28836 -> %%坐骑小福袋
%% 							?DEBUG("ZQXFD",[]),
							ZQDFDGoods = [24858, 24859, 24860, 24861, 24854, 24855, 24862, 24863],
							case lists:member(Goods_id, ZQDFDGoods) of
								true ->
									Msg = 
										io_lib:format("[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]打开坐骑小福袋，幸运地获得了[<font color='~s'>~s</font></a>]*~p！真是羡煞旁人呀..！",
													  [PlayerId, NickName, PCareer, PSex, NameColor, NickName, Color,GoodsName,N]),
									spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
								false ->
									skip
							end;
						BroadcastGid =:= 28838 ->%%灵兽福袋
%% 							?DEBUG("LSFD",[]),
							LSFDGoods = Goods_id =:= 24509 orelse (Goods_id =:= 24800 andalso (N =:= 5 orelse N =:= 10)),
							case LSFDGoods of
								true ->
									Msg = 
										io_lib:format("[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]打开灵兽福袋，幸运地获得了[<font color='~s'>~s</font></a>]*~p！真是羡煞旁人呀..！",
													  [PlayerId, NickName, PCareer, PSex, NameColor, NickName, Color,GoodsName,N]),
									spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
								false ->
									skip
							end;
						BroadcastGid =:= 28839 ->%%时装福袋
%% 							?DEBUG("LSFD",[]),
							IsBroad = lists:member(Goods_id, [31215, 31200, 31213, 28404]),
							case IsBroad of
								true ->
									GiveGoodsInfo = goods_util:get_new_goods_by_type(Goods_id,PlayerId),
									Msg = 
										io_lib:format("哟，[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]打开时装福袋，幸运地获得了[<a href='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a>]*~p，真是羡煞旁人呀！！！",
													  [PlayerId, NickName, PCareer, PSex, NameColor, NickName, GiveGoodsInfo#goods.id,PlayerId,Color,GoodsName,N]),
									spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
								false ->
									skip
							end;
						BroadcastGid =:= 28841 ->%%时装礼包
%% 							?DEBUG("LSFD",[]),
							IsBroad = lists:member(Goods_id, [31215, 31200, 31213, 28404, 31236]),
							case IsBroad of
								true ->
									GiveGoodsInfo = goods_util:get_new_goods_by_type(Goods_id,PlayerId),
									Msg = 
										io_lib:format("哟，[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]打开时装礼包，幸运地获得了[<a href='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a>]*~p，真是羡煞旁人呀！！！",
													  [PlayerId, NickName, PCareer, PSex, NameColor, NickName, GiveGoodsInfo#goods.id,PlayerId,Color,GoodsName,N]),
									spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
								false ->
									skip
							end;
						%%	==========================================
						%%	notice:	需要添加广播的物品，在此处append
						%%	==========================================
						true ->
							%% 是否是竞技场礼包
							case lists:member(GoodsInfo#goods.goods_id, [28835, 28834, 28833, 28832]) of
								true ->
									RandGoodsInfo = goods_util:get_goods_type(Goods_id),
									if
										RandGoodsInfo#ets_base_goods.color > 2 ->
											RealmName = goods_util:get_realm_to_name(PlayerStatus#player.realm),
											GiveGoodsInfo = goods_util:get_new_goods_by_type(Goods_id,PlayerId),
											ColiseumAwardInfoList = ["#FF0000", RealmName, NameColor, NickName, GoodsTypeInfo#ets_base_goods.goods_name, GiveGoodsInfo#goods.id, PlayerId, Color, GoodsName],
											Msg = io_lib:format("[<font color='~s'>~s</font>]玩家<font color='~s'>~s</font>打开~s，惊喜地发现其中的 [<a href='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a>]！", ColiseumAwardInfoList),
											spawn(fun()-> lib_chat:broadcast_sys_msg(2, Msg) end);
										true ->
											skip
									end;
								false ->
									skip
							end
					end,
					{ok,BinData} = pt_15:write(15018,[[[Goods_id,N]]]),
					lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
					%%添加开物品日志
					erlang:spawn(fun() -> db_agent:insert_log_goods_open(PlayerId, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, Goods_id, N) end),
					{ok,NewStatus};
				_ ->
					{ok,GoodsStatus}
			end;
		true ->
			{ok,GoodsStatus}
	end.
						
%%使用随机礼包
open_rand_gift(PlayerStatus,GoodsStatus,GoodsInfo) ->
	GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
	NameColor = data_agent:get_realm_color(PlayerStatus#player.realm),
	One = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data,rgift),
	F_get = fun(Other,DataInfo)->
				{_Goods_id,_n,_bind,_Ratio} = Other,
					lists:duplicate(_Ratio, Other) ++ DataInfo
		end,
	DuplicateGoods = lists:foldl(F_get, [], One),
	Len = length(DuplicateGoods),
	if
		Len > 0 ->
			R = util:rand(1,Len),
			Rgoods = lists:nth(R, DuplicateGoods),
			{Goods_id,N,Bind,_} = Rgoods,
			if
				%%随机生成紫装 
				Goods_id == 28701 ->
					Career = PlayerStatus#player.career,
					Step = goods_util:level_to_step(PlayerStatus#player.lv),
					Pattern = #ets_base_goods{type=10,career =Career ,color=4,step = Step,_='_'},
					BaseGoodsList = goods_util:get_ets_list(ets_base_goods,Pattern),
					%%过滤出诛邪套 防具 15开头以下
					F = fun(Ginfo) ->
							Ginfo#ets_base_goods.goods_id div 1000 =< 15 andalso Ginfo#ets_base_goods.subtype > 13
						end,
					FilterList = lists:filter(F, BaseGoodsList),
					Len2 = length(FilterList),
					RandGoodsInfo = lists:nth(util:rand(1,Len2), FilterList),
					{ok,NewStatus} = lib_goods:give_goods({RandGoodsInfo#ets_base_goods.goods_id, 1 ,Bind}, GoodsStatus),					
					Nickname = PlayerStatus#player.nickname,
					Player_id = PlayerStatus#player.id,
					GoodsName = RandGoodsInfo#ets_base_goods.goods_name,
					Color = goods_util:get_color_hex_value(RandGoodsInfo#ets_base_goods.color),
					RealmName = goods_util:get_realm_to_name(PlayerStatus#player.realm),
					GiveGoodsInfo = goods_util:get_new_goods_by_type(RandGoodsInfo#ets_base_goods.goods_id,Player_id),
					Msg = io_lib:format("【<font color='~s'>~s</font>】玩家<font color='~s'>~s</font>获得了~p个【 <a href='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a>】",["#FF0000",RealmName,NameColor,Nickname,N,GiveGoodsInfo#goods.id,Player_id,Color,GoodsName]),
					spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end),
					{ok,BinData} = pt_15:write(15018,[[[GiveGoodsInfo#goods.goods_id,1]]]),
					lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
					{ok,NewStatus};
				true ->
					case lib_goods:give_goods({Goods_id,N,Bind},GoodsStatus) of
						{ok,NewStatus} ->
							%% 判读礼包类型
%% 							LDGRLB = GoodsInfo#goods.goods_id == 28700,%%劳动关荣礼包
%% 							LDGRLBGB = [28023,21320],%%劳动礼包广播物品
							KZLB = GoodsInfo#goods.goods_id == 28702,%%空战礼包
							KZLBGB = [20301,20302,24105,21320,21360,21340,21300,21330,21350,21310,21500,21600],%%空战礼包广播物品
%% 							Zhongzi = GoodsInfo#goods.goods_id == 28703, %%粽子
%% 							ZhongziGB =[23201,21320,21700,24105,24401,22007,28023], %%粽子广播物品
							%% 是否有广播		
							case 
%% 									(lists:member(Goods_id, LDGRLBGB) andalso LDGRLB) 
									(lists:member(Goods_id, KZLBGB) andalso KZLB)
%% 									orelse (lists:member(Goods_id, ZhongziGB) andalso Zhongzi) 
							of
								true ->
									RandGoodsInfo = goods_util:get_goods_type(Goods_id),
									Nickname = PlayerStatus#player.nickname,
									Player_id = PlayerStatus#player.id,
									GoodsName = RandGoodsInfo#ets_base_goods.goods_name,
									Color = goods_util:get_color_hex_value(RandGoodsInfo#ets_base_goods.color),
									RealmName = goods_util:get_realm_to_name(PlayerStatus#player.realm),
									GiveGoodsInfo = goods_util:get_new_goods_by_type(Goods_id,Player_id),
									case true of
%% 										LDGRLB ->
%% 											Msg = io_lib:format("劳动节，劳动最光荣！【<font color='~s'>~s</font>】玩家<font color='~s'>~s</font>获得了~p个【 <a href='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a>】",["#FF0000",RealmName,NameColor,Nickname,N,GiveGoodsInfo#goods.id,Player_id,Color,GoodsName]);
										KZLB ->
											Msg = io_lib:format("【<font color='~s'>~s</font>】玩家<font color='~s'>~s</font>打开空战礼包，惊喜地发现里面包含~p个【 <a href='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a>】！",["#FF0000",RealmName,NameColor,Nickname,N,GiveGoodsInfo#goods.id,Player_id,Color,GoodsName]);
%% 										Zhongzi ->
%% 											Msg = io_lib:format("【<font color='~s'>~s</font>】玩家<font color='~s'>~s</font>打开了美味的粽子，获得了~p个【 <a href='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a>】的精美奖励。",["#FF0000",RealmName,NameColor,Nickname,N,GiveGoodsInfo#goods.id,Player_id,Color,GoodsName]);
										true ->
											Msg = ""  
									end,
									if Msg /= "" ->
										spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
									   true ->
										   skip
									end;
								false ->
									skip
							end,
							{ok,BinData} = pt_15:write(15018,[[[Goods_id,N]]]),
							lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
							%%添加开物品日志
							erlang:spawn(fun() -> db_agent:insert_log_goods_open(PlayerStatus#player.id, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, Goods_id, N) end),
							{ok,NewStatus};
						_ ->
							{ok,GoodsStatus}
					end
			end;
		true ->
			{ok,GoodsStatus}
	end.
	
	
%%增益类的buff效果
buff_add(PlayerStatus,GoodsInfo, GoodsBuffs1) ->
	PlayerId = PlayerStatus#player.id,
	BaseGoodsInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
	OData = goods_util:parse_goods_other_data(BaseGoodsInfo#ets_base_goods.other_data,buff),
	case length(OData) > 0 of
		true ->
			Data = OData;
		false ->
			Data = [0,0,0,0]
	end,
	%%找buff类型
	Now = util:unixtime(),
	IsHp = lists:member(GoodsInfo#goods.goods_id, [23400,23401,23402]),		%%气血
	IsMp = lists:member(GoodsInfo#goods.goods_id, [23406,23407,23408]),		%%魔法
	IsExp = lists:member(GoodsInfo#goods.goods_id, [23203,23204,23205]),	%%经验
	IsSpi = lists:member(GoodsInfo#goods.goods_id, [23303,23304,23305]),	%%灵力
	IsDef = lists:member(GoodsInfo#goods.goods_id, [23403,23404,23405]),	%%防御
	IsPet = lists:member(GoodsInfo#goods.goods_id, [24102,24103]),			%%灵兽经验
	IsPetExp = lists:member(GoodsInfo#goods.goods_id, [24108]),			%%极品灵兽经验
	IsPeach = lists:member(GoodsInfo#goods.goods_id, [23409,23410,23411]),	%%蟠桃
	IsTurned = lists:member(GoodsInfo#goods.goods_id, [28043]),             %%变身
 	IsTryTurned = lists:member(GoodsInfo#goods.goods_id, [28045]),          %%变身体验卡
	IsCulture = lists:member(GoodsInfo#goods.goods_id, [23500]),             %%双倍修为丹
	IsChrFashTurned = lists:member(GoodsInfo#goods.goods_id,[31216]),      %%圣诞礼服
	IsChrMount = lists:member(GoodsInfo#goods.goods_id,[31217]),           %%圣诞坐骑
	IsChrPet = lists:member(GoodsInfo#goods.goods_id,[31218]),              %%圣诞灵兽
	IsChrSnowTurned = lists:member(GoodsInfo#goods.goods_id, [28047]),             %%变身
	IsMonChange = lists:member(GoodsInfo#goods.goods_id, [28056]),		%%活动的怪物变身卡
	%%找物品ID
	BuffGoodsId = 
		if
			IsHp =:= true ->
				23400;
			IsMp =:= true ->
				23406;
			IsExp =:= true ->
				23203;
			IsSpi =:= true ->
				23303;
			IsDef =:= true ->
				23403;
			IsPet =:= true ->
				24102;
			IsPetExp =:= true ->
				24108;
			IsPeach =:= true ->
				23409;
			IsTurned =:= true ->
				28043;
			IsTryTurned =:= true ->
				28045;
			IsChrSnowTurned == true ->
				28047;
			IsCulture =:= true ->
				23500;
			IsChrFashTurned =:= true ->
				31216;
			IsChrMount =:= true ->
				31217;
			IsChrPet =:= true ->
				31218;	
			IsMonChange =:= true ->
				28056;
			true ->
				0
		end,
	if 
		%%使用24012,清除24018
		IsPet == true ->
		   GoodsBuffs = filter_buff(PlayerStatus,GoodsBuffs1,[24108]);
	   %%使用24018,清除24012
	    IsPetExp =:= true ->
			GoodsBuffs = filter_buff(PlayerStatus,GoodsBuffs1,[24102]);
		IsTurned == true ->
			GoodsBuffs = filter_buff(PlayerStatus,GoodsBuffs1,[28045,31216,28047,28056]);
		IsTryTurned == true ->
			GoodsBuffs = filter_buff(PlayerStatus,GoodsBuffs1,[28043,31216,28047,28056]);
		IsChrSnowTurned == true ->
			GoodsBuffs = filter_buff(PlayerStatus,GoodsBuffs1,[28043,28045,31216,28056]);
		IsChrFashTurned =:= true ->
			GoodsBuffs = filter_buff(PlayerStatus,GoodsBuffs1,[28043,28045,28047,28056]);
		IsMonChange =:= true ->
			GoodsBuffs = filter_buff(PlayerStatus,GoodsBuffs1,[28043,28045,28047,31216]);
	   true ->
		   GoodsBuffs = GoodsBuffs1
	end,
	%%查找玩家此时是否已有相同的物品BUFF
	NewPlayer = 
	case lists:keyfind(BuffGoodsId, 1, GoodsBuffs) of
		false ->
			if IsTurned =:= true ->
				   {MonId,BuffId,NewPlayer1} = use_turned_drug(PlayerStatus,1,28043),
				   %%变身时限半小时
				   {BuffData, ExpireTime} = {{MonId,BuffId},trunc(1800+Now)},
				   NewPlayer1;
			   IsTryTurned =:= true ->
				   {MonId,BuffId,NewPlayer1} = use_turned_drug(PlayerStatus,1,28045),
				   %%变身体验卡限2分钟
				   {BuffData, ExpireTime} = {{MonId,BuffId},trunc(120+Now)},
				   NewPlayer1;
			    IsChrFashTurned =:= true ->
				   {MonId,BuffId,NewPlayer1} = use_turned_drug(PlayerStatus,1,31216),
				   %%圣诞礼服时限3天
				   {BuffData, ExpireTime} = {{MonId,BuffId},trunc(3*24*60*60+Now)},
				   NewPlayer1;
			   IsChrSnowTurned == true ->
				    {MonId,BuffId,NewPlayer1} = use_turned_drug(PlayerStatus,1,28047),
				   %%圣诞雪人时限30分钟
				   {BuffData, ExpireTime} = {{MonId,BuffId},trunc(30*60+Now)},
				   NewPlayer1;
			   IsChrMount == true ->
				   {{BuffGoodsId,{Gid,Icon}},NewPlayer1} = use_chr_mount(PlayerStatus,1,31217),
				   %%圣诞坐骑buff为3天
				   {BuffData, ExpireTime} = {{BuffGoodsId,{Gid,Icon}},trunc(3*24*60*60+Now)},
				   NewPlayer1;
			   IsChrPet == true ->
				   {{BuffGoodsId,{Pid,Pet_Goods_id}},NewPlayer1} = use_chr_pet(PlayerStatus,1,31218,0),
				   %%圣诞灵兽buff为3天
				   {BuffData, ExpireTime} = {{BuffGoodsId,{Pid,Pet_Goods_id}},trunc(3*24*60*60+Now)},
				   NewPlayer1;
			   IsMonChange =:= true ->%%怪物变身卡
				   {MonId,BuffId,NewPlayer1} = use_turned_drug(PlayerStatus,1,28056),
				   %%圣诞灵兽buff为5分钟
				   {BuffData, ExpireTime} = {{MonId,BuffId},trunc(60*5+Now)},
				   NewPlayer1;
			   true ->			
				   {BuffData, ExpireTime} = get_newgoodsbuffs(Data, Now, 0, {0,0}),
				   NewPlayer1 = PlayerStatus
			end,
			BuffDataStr = tool:to_list(util:term_to_string(BuffData)),
			db_agent:add_goods_buff(PlayerId,BuffGoodsId,ExpireTime,BuffDataStr),
			%%是否要更新玩家属性的标志位,28043:变身符
			AttUp = lists:member(BuffGoodsId, [23400,23406,23403,28043,31216,31217,31218,28047,28056]),
			%%进程字典里的buff结构{BuffGoodsId, BuffData, ExpireTime}
			ENewBuff = {BuffGoodsId, BuffData, ExpireTime},
			NewGoodsBuffs = [ENewBuff|GoodsBuffs],
			NewPlayer1;
		{_Id, V, _T} ->
			%%通知客户端把旧的buff图标去除
			if BuffGoodsId =:= 28045 ->
				   OldBuffGid = lib_goods:get_buff_goodstypeid(BuffGoodsId, V) + 100;
			   true ->
				   OldBuffGid = lib_goods:get_buff_goodstypeid(BuffGoodsId, V)
			end,
			 {ok, BinData} = pt_13:write(13014, [[OldBuffGid,0,1]]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			%%是否要更新玩家属性的标志位,28043:变身符
			AttUp = lists:member(BuffGoodsId, [23400,23406,23403,28043,28045,31216,31217,31218,28047]),
			{NewGoodsBuffs,NewPlayer2}= 
				lists:foldl(fun(Elem, AccIn) ->
									{Buffs,EPlayer} = AccIn,
									{EGoodsId, EValue, ETime} =  Elem,
									case EGoodsId =:= BuffGoodsId of
										%%现有buff中，有相同的物品BUFF
										true ->
											case ETime < Now orelse ETime =:= 0 of
												true ->
													%%时间已到，这里不用再扣变身加成
													if EGoodsId =:= 28043 ->
														   {MonId,BuffId,NewPlayer1} = use_turned_drug(EPlayer,1,EGoodsId),
														   %%变身时限半小时
														   {BuffData, ExpireTime} = {{MonId,BuffId},trunc(1800+Now)},
														   NewPlayer1;
													   EGoodsId =:= 28045 ->
														   {MonId,BuffId,NewPlayer1} = use_turned_drug(EPlayer,1,EGoodsId),
														   %%变身体验卡时限5分钟
														   {BuffData, ExpireTime} = {{MonId,BuffId},trunc(300+Now)},
														   NewPlayer1;
													    EGoodsId =:= 28047 ->
														   {MonId,BuffId,NewPlayer1} = use_turned_drug(EPlayer,1,EGoodsId),
														   %%圣诞雪人时限30分钟
														   {BuffData, ExpireTime} = {{MonId,BuffId},trunc(30*60+Now)},
														   NewPlayer1;
													   EGoodsId =:= 31216 ->
														   {MonId,BuffId,NewPlayer1} = use_turned_drug(EPlayer,1,EGoodsId),
														   %%圣诞变身180分钟
														   {BuffData, ExpireTime} = {{MonId,BuffId},trunc(3*24*60*60+Now)},
														   NewPlayer1;
														EGoodsId =:= 28056 ->
															{MonId,BuffId,NewPlayer1} = use_turned_drug(EPlayer,1,EGoodsId),
														   %%怪物变身5分钟
														   {BuffData, ExpireTime} = {{MonId,BuffId},trunc(5*60+Now)},
															NewPlayer1 = lib_player_rw:set_player_info_fields(EPlayer, []),
															lib_player:send_player_attribute(NewPlayer1,2);
													   true -> 
														   {BuffData, ExpireTime} = get_newgoodsbuffs(Data, Now, 0, {0,0}),
														   NewPlayer1 = EPlayer
													end,
													BuffDataStr = tool:to_list(util:term_to_string(BuffData)),
													db_agent:update_goods_buff(PlayerId,BuffGoodsId,ExpireTime,BuffDataStr),
													ENewBuff = {BuffGoodsId, BuffData, ExpireTime},
													{[ENewBuff|Buffs],NewPlayer1};										
												false ->
													if (EGoodsId =:= 28043 andalso IsTurned =:= true) orelse
														  (EGoodsId =:= 28045 andalso IsTryTurned =:= true) orelse
														  (EGoodsId =:= 28047 andalso IsChrSnowTurned =:= true) orelse
														  (EGoodsId =:= 31216 andalso IsChrFashTurned =:= true)->
														   %%扣除旧属性加成
														   {OldMid,_B} = EValue,
														   if EGoodsId =:= 31216 ->
																 {_MonId,{Fields,Value,_BuffId}} = data_agent:get_chr_turned_buff_id(OldMid,PlayerStatus#player.career,PlayerStatus#player.sex);
															  true ->
																 {_MonId,{Fields,Value,_BuffId}} = data_agent:get_turned_buff_id(OldMid)
														   end,
														   ValueList = get_turned_values(PlayerStatus,Fields,-Value),
														   NewPs = lib_player_rw:set_player_info_fields(EPlayer, ValueList),
														   %%扣完后再次变身
														   {MonId,BuffId,NewPlayer1} = use_turned_drug(NewPs,1,EGoodsId),
														   %%变身时限半小时
														   if EGoodsId =:= 28043 ->
																  {BuffData, ExpireTime} = {{MonId,BuffId},trunc(1800+Now)};
															  EGoodsId =:= 28047 ->
																  {BuffData, ExpireTime} = {{MonId,BuffId},trunc(30*60+Now)};
															   EGoodsId =:= 31216 ->
																  {BuffData, ExpireTime} = {{MonId,BuffId},trunc(3*24*60*60+Now)};
															  true ->
																  {BuffData, ExpireTime} = {{MonId,BuffId},trunc(120+Now)}
														   end,
														   NewPlayer1;
													   EGoodsId =:= 28056 ->%%怪物变身卡，把原来的一些附加属性去掉 
															{MonId,BuffId,_NewPlayer1} = use_turned_drug(EPlayer,1,EGoodsId),
															{BuffData, ExpireTime} = {{MonId,BuffId},trunc(1800+Now)},
															NewPlayer1 = lib_player_rw:set_player_info_fields(EPlayer, []),
															lib_player:send_player_attribute(NewPlayer1,2);
													   EGoodsId =:= 31217 ->
														   {{BuffGoodsId,{Gid,Icon}},NewPlayer1} = use_chr_mount(PlayerStatus,1,31217),
														   %%圣诞坐骑buff为3小时
														   {BuffData, ExpireTime} = {{BuffGoodsId,{Gid,Icon}},trunc(3*24*60*60+Now)},
														   NewPlayer1;
													   EGoodsId =:= 31218 ->
														   {_BuffGoodsId,{_Pid,Old_Goods_id}} = EValue,
														   {{BuffGoodsId,{Pid,Pet_Goods_id}},NewPlayer1} = use_chr_pet(PlayerStatus,1,31218,Old_Goods_id),
														   %%圣诞灵兽buff为3小时
														   {BuffData, ExpireTime} = {{BuffGoodsId,{Pid,Pet_Goods_id}},trunc(3*24*60*60+Now)},
														   NewPlayer1;
													   true ->
														   {BuffData, ExpireTime} = get_newgoodsbuffs(Data, Now, ETime, EValue),
														   NewPlayer1 = EPlayer
													end,
													BuffDataStr = tool:to_list(util:term_to_string(BuffData)),
													db_agent:update_goods_buff(PlayerId,BuffGoodsId,ExpireTime,BuffDataStr),
													ENewBuff = {BuffGoodsId, BuffData, ExpireTime},
													{[ENewBuff|Buffs],NewPlayer1}
											end;
										%%现有buff中没有相同的
										false ->
											{[Elem|Buffs],EPlayer}
									end
							end, {[],PlayerStatus}, GoodsBuffs),
			NewPlayer2    
	end,
	{NewPlayer, {update, AttUp, NewGoodsBuffs}}.

get_newgoodsbuffs(Data, Now, OldTime, EValue) ->
	case Data of%%获取新的数据
		[buff,hp_lim,Value,LastTime] ->
			BuffData = {Value,LastTime},
			ExpireTime = trunc(LastTime * 3600 + Now);
		[buff,mp_lim,Value,LastTime] ->
			BuffData = {Value,LastTime},
			ExpireTime = trunc(LastTime * 3600 + Now);
		[buff,def_mult,Value,LastTime] ->
			BuffData = {Value,LastTime},
			ExpireTime = trunc(LastTime * 3600 + Now);
		[buff,exp_mult,Value,LastTime] ->
			BuffData = {Value,LastTime},
			ExpireTime = trunc(LastTime * 3600 + Now);
		[buff,spi_mult,Value,LastTime] ->
			BuffData = {Value,LastTime},
			ExpireTime = trunc(LastTime * 3600 + Now);
		[buff,pet_mult,Value,LastTime] ->
			BuffData = {Value,LastTime},
			ExpireTime = trunc(LastTime * 3600 + Now);
		[buff,pet_mult_exp,Value,LastTime] ->
			BuffData = {Value,LastTime},
			ExpireTime = trunc(LastTime * 3600 + Now);
		[buff,peach_mult,Value,LastTime] ->
			case OldTime =:= 0 of
				true ->
					BuffData = {Value,LastTime},
					ExpireTime = trunc(Now + LastTime * 60);%%蟠桃，一分钟为基数计算
				false ->
					{OldType,_T} = EValue,
					{ExpireTime, NewType} = lib_peach:count_add_peach_time(LastTime, Value, OldTime, OldType, Now),
					%%?DEBUG("AddExpireTime:~p, LastTime:~p, Value:~p, OldType:~p", [ExpireTime, LastTime, Value, OldType]),
					BuffData = {NewType, _T},
					ExpireTime
			end;
		[buff,culture,Value,LastTime] -> %%双倍修为丹，计算累计时间
			BuffData = {Value,LastTime},
			case OldTime =:= 0 of
				true ->
					ExpireTime = trunc(LastTime * 3600 + Now);
				false ->
					ExpireTime = trunc(LastTime * 3600 + OldTime)
			end;
		 _ ->
			 BuffData =[],
			 ExpireTime = trunc(Now)
	end,
	{BuffData, ExpireTime}.

filter_buff(PlayerStatus,GoodsBuffs,BuffGoodsIdList) ->
	if GoodsBuffs == [] ->
		   [];
	   true ->
		   F = fun(BuffGoodsId,GoodsBuffs0) ->
					   case lists:keyfind(BuffGoodsId, 1, GoodsBuffs0) of
						   false ->
							   GoodsBuffs0;
						   {EGoodsId, EValue, _ETime} ->
							   if BuffGoodsId =:= 28045 ->
									  OldBuffGid = lib_goods:get_buff_goodstypeid(BuffGoodsId, EValue) + 100;
								  true ->
									  OldBuffGid = lib_goods:get_buff_goodstypeid(BuffGoodsId, EValue)
							   end,
							   {ok, BinData} = pt_13:write(13014, [[OldBuffGid,0,1]]),
							   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
							   db_agent:del_goods_buff(PlayerStatus#player.id,EGoodsId),
							   lists:keydelete(BuffGoodsId, 1, GoodsBuffs0)
					   end
			   end,
		   lists:foldl(F, GoodsBuffs, BuffGoodsIdList)
	end.
	

%%持续加血加蓝的buff效果	
buff_AddHPMP(PlayerStatus,GoodsInfo,Type,Value) ->
	case Type of
		hp -> NewGoodsInfo = GoodsInfo#goods{hp = Value};
		mp -> NewGoodsInfo = GoodsInfo#goods{mp = Value};
		_ -> NewGoodsInfo = GoodsInfo
	end,
	gen_server:cast(PlayerStatus#player.other#player_other.pid,{'buff_AddHPMP',NewGoodsInfo}),
	ok.

%%使用气血包蓝包 大小气血包以普通气血包为基准，蓝包如是。
useHPMPPack(PlayerStatus,GoodsInfo,Num, GoodsBuffs)->
	PlayerId = PlayerStatus#player.id,
	Is_hppack = lists:member(GoodsInfo#goods.goods_id, [23006,23007,23010]),
	Is_mppack = lists:member(GoodsInfo#goods.goods_id, [23106,23107,23110]),
	case true of
		Is_hppack -> PackType = 23006;
		Is_mppack -> PackType = 23106
	end,
	%%如果有旧数据则更新
	ExpireTime=util:unixtime()+ 3600 * 24 * 365,
	BsseData = goods_util:get_goods_other_data(GoodsInfo#goods.goods_id),
	BaseValue = goods_util:parse_goods_other_data(BsseData,value),
	case lists:keyfind(PackType, 1, GoodsBuffs) of
		{_OGoodsTypeId, OValue, _OExpireTime} ->
			%%原来有则更新	
			NewValue =	OValue + tool:to_integer(BaseValue) * Num,
			
			db_agent:update_goods_buff(PlayerId,PackType,ExpireTime,NewValue),
			NewBuffData = {PackType, NewValue, ExpireTime},
			NewGoodsBuffs = lists:keyreplace(PackType, 1, GoodsBuffs, NewBuffData),%%代替新的buff
			%%发送气血包改变值
			TransGoodsBuff = lib_goods:goods_buff_trans_to_proto(NewGoodsBuffs),
			{ok, BinData} = pt_13:write(13014, TransGoodsBuff),
    		spawn(fun() -> lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData) end),
			{PlayerStatus,{update, NewGoodsBuffs}};
		false ->	%%原来没有新增
			NewValue = tool:to_integer(BaseValue) * Num ,
			db_agent:add_goods_buff(PlayerId,PackType,ExpireTime,NewValue),
			NewBuffData = {PackType, NewValue, ExpireTime},
			%%直接+新的buff
			NewGoodsBuffs = [NewBuffData|GoodsBuffs],
			%%发送气血包改变值
			TransGoodsBuff = lib_goods:goods_buff_trans_to_proto(NewGoodsBuffs),
			{ok, BinData} = pt_13:write(13014, TransGoodsBuff),
    		spawn(fun() -> lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData) end),
			{PlayerStatus,{update, NewGoodsBuffs}}
	end.

%% 加血加蓝类道具
useHPMP(Player, GoodsInfo, GoodsNum) ->
    %% 计算气血或者内力
	case GoodsInfo#goods.subtype of
		10 ->
			Hp =
				if
					%% 处理传递过来的buff效果
					GoodsInfo#goods.hp > 0 ->
						GoodsInfo#goods.hp;
					true ->
						_OtherData = goods_util:get_goods_other_data(GoodsInfo#goods.goods_id),
						_Ovalue = goods_util:parse_goods_other_data(_OtherData,value),
    					tool:to_integer(_Ovalue) * GoodsNum 
				end,
			NewHp = 
				case Player#player.hp + Hp > Player#player.hp_lim of
                	true -> 
						Player#player.hp_lim;
                	false -> 
						Player#player.hp + Hp
           		end,
			NewPlayer = Player#player{ hp = NewHp },
			{ok, BinData1} = pt_12:write(12014, [NewPlayer#player.id, GoodsInfo#goods.goods_id, NewHp, NewPlayer#player.hp_lim]),
           	mod_scene_agent:send_to_area_scene(NewPlayer#player.scene, NewPlayer#player.x, NewPlayer#player.y, BinData1),
			{ok, NewPlayer};
		11 ->
			Mp =
				if
					%% 处理传递过来的buff效果
					GoodsInfo#goods.mp > 0 ->
						GoodsInfo#goods.mp;
					true ->
						_OtherData = goods_util:get_goods_other_data(GoodsInfo#goods.goods_id),
						_Ovalue = goods_util:parse_goods_other_data(_OtherData,value),
    					tool:to_integer(_Ovalue) * GoodsNum 
				end,
			NewMp = 
				case Player#player.mp + Mp > Player#player.mp_lim of
                	true -> 
						Player#player.mp_lim;
                	false -> 
						Player#player.mp + Mp
           		end,
			NewPlayer = Player#player{ mp = NewMp },
			lib_player:send_player_attribute2(NewPlayer, 3),
			{ok, NewPlayer};
		_ ->
			{ok, Player}
	end.
    
%%加经验类
useEXP(PlayerStatus, GoodsInfo, GoodsNum) ->	
	%%经验单类型ID
	case lists:member(GoodsInfo#goods.goods_id, [23200,23201,23202,23206]) of 
		true ->
			_OtherData = goods_util:get_goods_other_data(GoodsInfo#goods.goods_id),
			_Ovalue = goods_util:parse_goods_other_data(_OtherData,value),
			Exp = tool:to_integer(_Ovalue);
		false ->
			Exp = 0
	end,
	NewExp = Exp * GoodsNum,
    NewPlayerStatus = lib_player:add_exp(PlayerStatus, NewExp, 0,2),
    {ok, NewPlayerStatus}.

%%加灵力类
useSPI(PlayerStatus , GoodsInfo, GoodsNum) ->
	%%灵力单类型ID
	case lists:member(GoodsInfo#goods.goods_id, [23300,23301,23302,23306]) of
		true ->
			_OtherData = goods_util:get_goods_other_data(GoodsInfo#goods.goods_id),
			_Ovalue = goods_util:parse_goods_other_data(_OtherData,value),
			Spi = tool:to_integer(_Ovalue);
		false ->
			Spi = 0
	end,
	NewSpi = Spi * GoodsNum,
	NewPlayerStatus = lib_player:add_spirit(PlayerStatus,NewSpi),
	spawn(fun()->lib_player:send_player_attribute(NewPlayerStatus,2)end),
	{ok,NewPlayerStatus}.

%%使用vip卡
use_vip_card(PlayerStatus,GoodsInfo,_GoodsNum)->
	case lists:member(GoodsInfo#goods.goods_id, [28600,28601,28602,28603,28604,28605]) of
		true ->
			NewPlayerStatus = lib_vip:set_vip_state(PlayerStatus,GoodsInfo#goods.goods_id),
			%%通知氏族模块
			mod_guild:role_vip_update(NewPlayerStatus#player.id, NewPlayerStatus#player.vip),
			spawn(fun()->lib_player:send_player_attribute(NewPlayerStatus,2)end),

			%% 更新竞技场挑战次数
			gen_server:cast(NewPlayerStatus#player.other#player_other.pid, {'CHANGE_COLISEUM_TIMES', NewPlayerStatus#player.vip, PlayerStatus#player.vip}),
			
			{ok, Bin12042} = pt_12:write(12042, [PlayerStatus#player.id, [{3, NewPlayerStatus#player.vip}]]),
			%%采用广播通知，附近玩家都能看到
			mod_scene_agent:send_to_area_scene(PlayerStatus#player.scene, PlayerStatus#player.x, PlayerStatus#player.y, Bin12042),
	
%% 			lib_vip:get_vip_award_load(NewPlayerStatus),
%% 			gen_server:cast(NewPlayerStatus#player.other#player_other.pid_goods, {'extend_vip', 1, NewPlayerStatus}),
			{ok,NewPlayerStatus};
		false ->
			{ok,PlayerStatus}

	end.

%%使用和平运镖令
use_carry_card(PlayerStatus,GoodsInfo,_GoodsNum)->
	case lists:member(GoodsInfo#goods.goods_id, [28506]) of
		true ->
			NewPlayerStatus = PlayerStatus#player{pk_mode=1},
			{ok, PkModeBinData} = pt_13:write(13012, [1, 1]),
    		lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, PkModeBinData),
			{ok,NewPlayerStatus};
		false ->
			{ok,PlayerStatus}
	end.

%%use_hero_card使用封神贴
use_hero_card(PlayerStatus,GoodsId)->
	{Lv,Color,TaskId} = lib_hero_card:get_lv_and_color(GoodsId),
	%%接受任务
	case lib_task:trigger(TaskId,0, PlayerStatus,0) of
		{true,NewPlayerStatus}->
			lib_hero_card:use_hero_card(PlayerStatus#player.id,Lv,Color),
			{ok, BinData} = pt_30:write(30006, [1,0]),
			lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData),
			{ok,NewPlayerStatus};
		_Error->
			error
	end.

%%判断buff是否存在，否则返回默认值
check_goods_buff_esixt(GoodsTypeId, GoodsBuffs) ->
	case lists:keyfind(GoodsTypeId, 1, GoodsBuffs) of
		false ->
			1;
		{_GoodsTypeId, Buff, _ExpireTime} ->
			Buff
	end.
			
%%使用诛仙碎片(每个碎片可以兑换20点荣誉)
use_zxt_pieces(PlayerStatus,GoodsId,GoodsNum)->
	case lists:member(GoodsId,[28405]) of
		true->
			lib_scene_fst:add_zxt_honor(PlayerStatus,GoodsNum*20);
		false->
			PlayerStatus
	end.
%%使用封神台碎片
use_fst_pieces(PlayerStatus,GoodsId,GoodsNum) ->
	case lists:member(GoodsId, [28403]) of
		true ->
			lib_scene_fst:add_fst_honor(PlayerStatus,GoodsNum * 20);
		false ->
			PlayerStatus
	end.
%%吉祥兔变身月兔
change_moon_rabbit(PlayerStatus,GoodsInfo) ->
	if
		PlayerStatus#player.mount > 0 ->
			MountInfo = goods_util:get_goods(PlayerStatus#player.mount),
			%%卸下原来的坐骑
			Player2 = lib_goods:get_off_mount(PlayerStatus,MountInfo),
			%%卸下的坐骑不一定是变身的坐骑，所以mountinfo 不一定跟goodsinfo 一致
			GoodsInfo2 = GoodsInfo#goods{goods_id = 16008 ,speed = 65 ,color = 3 ,other_data = undefined},
			spawn(fun()->db_agent:update_goods([{goods_id,16008},{speed,65} ,{color ,3}],[{id ,GoodsInfo2#goods.id}])end),
			ets:insert(?ETS_GOODS_ONLINE, GoodsInfo2),
			NewGoodsInfo = goods_util:get_goods(GoodsInfo2#goods.id),			
			NewPlayerStatus = lib_goods:get_on_mount(Player2,NewGoodsInfo),
			%%改变物品信息
			{ok, BIN} = pt_15:write(15000, [NewGoodsInfo, 0, []]),
    		lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BIN),
			%%改变坐骑
			{ok, BinData} = pt_16:write(16002, [1, NewGoodsInfo#goods.id, NewGoodsInfo#goods.goods_id,NewPlayerStatus#player.speed]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		true ->
			%%没有坐骑的情况
			NewGoodsInfo = GoodsInfo#goods{goods_id = 16008 ,speed = 65 ,color = 3 ,other_data = undefined},
			ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
			spawn(fun()->db_agent:update_goods([{goods_id,16008},{speed,65} ,{color ,3}],[{id ,NewGoodsInfo#goods.id}])end),
			NewPlayerStatus = PlayerStatus
	end,
	%%...需要刷背包才改变图片
	lib_player:refresh_client(PlayerStatus#player.other#player_other.pid_send, 2),
	NewPlayerStatus.

%%中秋时装变换
change_mid_fashion(PlayerStatus,Status,Gid) ->
	Fashion = goods_util:get_cell_equip(PlayerStatus#player.id,13),
	[G1,G2] =
		case Gid of
			%%中秋变身券
			31203 ->
				case PlayerStatus#player.career of
					1 -> [10911,10912];
					2 -> [10913,10914];
					3 -> [10915,10916];
					4 -> [10917,10918];
					5 -> [10919,10920]
				end;
			%%感恩节变身券
			31214 ->
				case PlayerStatus#player.career of
					1 -> [10921,10922];
					2 -> [10923,10924];
					3 -> [10925,10926];
					4 -> [10927,10928];
					5 -> [10929,10930]
				end;
			%%时装升级券
			31215 ->
				case PlayerStatus#player.career of
					1 -> [10931,10932];
					2 -> [10933,10934];
					3 -> [10935,10936];
					4 -> [10937,10938];
					5 -> [10939,10940]
				end
		end,
	Goods_id =
		if
			PlayerStatus#player.sex == 1 ->
				G1;
			true ->
				G2
		end,
	if Gid =/= 31215 ->
		   NewFashion = Fashion#goods{icon = Goods_id,goods_id = Goods_id},
		   ets:insert(?ETS_GOODS_ONLINE, NewFashion),
		   spawn(fun()->db_agent:update_goods([{icon ,Goods_id},{goods_id,Goods_id}],[{id ,NewFashion#goods.id}])end);
	   true ->
		  GoodsTypeInfo = goods_util:get_goods_type(Goods_id),
		  NewFashion = Fashion#goods{icon = Goods_id,
									 goods_id = Goods_id,
        							 price_type = GoodsTypeInfo#ets_base_goods.price_type,
                                     price = GoodsTypeInfo#ets_base_goods.price,
									 hp = GoodsTypeInfo#ets_base_goods.hp,
									 def = GoodsTypeInfo#ets_base_goods.def        
									 },
		  NewFashion1 = NewFashion#goods{other_data = []},
		  ets:insert(?ETS_GOODS_ONLINE, NewFashion1),
		  spawn(fun()->db_agent:update_goods([{icon ,Goods_id},{goods_id,Goods_id},{price_type,NewFashion#goods.price_type},{price,NewFashion#goods.price},{hp,NewFashion#goods.hp},{def,NewFashion#goods.def}],[{id ,NewFashion#goods.id}])end)
	end,
	[_Player_Id, _ShieldRole, _ShieldSkill, _ShieldRela, _ShieldTeam, _ShieldChat, _Music, _SoundEffect,Fasheffect, _Smelt] = lib_syssetting:query_player_sys_setting(PlayerStatus#player.id),
	case Fasheffect == 1 of
		true ->
				{ok, Bin12042} = pt_12:write(12042, [PlayerStatus#player.id, [{2, 0}]]),
				%%采用广播通知，附近玩家都能看到
				mod_scene_agent:send_to_area_scene(PlayerStatus#player.scene, PlayerStatus#player.x, PlayerStatus#player.y, Bin12042);
		false ->
				{ok, Bin12042} = pt_12:write(12042, [PlayerStatus#player.id, [{2, Goods_id}]]),
				%%采用广播通知，附近玩家都能看到
				mod_scene_agent:send_to_area_scene(PlayerStatus#player.scene, PlayerStatus#player.x, PlayerStatus#player.y, Bin12042)
	end,
	[Wq, _Yf, Fbyf, Spyf, Zq] = Status#goods_status.equip_current,
	CurrentEquip = [Wq, Goods_id, Fbyf, Spyf, Zq],
	NewStatus = Status#goods_status{equip_current = CurrentEquip},
	NewPlayerStatus = PlayerStatus#player{
						   other = PlayerStatus#player.other#player_other{
                           		equip_current = CurrentEquip
							}
      },
	%%玩家重新穿上装备，更新衣橱的数据
	{_IsNeedF5, _ChangeFashion} = lib_wardrobe:equip_check_wardrobe(NewFashion, PlayerStatus#player.id, PlayerStatus#player.sex, change, PlayerStatus#player.nickname),
	%%检查是否需要主推刷新衣橱数据
	lib_wardrobe:check_need_f5_wardrobe(self(), PlayerStatus#player.id, PlayerStatus#player.other#player_other.pid_send, 3, {}, {}),
	%%使用后角色面板要刷新
	gen_server:cast(self(), {'list_15010', NewPlayerStatus, 1}),
	gen_server:cast(self(),	{'info_15000', NewFashion#goods.id, 1}),
	%%lib_player:refresh_client(Status#goods_status.pid_send, 2),%%通知刷背包
	%%lib_player:refresh_client(Status#goods_status.pid_send, 1),%%通知刷人物面部
	%%改变物品信息
	[NewPlayerStatus,NewStatus].

%%冰炎石使用
use_ice_stone(Player, Status, Gid) ->
	MountId = Player#player.mount,
	GoodsInfo = goods_util:get_goods(MountId),
	if 
		is_record(GoodsInfo,goods) == false ->
			[Player,Status];
		true ->
			if GoodsInfo#goods.goods_id == 16004 ->
				   NowGoodsId = 16005;
			   GoodsInfo#goods.goods_id == 16005 ->
				   NowGoodsId = 16004;
			   true ->
				   NowGoodsId = GoodsInfo#goods.goods_id
			end,
			{ok,Status1,_} = lib_goods:delete_one(Status,goods_util:get_goods(Gid),1),
			NewGoodsInfo = GoodsInfo#goods{goods_id = NowGoodsId},
			ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
			%%添加坐骑图鉴
			lib_mount:add_active_type(Player,[16004,16005]),
			spawn(fun()->db_agent:update_goods([{goods_id ,NowGoodsId}],[{id ,NewGoodsInfo#goods.id}])end),
			{ok, Bin12042} = pt_12:write(12042, [Player#player.id, [{4, NowGoodsId}]]),
			%%采用广播通知，附近玩家都能看到
			mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, Bin12042),
			[_Wq, _Yf, Fbyf, Spyf, _Zq] = Player#player.other#player_other.equip_current,
			CurrentEquip = [_Wq, _Yf, Fbyf, Spyf, NowGoodsId],
			NewPlayer = Player#player{
					other = Player#player.other#player_other{
							equip_current = CurrentEquip
					}
     		},
			gen_server:cast(NewPlayer#player.other#player_other.pid_goods, {'equip_current',CurrentEquip}),
			NewStatus = Status1#goods_status{equip_current = CurrentEquip},
			%%使用后角色面板要刷新%%改变物品信息
			gen_server:cast(self(), {'list_15010', NewPlayer, 1}),
			gen_server:cast(self(),	{'info_15000', NewGoodsInfo#goods.id, 1}),
			lib_player:send_player_attribute(NewPlayer,2),
			[NewPlayer,NewStatus]
	end.
	

%%使用月饼，增加5000经验和灵力
eat_mooncake(PlayerStatus, GoodsNum) ->
	AddExpSpi = GoodsNum * 5000,
	lib_player:add_exp(PlayerStatus, AddExpSpi, AddExpSpi,2).

%% 使用国庆快乐
use_guoqingkuaile(PlayerStatus,GoodsNum) ->
	AddNum = GoodsNum * 1000,
	lib_player:add_exp(PlayerStatus,AddNum ,AddNum,2).

%%使用彩灯
use_lantern(PlayerStatus, GoodsNum) ->
	AddNum = GoodsNum * 2000,
	lib_player:add_exp(PlayerStatus,AddNum ,AddNum,2).
	
%%使用黄金月饼或者黄金钥匙
eat_goldmooncake_or_key(PlayerStatus, GoodsStatus, GoodsTypeId) ->
	FailType = 
		case GoodsTypeId of
			31202 ->%%点击使用黄金月饼的，要删除黄金钥匙
				47;
			28704 ->%%点击使用黄金钥匙的，要删除黄金月饼
				46
		end,
	NameColor = data_agent:get_realm_color(PlayerStatus#player.realm),
	%%开始删除物品
	GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId, 4),
	TotalNum = goods_util:get_goods_totalnum(GoodsList),
	if
		%% 物品不存在
		length(GoodsList) =:= 0 ->
			{fail, FailType, GoodsStatus};
		%% 物品数量不足
		TotalNum < 1 ->
			{fail, FailType, GoodsStatus};
		true ->
%% 			给物品
			Goods = [24105,21801,21700,21500,24102,28801,28409,21023],%%月饼礼盒奖励物品
			Len = length(Goods),
			R = util:rand(1,Len),
			GiveGoodsId = lists:nth(R, Goods),
			GoodsTypeInfo = goods_util:get_goods_type(GiveGoodsId),
			if
				%% 物品不存在
				is_record(GoodsTypeInfo, ets_base_goods) =:= false ->
					{fail, 2, GoodsStatus};
				true ->
					case lib_goods:give_goods({GiveGoodsId,1,0},GoodsStatus) of
						{ok,GiveGoodsStatus} ->
							%%发给前端提示
							{ok,BinData} = pt_15:write(15018,[[[GiveGoodsId,1]]]),
							lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
							%%删除物品开始
							case (catch lib_goods:delete_more(GiveGoodsStatus, GoodsList, 1)) of
								{ok, DeleteGoodsStatus} ->
									lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
%% 									?DEBUG("ok,delete the goods", []),
									#ets_base_goods{color = ColorNum,
													goods_name = GoodsName} = GoodsTypeInfo,
									Color = goods_util:get_color_hex_value(ColorNum),
									#player{id = PlayerId,
											nickname = PlayerName,
											career = Career,
											sex = Sex} = PlayerStatus,
									Msg = 
										io_lib:format("我了个去,[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]手中黄金钥匙一亮，意外发现了黄金月饼礼盒中的[<font color='~s'>~s</font></a>],真是神奇啊!!!",
													  [PlayerId, PlayerName, Career, Sex, NameColor, PlayerName, Color,GoodsName]),
									spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end),
									{ok, 1, DeleteGoodsStatus};
								_Other ->
%% 									?DEBUG("omg! can not delete the goods", []),
									{fail, 0, GoodsStatus}
							end;
						{fail, cell_num, _GoodsStatus} ->
							{fail, 19, GoodsStatus};
						_other ->
							{fail, 0, GoodsStatus}
					end
			end
	end.

get_turned_values(Player,Fields,Value) ->
	if Fields < 1005 ->
		   [{def,Player#player.def + Value}];
	   Fields < 1009 ->
		   [{min_attack,Player#player.min_attack + Value},{max_attack,Player#player.max_attack + Value}];
	   Fields =:= 1009 ->
		   [{hit,Player#player.hit + Value}];
	   Fields =:= 1010 ->
		   [{dodge,Player#player.dodge + Value}];
	   Fields =:= 1011 ->
		   [{crit,Player#player.crit + Value}];
	   Fields < 1014 ->
		   [{anti_wind,Player#player.anti_wind + Value}, {anti_fire,Player#player.anti_fire + Value}, {anti_water, Player#player.anti_water + Value},
			{anti_thunder,Player#player.anti_thunder + Value},{anti_soil,Player#player.anti_soil + Value}];
	   Fields < 1021 ->
		   [{hp,Player#player.hp + Value}];
	   Fields == 40107 ->
		   [{def,Player#player.def + Value}];
	   true ->
		   []
	end.

get_chr_turned_eft(Player,Fields,Value) ->
		if Fields < 1005 ->
		   [{def,Player#player.def + Value}];
	   Fields < 1009 ->
		   [{min_attack,Player#player.min_attack + Value},{max_attack,Player#player.max_attack + Value}];
	   Fields =:= 1009 ->
		   [{hit,Player#player.hit + Value}];
	   Fields =:= 1010 ->
		   [{dodge,Player#player.dodge + Value}];
	   Fields =:= 1011 ->
		   [{crit,Player#player.crit + Value}];
	   Fields < 1014 ->
		   [{anti_wind,Player#player.anti_wind + Value}, {anti_fire,Player#player.anti_fire + Value}, {anti_water, Player#player.anti_water + Value},
			{anti_thunder,Player#player.anti_thunder + Value},{anti_soil,Player#player.anti_soil + Value}];
	   Fields < 1021 ->
		   [{hp,Player#player.hp + Value}];
	   Fields >= 10941 andalso  Fields =< 10950->
		   [{hp,Player#player.hp}];
	   true ->
		   []
	end.

get_turned_add_value(_Player,Fields,Value) ->
	if Fields < 1005 ->
		   [{def, Value}];
	   Fields < 1009 ->
		   [{atk,Value}];
	   Fields =:= 1009 ->
		   [{hit,Value}];
	   Fields =:= 1010 ->
		   [{dodge,Value}];
	   Fields =:= 1011 ->
		   [{crit,Value}];
	   Fields < 1014 ->
		   [{anti, Value}];
	   Fields < 1021 ->
		   [{hp_lim,Value}];
	   Fields == 40107 ->
		   [{def, Value}];
	   true ->
		   []
	end.

get_chr_turned_add_value(_Player,Fields,Value) ->
	if Fields < 1005 ->
		   [{def, Value}];
	   Fields < 1009 ->
		   [{atk,Value}];
	   Fields =:= 1009 ->
		   [{hit,Value}];
	   Fields =:= 1010 ->
		   [{dodge,Value}];
	   Fields =:= 1011 ->
		   [{crit,Value}];
	   Fields < 1014 ->
		   [{anti, Value}];
	   Fields < 1021 ->
		   [{hp_lim,Value}];
	   Fields >= 10940 andalso  Fields =< 10950->
		   [{hp_lim,Value}];
	   true ->
		   []
	end.

%%使用变身丹
%%Type，0表示取消变身，1表示变身BUFF开始
use_turned_drug(Player,Type,GoodsId) ->
	Rnd =  random:uniform(100),
	Result = 
		if GoodsId =:= 28043 ->
			   data_agent:get_turned_eft(Rnd,Type,Player#player.career);
		   GoodsId =:= 31216 ->
			   data_agent:get_chr_turned_eft(Rnd,Type,Player);
		   GoodsId =:= 28045 ->
			   data_agent:get_turned_try_eft(Rnd,Type,Player#player.sex);
		   GoodsId =:= 28047 ->
			   data_agent:get_chr_snow_turned_eft(Rnd,Type,Player#player.career);
		   GoodsId =:= 28056 ->
			   data_agent:get_mon_change(Rnd, 28056);
		   true ->
			   false
		end,		
	case Result of
		false ->
			{0,0,Player};
		[MonId,{Fields, Value, BuffId}] ->
			if GoodsId == 31216 ->
				   ValueList = get_chr_turned_eft(Player,Fields,Value);
			   true ->
				   ValueList = get_turned_values(Player,Fields,Value)
			end,
			if ValueList =:= [] ->
				   case GoodsId =:= 28056 of
					   false ->
						   %%通知场景，模型改变
						   {ok,Data12066} = pt_12:write(12066,[Player#player.id,Player#player.other#player_other.turned]),
						   mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, Data12066),
						   {0,0,Player};
					   true ->
						   NewPlayer1 = Player#player{other = Player#player.other#player_other{turned = Fields,
																							   goods_buff = Player#player.other#player_other.goods_buff#goods_cur_buff{turned_mult = []}}},
						   NewPlayer2 = lib_player:count_player_attribute(NewPlayer1),
						   %%发送玩家属性变更通知到客户端,这就是 13001！！！！！！！！！！！！！
						   lib_player:send_player_attribute(NewPlayer2,2),
						   %%通知场景，模型改变
						   {ok,Data12066} = pt_12:write(12066,[NewPlayer2#player.id,NewPlayer2#player.other#player_other.turned]),
						   mod_scene_agent:send_to_area_scene(NewPlayer2#player.scene,NewPlayer2#player.x, NewPlayer2#player.y, Data12066),
						   {MonId,BuffId,NewPlayer2}
				   end;
			   true ->
				   if 
					   Value > 0 ->
						   %%变身buff开始
						   if GoodsId == 31216 ->
								  BuffValues = get_chr_turned_add_value(Player,Fields,Value),
								  NewPlayer1 = Player#player{other = Player#player.other#player_other{turned = Fields,
																			goods_buff = Player#player.other#player_other.goods_buff#goods_cur_buff{turned_mult = [BuffValues]}}},
								  NewPlayer2 = lib_player:count_player_attribute(NewPlayer1);
							  true ->
								  BuffValues = get_turned_add_value(Player,Fields,Value),
								  NewPlayer = lib_player_rw:set_player_info_fields(Player, ValueList),
								  NewPlayer2 = NewPlayer#player{other = NewPlayer#player.other#player_other{turned = Fields,
																			goods_buff = NewPlayer#player.other#player_other.goods_buff#goods_cur_buff{turned_mult = [BuffValues]}}},
								  %%聊天窗口通知
								  NpcName = data_agent:get_turned_name(MonId),
								  Content = io_lib:format("你成功幻化成<font color='#FEDB4F'> ~s</font> 的样子！", [NpcName]),
								  {ok, BinData} = pt_11:write(11080, 2, Content),
								  lib_send:send_to_sid(NewPlayer2#player.other#player_other.pid_send, BinData)
						   end,
						   NewPlayer2;
					   true ->
						   %%解除变身buff
							NewPlayer = lib_player_rw:set_player_info_fields(Player, ValueList),
							NewPlayer2 = NewPlayer#player{other = NewPlayer#player.other#player_other{turned = 0,
																									  goods_buff = NewPlayer#player.other#player_other.goods_buff#goods_cur_buff{turned_mult = []}}}
				   end,
				   %%发送玩家属性变更通知到客户端,这就是 13001！！！！！！！！！！！！！
				   lib_player:send_player_attribute(NewPlayer2,2),
				   %%通知场景，模型改变
				   {ok,Data12066} = pt_12:write(12066,[NewPlayer2#player.id,NewPlayer2#player.other#player_other.turned]),
				   mod_scene_agent:send_to_area_scene(NewPlayer2#player.scene,NewPlayer2#player.x, NewPlayer2#player.y, Data12066),
				   {MonId,BuffId,NewPlayer2}
			end
	end.
				 

%%使用圣诞礼服
%%Type为1表示首次使用，2表示不是首次使用
use_chr_fash(Player,Type,GoodsId) ->
	PropValueList = data_agent:get_chr_fash_eft(Player#player.career),
	Fashion = goods_util:get_cell_equip(Player#player.id,13),
	if Type =:= 2 ->
		   {{GoodsId,[Fashion#goods.id | PropValueList]},Player};
	   true ->
		   [G1,G2] =  
			   case Player#player.career of
				   1 -> [10931,10932];
				   2 -> [10933,10934];
				   3 -> [10935,10936];
				   4 -> [10937,10938];
				   5 -> [10939,10940]
			   end,
		   NewCoinId =
			   if
				   Player#player.sex == 1 ->
					   G1;
				   true ->
					   G2
			   end,
		   NewFashion = Fashion#goods{icon = NewCoinId},
		   ets:insert(?ETS_GOODS_ONLINE, NewFashion),
		   spawn(fun()->db_agent:update_goods([{icon ,NewCoinId}],[{id ,NewFashion#goods.id}])end),
		   [_Player_Id, _ShieldRole, _ShieldSkill, _ShieldRela, _ShieldTeam, _ShieldChat, _Music, _SoundEffect,Fasheffect, _Smelt] = lib_syssetting:query_player_sys_setting(Player#player.id),
		   case Fasheffect == 1 of
			   true ->
				   {ok, Bin12042} = pt_12:write(12042, [Player#player.id, [{2, 0}]]),
				   %%采用广播通知，附近玩家都能看到
				   mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, Bin12042);
			   false ->
				   {ok, Bin12042} = pt_12:write(12042, [Player#player.id, [{2, NewCoinId}]]),
				   %%采用广播通知，附近玩家都能看到
				   mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, Bin12042)
		   end,
		   [_Wq, _Yf, Fbyf, Spyf,_Zq] = Player#player.other#player_other.equip_current,
		   CurrentEquip = [_Wq, NewCoinId, Fbyf, Spyf, _Zq],
		   gen_server:cast(Player#player.other#player_other.pid_goods, {'equip_current',CurrentEquip}),
		   NewPlayer = Player#player{
						   other = Player#player.other#player_other{
                           		equip_current = CurrentEquip
							}
     		},
		   PropValueAddList = goods_util:prop_value_add(PropValueList,add),
		   NewPlayer1 = lib_player_rw:set_player_info_fields(NewPlayer, PropValueAddList),
		   NewPlayer2 = NewPlayer1#player{other = NewPlayer1#player.other#player_other{
													goods_buff = NewPlayer1#player.other#player_other.goods_buff#goods_cur_buff{chr_fash = [PropValueList]}}},
		    %%发送玩家属性变更通知到客户端,这就是 13001！！！！！！！！！！！！！
		   %%使用后角色面板要刷新%%改变物品信息
		   gen_server:cast(self(), {'list_15010', NewPlayer, 1}),
		   gen_server:cast(self(),	{'info_15000', NewFashion#goods.id, 1}),
		   lib_player:send_player_attribute(NewPlayer2,2),
		   {{GoodsId,[Fashion#goods.id | PropValueList]},NewPlayer2}
	end.

%%取消圣诞礼服
cancel_chr_fash(Player,Value) ->
	{_BuffId,[Gid,{_Key,_Value}]} = Value,
	 Fashion = 
	 case goods_util:get_goods(Gid) of
		 [] ->
			 %%根据物品id修改时装icon字段，防止因交易后不能清除玩家时间icon值
			 spawn(fun()->db_agent:update_goods([{icon ,0}],[{id ,Gid}])end),
			 goods_util:get_goods_by_id(Gid);
		 Fashion1 ->
			 Fashion1
	 end,
	 if Fashion == [] ->
			Player;
		true ->
			NewFashion = Fashion#goods{icon = 0},
			ets:insert(?ETS_GOODS_ONLINE, NewFashion),
			spawn(fun()->db_agent:update_goods([{icon ,0}],[{id ,NewFashion#goods.id}])end),
			[_Player_Id, _ShieldRole, _ShieldSkill, _ShieldRela, _ShieldTeam, _ShieldChat, _Music, _SoundEffect,Fasheffect, _Smelt] = lib_syssetting:query_player_sys_setting(Player#player.id),
			case Fasheffect == 1 of
				true ->
					{ok, Bin12042} = pt_12:write(12042, [Player#player.id, [{2, 0}]]),
					%%采用广播通知，附近玩家都能看到
					mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, Bin12042);
				false ->
					{ok, Bin12042} = pt_12:write(12042, [Player#player.id, [{2, NewFashion#goods.goods_id}]]),
					%%采用广播通知，附近玩家都能看到
					mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, Bin12042)
			end,
			[_Wq, _Yf, Fbyf, Spyf, _Zq] = Player#player.other#player_other.equip_current,
			CurrentEquip = [_Wq, NewFashion#goods.goods_id, Fbyf, Spyf, _Zq],
			gen_server:cast(Player#player.other#player_other.pid_goods, {'equip_current',CurrentEquip}),
			NewPlayer = Player#player{
						   other = Player#player.other#player_other{
                           		equip_current = CurrentEquip
							}
     			},
			if  NewPlayer#player.other#player_other.goods_buff#goods_cur_buff.chr_fash == [] ->
					EPlayer2 = NewPlayer;
				true ->
					PropValueList = data_agent:get_chr_fash_eft(NewPlayer#player.career),
					PropValueAddList = goods_util:prop_value_add(PropValueList,sub),
					EPlayer1 = lib_player_rw:set_player_info_fields(Player, PropValueAddList),
					EPlayer2 = EPlayer1#player{other = EPlayer1#player.other#player_other{
													goods_buff = EPlayer1#player.other#player_other.goods_buff#goods_cur_buff{chr_fash = []}}},
					lib_player:send_player_attribute(EPlayer2,2)
			end,
			%%发送玩家属性变更通知到客户端,这就是 13001！！！！！！！！！！！！！
			EPlayer2
	 end.

%%使用圣诞从骑
%%Type为1表示首次使用，2表示不是首次使用
use_chr_mount(Player,Type,GoodsId) ->
	MountId = Player#player.mount,
	case Type == 2 of
		true ->
			{{GoodsId,MountId},Player};
		false ->
			NewCoinId = 16011,
			GoodsInfo = goods_util:get_goods(MountId),
			NewGoodsInfo = GoodsInfo#goods{icon = NewCoinId},
			ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
			spawn(fun()->db_agent:update_goods([{icon ,NewCoinId}],[{id ,NewGoodsInfo#goods.id}])end),
			{ok, Bin12042} = pt_12:write(12042, [Player#player.id, [{4, NewCoinId}]]),
			%%采用广播通知，附近玩家都能看到
			mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, Bin12042),
			[_Wq, _Yf, Fbyf, Spyf,_Zq] = Player#player.other#player_other.equip_current,
			CurrentEquip = [_Wq, _Yf, Fbyf, Spyf, NewCoinId],
			gen_server:cast(Player#player.other#player_other.pid_goods, {'equip_current',CurrentEquip}),
			NewPlayer = Player#player{
									  other = Player#player.other#player_other{
								           		equip_current = CurrentEquip
							}
     		},
			NewPlayer1 = NewPlayer#player{other = NewPlayer#player.other#player_other{
										goods_buff = NewPlayer#player.other#player_other.goods_buff#goods_cur_buff{chr_mount = NewGoodsInfo#goods.id}}},
			Mount =  lib_mount:get_mount(MountId),
			if is_record(Mount,ets_mount) ->
				   Mount1 = Mount#ets_mount{icon = NewCoinId},
				   lib_mount:update_mount(Mount1),
				   spawn(fun()-> db_agent:update_mount([{icon,NewCoinId}], [{id,Mount1#ets_mount.id}]) end),
				   {ok, BinData} = pt_12:write(12010, [NewPlayer1#player.id, NewPlayer1#player.speed, NewCoinId,Mount1#ets_mount.id,Mount1#ets_mount.stren]),
				   mod_scene_agent:send_to_area_scene(NewPlayer1#player.scene, NewPlayer1#player.x, NewPlayer1#player.y, BinData),
				   Icon = Mount#ets_mount.icon;
			   true ->
				   Icon = GoodsInfo#goods.icon
			end,
			%%发送玩家属性变更通知到客户端,这就是 13001！！！！！！！！！！！！！
			%%使用后角色面板要刷新%%改变物品信息
			gen_server:cast(self(), {'list_15010', NewPlayer1, 1}),
			gen_server:cast(self(),	{'info_15000', NewGoodsInfo#goods.id, 1}),
			lib_player:send_player_attribute(NewPlayer1,2),
			{{GoodsId,{NewGoodsInfo#goods.id,Icon}},NewPlayer1}
	end.

%%取消圣诞坐骑
cancel_chr_mount(Player,Value) ->
	{_BuffId,{Gid,Icon}} = Value,
	 GoodsInfo = 
	 case goods_util:get_goods(Gid) of
		 [] ->
			 %%根据物品id修改时装icon字段，防止因交易后不能清除玩家时间icon值
			 spawn(fun()->db_agent:update_goods([{icon ,Icon}],[{id ,Gid}])end),
			 goods_util:get_goods_by_id(Gid);
		 GoodsInfo1 ->
			 GoodsInfo1
	 end,
	 if GoodsInfo == [] ->
			Player;
		true ->
			NewGoodsInfo = GoodsInfo#goods{icon = Icon},
			ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
			spawn(fun()->db_agent:update_goods([{icon ,Icon}],[{id ,NewGoodsInfo#goods.id}])end),
			if Player#player.mount ==  NewGoodsInfo#goods.id ->
				   Mount = lib_mount:get_mount(Player#player.mount),
				   if is_record(Mount,ets_mount) ->
						  {ok, Bin12042} = pt_12:write(12042, [Player#player.id, [{4, NewGoodsInfo#goods.goods_id}]]),
						  %%采用广播通知，附近玩家都能看到
				   		  mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, Bin12042),
						  [_Wq, _Yf,Fbyf, Spyf, _Zq] = Player#player.other#player_other.equip_current,
						  CurrentEquip = [_Wq, _Yf, Fbyf, Spyf, Icon],
						  Mount1 = Mount#ets_mount{icon = Icon},
						  lib_mount:update_mount(Mount1),
						  spawn(fun()-> db_agent:update_mount([{icon,Icon}], [{id,Mount1#ets_mount.id}]) end),
						  Player1 = Player#player{
                    			mount = Mount1#ets_mount.id,
								other = Player#player.other#player_other{
                    			equip_current = CurrentEquip,
								mount_stren = Mount1#ets_mount.stren}},
						  {ok, BinData} = pt_12:write(12010, [Player#player.id, Player#player.speed, Icon,Mount1#ets_mount.id,Mount1#ets_mount.stren]),
						  mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData),
%% 					  gen_server:cast(Player#player.other#player_other.pid_goods, {'equip_current',CurrentEquip}),
						  NewPlayer1 = Player1#player{other = Player1#player.other#player_other{goods_buff = Player1#player.other#player_other.goods_buff#goods_cur_buff{chr_mount = 0}}},
						  NewPlayer2 = NewPlayer1#player{other = NewPlayer1#player.other#player_other{equip_current = CurrentEquip}};
					  true ->
						  NewPlayer2 =  Player#player{other = Player#player.other#player_other{
										goods_buff = Player#player.other#player_other.goods_buff#goods_cur_buff{chr_mount = 0}}}
				   end;
			   true ->
				   NewPlayer2 =  Player#player{other = Player#player.other#player_other{
										goods_buff = Player#player.other#player_other.goods_buff#goods_cur_buff{chr_mount = 0}}}
			end,
			lib_player:send_player_attribute(NewPlayer2,2),
			NewPlayer2
	end.
			
	
%%使用圣诞灵兽
%%Type为1表示首次使用，2表示不是首次使用
use_chr_pet(Player,Type,GoodsId,OldGoodsId) ->
	Pet = lib_pet:get_out_pet(Player#player.id),
	case Type == 2 of
		true ->
			{{GoodsId,{Pet#ets_pet.id,OldGoodsId}},Player};
		false ->
			NewGoodsId = 24616,
			PetNew = Pet#ets_pet{goods_id=NewGoodsId},
			lib_pet:update_pet(PetNew),
			lib_pet:save_pet(PetNew),
			DelPetColor = data_pet:get_pet_color(PetNew#ets_pet.aptitude),
			{ok,DelBinData} = pt_12:write(12031,[1,Player#player.id,PetNew#ets_pet.id ,PetNew#ets_pet.name,DelPetColor,PetNew#ets_pet.goods_id,PetNew#ets_pet.grow,PetNew#ets_pet.aptitude]),
			mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, DelBinData),
			if OldGoodsId == 0 ->
				   {{GoodsId,{Pet#ets_pet.id,Pet#ets_pet.goods_id}},Player};
			   true ->
				   {{GoodsId,{Pet#ets_pet.id,OldGoodsId}},Player}
			end
	end.

%%取消圣诞灵兽
%%Type为1表示首次使用，2表示不是首次使用
cancel_chr_pet(Player,Value) ->
	{_BuffId,{PetId,PetOldGoodsId}} = Value,
	Pet = lib_pet:get_pet(PetId),
	OutPet = lib_pet:get_out_pet(Player#player.id),
	case Pet == [] of
		true ->
			Player;
		false ->
			%%当前灵兽不是圣诞变身卡的灵兽
			if OutPet == [] orelse OutPet#ets_pet.id =/= PetId ->
				   PetNew = Pet#ets_pet{goods_id=PetOldGoodsId},
				   lib_pet:update_pet(PetNew),
				   lib_pet:save_pet(PetNew),
				   Player;
			   true ->
				   PetNew = Pet#ets_pet{goods_id=PetOldGoodsId},
				   lib_pet:update_pet(PetNew),
				   lib_pet:save_pet(PetNew),
				   {ok,OldBinData1} = pt_41:write(41004,[1,PetNew#ets_pet.id,1]),
				   lib_send:send_to_sid(Player#player.other#player_other.pid_send,OldBinData1),
				   DelPetColor = data_pet:get_pet_color(PetNew#ets_pet.aptitude),
				   {ok,DelBinData} = pt_12:write(12031,[1,Player#player.id,PetNew#ets_pet.id ,PetNew#ets_pet.name,DelPetColor,PetNew#ets_pet.goods_id,PetNew#ets_pet.grow,PetNew#ets_pet.aptitude]),
				   mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, DelBinData),
				   Player
			end
	end.

	

%%检查vip状态
check_vip_state(PlayerStatus,GoodsId)->
	{Type,_} = lib_vip:get_vip_type(GoodsId),
	%%Type 1月卡，2季度卡，3半年卡，4周卡，5一天卡,6体验卡
	case PlayerStatus#player.vip of
		1-> lists:member(Type,[1,2,3,6]);
		2-> lists:member(Type,[2,3,6]);
		3-> lists:member(Type,[3,6]);
		4-> lists:member(Type,[1,2,3,4,6]);
		5-> lists:member(Type,[1,2,3,4,5,6]);
		6-> lists:member(Type,[1,2,3,4,5,6]);
		_-> lists:member(Type,[1,2,3,4,5,6])
	end.

%%单独使用南瓜馅饼，可获得2000经验
eat_pumpkin(PlayerStatus, GoodsNum) ->
	AddExp = GoodsNum * 5000,
	lib_player:add_exp(PlayerStatus, AddExp, 0, 2).
%%单独使用鸡腿，可获得1000经验
eat_chicken_foot(PlayerStatus, GoodsNum) ->
	AddExp = GoodsNum * 1000,
	lib_player:add_exp(PlayerStatus, AddExp, 0, 2).
%%吃汤圆增加5000经验和5000灵力
eat_riceball(PlayerStatus, GoodsNum) ->
	AddExp = GoodsNum * 5000,
	lib_player:add_exp(PlayerStatus, AddExp, AddExp, 2).

%% 使用火种或者火鸡
%% Param
%% PlayerStatus	record #player
%% GoodsStatus	record #goods_status
%% DelGoodsTypeId	%%需要删除的物品类型Id
eat_fire_or_turkey(PlayerStatus, GoodsStatus, DelGoodsTypeId, OtherData) ->
	FailType = 
		case DelGoodsTypeId of
			31211 ->%%点击火鸡的，要删除火种
				53;
			28816 ->%%点击火种的，要删除火鸡
				54
		end,
	NameColor = data_agent:get_realm_color(PlayerStatus#player.realm),
	%%开始删除物品
	GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, DelGoodsTypeId, 4),
	TotalNum = goods_util:get_goods_totalnum(GoodsList),
	if
		%% 物品不存在
		length(GoodsList) =:= 0 ->
			{fail, FailType, GoodsStatus};
		%% 物品数量不足
		TotalNum < 1 ->
			{fail, FailType, GoodsStatus};
		true ->
%% 			给物品,由OtherData取出随机的物品Id
			One = goods_util:parse_goods_other_data(OtherData,rgift),
			FGet = fun(EOther,AccIn)->
							{EGoodsId,EN,EBind,ERatio} = EOther,
							case AccIn of
								[] ->
									[{EGoodsId, EN, EBind, ERatio}];
								[{_LEGoodsId, _LN, _LEBind, LERatio}|_] ->
									[{EGoodsId, EN, EBind, ERatio+LERatio}|AccIn]
							end
					end,
			DuplicateGoods = lists:foldl(FGet, [], One),
			[{_,_,_, Len}|_Other] = DuplicateGoods,
			if
				Len > 0 ->
					%%获取随机到的物品Id
					R = util:rand(1,Len),
					{GiveGoodsId,N,Bind,_} = get_random_goods(R, lists:reverse(DuplicateGoods)),%%因为第一个元素一定是最大的，需要反转一次
					GoodsTypeInfo = goods_util:get_goods_type(GiveGoodsId),
					if
						%% 物品不存在
						is_record(GoodsTypeInfo, ets_base_goods) =:= false ->
							{fail, 2, GoodsStatus};
						true ->
							case lib_goods:give_goods({GiveGoodsId,N,Bind},GoodsStatus) of
								{ok,GiveGoodsStatus} ->
									%%发给前端提示
									{ok,BinData} = pt_15:write(15018,[[[GiveGoodsId,1]]]),
									lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
									%%删除物品开始
									case (catch lib_goods:delete_more(GiveGoodsStatus, GoodsList, 1)) of
										{ok, DeleteGoodsStatus} ->
											lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
%% 											获得成长保护丹、紫色附魔石、五级紫水晶、四级紫水晶、极品幸运符、神兽蛋的时候进行公告
											CastList = [24105,21023,21501,21500,20306,24800],
											case lists:member(GiveGoodsId, CastList) of
												true ->
													#ets_base_goods{color = ColorNum,
																	goods_name = GoodsName} = GoodsTypeInfo,
													Color = goods_util:get_color_hex_value(ColorNum),
													#player{id = PlayerId,
															nickname = PlayerName,
															career = Career,
															sex = Sex} = PlayerStatus,
													Msg = 
														io_lib:format("哗~~我滴神呐,[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]人品大爆发，竟在火鸡肚中发现了[<font color='~s'>~s</font></a>]！乐得合不拢嘴！",
																	  [PlayerId, PlayerName, Career, Sex, NameColor, PlayerName, Color,GoodsName]),
													spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
												false ->
													skip
											end,
											{ok, 1, DeleteGoodsStatus};
										_Other ->
											{fail, 0, GoodsStatus}
									end;
								{fail, cell_num, _GoodsStatus} ->
									{fail, 19, GoodsStatus};
								_other ->
									{fail, 0, GoodsStatus}
							end
					end;
				true ->%%居然没随机物品Id,other_data为空
					{fail, 0, GoodsStatus}
			end
	end.

%%计算出符合当前概率的物品Id
get_random_goods(_R, []) ->
	{0,0,0,0};
get_random_goods(R, [{_FGoodsId, _FN, _FBind, FRatio}|Rest]) ->
	case R =< FRatio of
		true ->
			{_FGoodsId, _FN, _FBind, FRatio};
		false ->
			get_random_goods(R, Rest)
	end.

%%放婚宴烟花
lit_fireworks(Player, GoodsNum, GoodsId) ->
	{Exp,Type} = 
		case GoodsId of
			28049 ->
				{GoodsNum*1000,1};
			28050 ->
				{GoodsNum*2000,2};
			28051 ->
				{GoodsNum*5000,3}
		end,
	%%通知客户端播放烟花效果
	{ok,Bin} = pt_48:write(48018,Type),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin),
	mod_scene_agent:send_to_scene(Player#player.scene,Bin),
	lib_player:add_exp(Player, Exp, 0, 2).
	
							
					

%%使用诺亚方舟船票，产生替身娃娃
use_noah_ark(PlayerStatus, GoodsStatus, _GoodsInfo) ->
%% 	GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
	R = util:rand(1,100),
	NameColor = data_agent:get_realm_color(PlayerStatus#player.realm),
	Rem = R rem 2,
	case Rem of
		0 ->%%成功拿到替身娃娃
			case lib_goods:give_goods({28400,1,2},GoodsStatus) of
				{ok,NewStatus} ->
					Msg =
						io_lib:format("哇，[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]历经千辛万苦，幸运地登上诺亚方舟，获得[<font color='#FFFFFF'>替身娃娃</font></a>]*1,我的神呐！！！！",
									  [PlayerStatus#player.id, PlayerStatus#player.nickname, PlayerStatus#player.career, PlayerStatus#player.sex, NameColor, PlayerStatus#player.nickname]),
					spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end),
					{ok,BinData} = pt_15:write(15018,[[[28400,1]]]),
					lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
					{1, NewStatus};
				_ ->
					{0, GoodsStatus}
			end;
		_ ->%%很遗憾的拿不到
			Msg =
				io_lib:format("好遗憾！诺亚方舟早已人满为患，[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]最终没能登上T_T，可怜的娃！！！",
							  [PlayerStatus#player.id, PlayerStatus#player.nickname, PlayerStatus#player.career, PlayerStatus#player.sex, NameColor, PlayerStatus#player.nickname]),
			spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end),
			{1, GoodsStatus}
	end.

%%如意面条,如意鸡蛋,如意饺子,直接加经验
use_wishful_food(PlayerStatus, GoodsNum) ->
	AddExpSpi = GoodsNum * 2000,
	lib_player:add_exp(PlayerStatus, AddExpSpi, AddExpSpi,2).
%% 小福袋直接加经验
use_xiaofudai(PlayerStatus, GoodsNum) ->
	AddExp = GoodsNum * 1000,
	lib_player:add_exp(PlayerStatus, AddExp, 0,2).

get_random_online_player(SelfId) ->
	{Type,_}=tool:list_random([id,lv,exp,spirit,coin,cash,hp,mp,honor,culture]),
	PlayerList = db_agent:get_online_player_match(Type,SelfId),
	if 
		PlayerList =:= [] ->
			[];
		true ->
			 map_thefirst(PlayerList)
	end.

map_thefirst([]) ->
	[];
map_thefirst([[PlayerId]|PlayerList]) ->
	case lib_player:get_online_info_fields(PlayerId,[scene,x,y,pid,turned,nickname]) of
		[Scene,X,Y,ToPid,ToTurned,PName] ->
			case ToTurned =:= 0 of
				false ->
					map_thefirst(PlayerList);
				true ->
					{PlayerId, ToPid, PName, Scene, X, Y}
			end;
		[] ->
			map_thefirst(PlayerList)
	end.
