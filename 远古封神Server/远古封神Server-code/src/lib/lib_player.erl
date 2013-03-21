%%%--------------------------------------
%%% @Module  : lib_player
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description:角色相关处理
%%%--------------------------------------
-module(lib_player).
-export(
 	[
		init_base_career/0,
		get_career_info/1,
        is_online/1,
        get_role_id_by_name/1,
		get_role_name_by_id/1,
        is_exists_name/1,
        add_exp/4,
        add_coin/2,
		add_bcoin/2,
		add_spirit/2,
		sub_spirit/2,
		add_culture/2,
		sub_culture/2,
		reduce_culture/2,
		add_honor/2,
		add_realm_honor/2,
        refresh_client/1,
        refresh_client/2,
        next_lv_exp/1,
        get_online_info/1,
		get_online_info_fields/2,
		login_process/2,
		get_player_pid/1,
        is_accname_exists/2,
		get_attribute_parameter/1,
        attribute_1_to_2/6,
		pet_attribute_1_to_2/6,
        count_player_attribute/1,
        refresh_spirit/2,
        send_player_attribute/2,
		send_player_attribute2/2,
        player_die/6,
		get_donttalk_status/1,
		get_skill_buff_attr/1,        		
        get_skill_buff_effect/3,
		get_user_info_by_id/1,
		send_player_sit_attribute/2,
		startSitStatus/2,
		cancelSitStatus/1,
		refresh_player_buff/3,
		refresh_player_goods_buff/7,
		get_country/1,		
		handle_role_hp_mp/2,
		player_status/1,
		add_fst_esh/5, %%诛仙台/诛仙台经验，灵力，荣誉
		check_fst_td_log/3,
		cast_last_skill_buff_loop/6,
		set_skill_buff_timer/2,
		stop_skill_buff_timer/0,
		guild_carry_tip/2,
		save_online/1,
		get_other_player_data/3,
		init_join_data/2,
		change_playername/2,
		is_exp_activity/0,
		exp_activity_login_check/1,
		get_other_player_info/3,
		deduct_evil/1,
		update_last_login/3,
		update_online_time/4,
		get_palyer_properties/2,
		check_sex_change/1,
		get_fashion_equip_change/1,		%% 因为变性而时装变换需要转换的Ids
		get_fashion_fb_sp_change/1,
		get_guild_post_title/1,
		count_player_batt_value/1,
		start_double_rest/2,
		cancel_double_rest/2,
		double_rest_peach/1,
		count_player_speed/1,
		player_speed_count/1,
		calc_player_pay/3,
		count_value/1,
		count_batt_value/3,
		get_player_pay_gold/1,
		count_player_batt_value1/4,
		backup_player_data/1,
		get_player_info/1
	]
).
-include("common.hrl").
-include("record.hrl"). 
-include("guild_info.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%% 持续技能BUFF类型
-define(SKILL_BUFF_TYPE_LIST, [hp_lim, agile, physique, def, last_anti, hit_add, castle_rush_att, castle_rush_anti]).

%%初始化基础职业属性
init_base_career() ->
    F = fun(Career) ->
				  CareerInfo = list_to_tuple([ets_base_career] ++ Career),
                  ets:insert(?ETS_BASE_CAREER, CareerInfo)
           end,
	L = db_agent:get_base_career(),
	lists:foreach(F, L),
    ok.

%%获取基础职业属性
get_career_info(Id) ->
	case ets:lookup(?ETS_BASE_CAREER, Id) of
   		[] -> undefined;
   		[R] -> R
	end.

%% 检测某个角色是否在线
is_online(PlayerId) ->
%% 	case get_player_pid(PlayerId) of
%% 		[] -> false;
%% 		_Pid -> true
%% 	end.
	PlayerProcessName = misc:player_process_name(PlayerId),
	Pid = misc:whereis_name({global, PlayerProcessName}),
	is_pid(Pid).

%% 取得在线角色的进程PID
get_player_pid(PlayerId) ->
	PlayerProcessName = misc:player_process_name(PlayerId),
	Pid = misc:whereis_name({global, PlayerProcessName}),
	case misc:is_process_alive(Pid) of
		true -> 
			Pid;
		_ ->
			[]
	end.

%% 根据角色名称查找ID
get_role_id_by_name(Name) ->
    db_agent:get_role_id_by_name(Name).

%%根据角色id查找名称
get_role_name_by_id(Id)->
	db_agent:get_role_name_by_id(Id).

%% 检测指定名称的角色是否已存在
is_accname_exists(Sn, AccName) ->
    case db_agent:is_accname_exists(Sn, AccName) of
        null -> false;
        _Other -> true
    end.

%% 获取角色禁言信息
get_donttalk_status(PlayerId) ->
	try
		case db_agent:get_donttalk_status(PlayerId) of
			[] -> [undefined, undefined];
			[TimeStart, Stop_chat_minutes] ->
				[TimeStart, Stop_chat_minutes]
		end
	catch
		_:_ ->
			[undefined, undefined]
	end.

%% 检测指定名称的角色是否已存在
is_exists_name(Name) ->
    case get_role_id_by_name(Name) of
        null -> false;
        _Other -> true
    end.

%% 取得在线角色的角色状态
get_online_info(PlayerId) ->
	case ets:lookup(?ETS_ONLINE, PlayerId) of
   		[] ->
			get_user_info_by_id(PlayerId);
   		[Player] ->
       		case is_process_alive(Player#player.other#player_other.pid) of
           		true -> 
					Player;
           		false ->
               		ets:delete(?ETS_ONLINE, PlayerId),
               		[]
       		end
	end.

%% 获取玩家信息
get_user_info_by_id(PlayerId) ->
	case get_player_pid(PlayerId) of
		[] -> 
			[];
		Pid ->
       		case catch gen:call(Pid, '$gen_call', 'PLAYER', 2000) of
           		{'EXIT',_Reason} ->
              		[];
          		{ok, Player} ->
               		Player
          	end
	end.

%% 获取用户信息(按字段需求)
get_online_info_fields(PlayerId, L) when is_integer(PlayerId) ->
	case get_player_pid(PlayerId) of
		[] -> 
			[];
		Pid ->
			get_online_info_fields(Pid, L)
	end;
get_online_info_fields(Pid, L) when is_pid(Pid) ->
    case catch gen:call(Pid, '$gen_call', {'PLAYER', L}, 2000) of
       	{'EXIT',_Reason} ->
      		[];
       	{ok, PlayerFields} ->
       		PlayerFields
	end.

%%登陆过程记录
login_process(Socket,N) ->
	{ok,Bin} = pt_10:write(10009,[N]),
	lib_send:send_one(Socket,Bin).

%% 增加人物经验入口(FromWhere：0为任务收入、1为单人打怪收入、2为使用物品收入、3为师徒收入,4为凝神修炼, 5为好友祝福, 6为爬塔,
%% 7吃蟠桃, 9答题收入, 10氏族战奖励, 11塔防奖励，12为组队打怪收入, 13自动打坐收入,14仙侣情缘, 15温泉, 16氏族祝福奖励, 17双修,20活动兑换, 21神魔乱斗
%%	22婚宴,23经验找回,24封神纪元)
add_exp(Status, _Exp, _Spirit, 13) when Status#player.lv < 10 ->
	Status;
add_exp(Status, Exp, Spirit, FromWhere) ->
	[RetExp, RetSpirit,NewStatus1] = 
        case FromWhere of
            1 ->				
				%% 道具buff的加成系数
				Mult_exp = Status#player.other#player_other.goods_buff#goods_cur_buff.exp_mult ,
				Mult_spi = Status#player.other#player_other.goods_buff#goods_cur_buff.spi_mult,
				%%vip加成
				{NewStatus,_ok,VipMult} = lib_vip:get_vip_award(pk_mon,Status),
				%% 攻城战霸主经验加成
				{CastleRushExp, CastleRushSpt} =
					case Status#player.other#player_other.castle_king of
						0 ->
                            {0, 0};
						_ ->
                            {0.05, 0.1}
					end,
				%%封神争霸加成
				[_,_,WarMult|_] = Status#player.other#player_other.war_honor_value,
				Exp1 = round(Exp * (Mult_exp + VipMult + CastleRushExp)),
				Spirit1 = round(Spirit * (Mult_spi + VipMult + CastleRushSpt + WarMult)),
				%% 判断是否加入氏族，以及加入的氏族技能等级效果
                GuildId = Status#player.guild_id,
				Exp2 =                     
                    case GuildId of
                        0 ->%% 没有加入氏族
                            Exp1;
                        _ ->%% 加入了氏族
                            round(mod_guild:get_guild_battle_exp(GuildId, Exp1))
                    end,
				[Exp2, Spirit1, NewStatus];
            _ ->
           		[Exp, Spirit,Status]
        end,
	NewExp = NewStatus1#player.exp + RetExp,
	NewStatus2 = add_exp(NewStatus1, NewExp, 0, NewExp, RetSpirit,FromWhere),
	%%添加坐骑经验
	NewStatus3 = lib_mount:add_mount_exp(NewStatus2,round(RetExp*0.05)),
	NewStatus3.

%% 增加人物经验(递归)
add_exp(Status, Exp, Type, Exp_ori, Spt,FromWhere) ->
    %%增加灵力
    NextLvExp = next_lv_exp(Status#player.lv),	
    if
        NextLvExp > Exp orelse Status#player.lv >= 99 ->  
			case Type of 
				0 ->	%% 未到升级
					if 
						Status#player.lv >= 99 ->
						   Spirit = Status#player.spirit,
						   Exp1= NextLvExp;
					  	true ->						 
						   Spirit =Status#player.spirit + Spt,
						   Exp1 = Exp
					end,
            		{ok, BinData} = pt_13:write(13002, [Exp1, Spirit]),
            		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					case lists:member(FromWhere ,[1,7,13,14]) of
						true->
						   [Timestamp] = get(update_exp_timestamp),
						   NowTime = util:unixtime(), 
						   case NowTime-Timestamp>120 of
								true->
            						ValueList = [{exp, Exp1}, {spirit, Spirit}, {hp, Status#player.hp}, {mp, Status#player.mp}],
									WhereList = [{id, Status#player.id}],
            						spawn(fun()->db_agent:update_player_exp_data(ValueList, WhereList)end),
									put(update_exp_timestamp,[NowTime]);
							   false->skip
						   end;
						  false->
							  ValueList = [{exp, Exp1}, {spirit, Spirit}, {hp, Status#player.hp}, {mp, Status#player.mp}],
							  WhereList = [{id, Status#player.id}],
            				  spawn(fun()->db_agent:update_player_exp_data(ValueList, WhereList)end)
					end,
					Status#player{exp = Exp1, spirit = Spirit};	
				1 ->		%% 	升级了	
					ValueList = [
						 {exp,  Status#player.exp},
					     {lv,  Status#player.lv},
                         {spirit,  Status#player.spirit},
						 {hp, Status#player.hp},
						 {mp, Status#player.mp}
                     	],
					WhereList = [{id, Status#player.id}],
            		spawn(fun()->db_agent:update_player_exp_data(ValueList, WhereList)end),			
            		NextLvExp1  = next_lv_exp(Status#player.lv),
					%%人物等级成就升级的判断
					lib_achieve_outline:add_exp_check(Status#player.lv, Status#player.other#player_other.pid),
            		{ok, BinData} = pt_13:write(13003, [Status#player.hp_lim, Status#player.mp_lim,
														Status#player.lv, Status#player.exp, NextLvExp1, Status#player.spirit,
														Exp_ori]),
            		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            		%% 更新氏族成员缓存
            		mod_guild:role_upgrade(Status#player.id, Status#player.lv),
					Status
			end;
        true -> %% 已到升级
			Spirit =Status#player.spirit + Spt,		
            Lv = Status#player.lv + 1,
            %% 职业收益
			CareerInfo = get_attribute_parameter(Status#player.career),
            Status_1 = Status#player{
                exp = Exp - NextLvExp,
                lv = Lv,
                spirit = Spirit,
                forza = round(CareerInfo#ets_base_career.forza),
				physique = round(CareerInfo#ets_base_career.physique),
                agile = round(CareerInfo#ets_base_career.agile),
                wit = round(CareerInfo#ets_base_career.wit)
            },
            %% 人物属性计算			
            NewStatus = count_player_attribute(Status_1),
			NewStatus1 = NewStatus#player{
				hp = NewStatus#player.hp_lim,
				mp = NewStatus#player.mp_lim						  
			},
			
			%% 25级以后，每升三级都可以接收一次好友祝福
			NewStatus3 =
				if
					Lv > 24 andalso (Lv - 25) rem 3 =:= 0 ->
						lib_relationship:send_bless_notes(NewStatus1);
					true ->
						%% 前20级自动修炼法宝
						if
							Lv =< 20 ->
								%% 广播玩家升级用户新手换模型
								if
									Lv < 10 ->
										spawn(fun() ->
											{ok, Bin12042} = pt_12:write(12042, [NewStatus1#player.id, [{7, Lv}]]),
											mod_scene_agent:send_to_area_scene(NewStatus1#player.scene, NewStatus1#player.x, NewStatus1#player.y, Bin12042)
										end);
									true -> skip
								end,
								lib_make:auto_practise(NewStatus1);
							true ->
								NewStatus1
						end
				end,
			
			mod_master_apprentice:update_masterAndApprenteniceLv(NewStatus3),%%当等级提升时，修改师傅表和伯乐表中的等级信息
			%%玩家升级，刷新任务列表
			case Lv > 29 of
				true ->
					gen_server:cast(NewStatus3#player.other#player_other.pid_task,{'refresh_task',NewStatus3}),
					if 
						%% 30级自动进入伯乐榜 
						Lv == 30 ->
							%% 初始竞技场数据
							spawn(fun()-> lib_coliseum:init_coliseum_data(NewStatus3) end),
							%%三月活动
							%% 活动七：飞跃竞技场	
							lib_act_interf:check_player_arena_ranking(NewStatus3),
						   	pp_master_apprentice:handle(27031, NewStatus3, []);
					   	%% 40级自动出师 
						Lv == 40 ->
						   	pp_master_apprentice:handle(27040, NewStatus3, []);
					   	true ->
						   	skip
					end,
					%%2 秒之后开始检查玩家的轻功技能
					case Lv < 35 of
						true->
							erlang:send_after(1000*2, self(), {'UPDATE_LIGHT_SKILL'});
						false->skip
					end;
				false ->
					skip
			end,
			
			%%检查拜师指引
			case Lv >9 andalso Lv<37 of
				true->
					NewStatus3#player.other#player_other.pid!{'MASTER_LEAD'};
				false->skip
			end,
			
			%%升级任务接口
 			spawn(fun()->lib_task:event(up_level,{Lv},NewStatus3)end),
			%% 升级日志
			spawn(fun()->log:log_uplevel(NewStatus3,Exp,FromWhere)end),
			add_exp(NewStatus3, NewStatus3#player.exp, 1, Exp_ori, 0,FromWhere)
    end.

%% 增加铜币
add_coin(Status, 0) ->  
	Status;
add_coin(Status, Num) ->
    Coin = Status#player.coin + Num,
	case Coin >0 of
		false->Status#player{coin = 0};
		true->Status#player{coin = Coin}
	end.

%% 增加绑定铜币
add_bcoin(Status, 0) ->
    Status;
add_bcoin(Status, Num) ->
    BCoin = Status#player.bcoin + Num,
    case BCoin >0 of
		false->Status#player{bcoin = 0};
		true->Status#player{bcoin = BCoin}
	end.


%% 增加灵力
add_spirit(Status, 0) ->
    Status;
add_spirit(Status, Num) ->
	Spirit = Status#player.spirit + Num,
    case Spirit >0 of
		false->Status#player{spirit = 0};
		true->Status#player{spirit = Spirit}
	end.
%%扣除灵力
sub_spirit(Status,0) ->
	Status;
sub_spirit(Status,Num) ->
	if
		Status#player.spirit >= abs(Num) ->
			Status#player{spirit = Status#player.spirit - Num};
		true ->
			Status#player{spirit = 0}
	end.
		
%%增加修为
add_culture(Status,0) -> Status;
add_culture(Status,Num) ->
	Culture = Status#player.culture + Num,
	case Culture =<0 of
		true-> 
			Status#player{culture = 0};
		_-> 
			{ok, BinData} = pt_13:write(13052, [Num]),%%客户端右下角添加增加修为的提示
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			Status#player{culture = Culture}
	end.
%%扣减修为
sub_culture(Status,0) ->Status;
sub_culture(Status,Num) ->
	if
		Status#player.culture >= abs(Num) ->
			Status#player{culture = Status#player.culture - Num};
		true ->
			Status#player{culture = 0}
	end.

%%减少修为
%%即时写入数据库
reduce_culture(Status,0) -> 
	Status;
reduce_culture(Status,Num) ->
	Culture = Status#player.culture - Num,
	lib_achieve:check_achieve_finish_cast(Status#player.other#player_other.pid, 407, [abs(Num)]),%%减少修为的成就判断
	case Culture =<0 of
		true->
			spawn(fun()->db_agent:mm_update_player_info([{culture, 0}],[{id, Status#player.id}]) end),
			Status#player{culture = 0};
		_-> 
			spawn(fun()->db_agent:mm_update_player_info([{culture, Culture}],[{id, Status#player.id}]) end),
			Status#player{culture = Culture}
	end.

%% 增加荣誉
add_honor(Status, 0) ->
    Status;
add_honor(Status, Num) ->
	Honor = Status#player.honor + Num,
    case Honor >0 of
		false->Status#player{honor = 0};
		true->
			lib_achieve_outline:honor_ach_check(Honor, Status#player.other#player_other.pid),%%荣誉成就判断
			Status#player{honor = Honor}
	end.

%% 增加部落荣誉
add_realm_honor(Status, 0) ->
    Status;
add_realm_honor(Status, Num) ->
	Honor = Status#player.realm_honor + Num,
    case Honor >0 of
		false->Status#player{realm_honor = 0};
		true->Status#player{realm_honor = Honor}
	end.


%% 刷新客户端
refresh_client(Id, S) when is_integer(Id)  ->
    {ok, BinData} = pt_13:write(13005, S),
    lib_send:send_to_uid(Id, BinData);

refresh_client(Pid_send,S) when is_list(Pid_send) ->
	{ok,BinData} = pt_13:write(13005,S),
	lib_send:send_to_sid(Pid_send,BinData);
								
refresh_client(Socket,S) ->
	{ok,BinData} = pt_13:write(13005,S),
	lib_send:send_one(Socket,BinData).
%%或新人物信息
refresh_client(Ps) ->
    refresh_client(Ps#player.id, 1).

%% 更新客户端
refresh_spirit(Socket, Spr) ->
    {ok, BinData} = pt_13:write(13006, Spr),
    lib_send:send_one(Socket, BinData).

%% 经验
next_lv_exp(Lv) ->
    data_exp:get(Lv).

get_attribute_parameter(Career) ->
	 Career_id =
	 	case Career of
			1 -> 1;			%玄武--战士
         	2 -> 2;			%白虎--刺客
         	3 -> 3;			%青龙--弓手
        	4 -> 4;     	%朱雀--牧师
        	_ -> 5     		%麒麟--武尊
    	end,
	get_career_info(Career_id).	 

%% 一级属性转化为二级属性
attribute_1_to_2(Forza, Physique, Agile, Wit, Career, Lv) ->
    Info = get_attribute_parameter(Career),   	
    Hp = round(Info#ets_base_career.hp_init + Info#ets_base_career.hp_physique * Physique +  Info#ets_base_career.hp_lv*Lv),
    Mp = round(Info#ets_base_career.mp_init + Info#ets_base_career.mp_wit * Wit + Info#ets_base_career.mp_lv*Lv),
    MinAtt = round(Info#ets_base_career.att_init_min + Info#ets_base_career.att_forza * Forza + Info#ets_base_career.att_agile * Agile + Info#ets_base_career.att_wit * Wit),
   	MaxAtt = round(Info#ets_base_career.att_init_max + Info#ets_base_career.att_forza * Forza + Info#ets_base_career.att_agile * Agile + Info#ets_base_career.att_wit * Wit),
    Def = 0,
    Hit = round(Info#ets_base_career.hit_init  + Info#ets_base_career.hit_forza * Forza + Info#ets_base_career.hit_agile * Agile + Info#ets_base_career.hit_wit * Wit + Info#ets_base_career.hit_lv*Lv),
    Dodge = round(Info#ets_base_career.dodge_init + Info#ets_base_career.dodge_agile * Agile + Info#ets_base_career.dodge_lv*Lv),
    Crit = round(Info#ets_base_career.crit_init + Info#ets_base_career.crit_lv*Lv),
    Anti_wind = 0,
	Anti_fire = 0,
	Anti_water = 0,
	Anti_thunder = 0,
   	Anti_soil = 0,
    [Hp, Mp, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Anti_wind, Anti_fire, Anti_water, Anti_thunder, Anti_soil].

%%灵兽一级属性转化为二级属性[力量,体质,敏捷,智力]
pet_attribute_1_to_2(Forza, Physique, Agile, Wit, Career, _Lv)->
	 Info = get_attribute_parameter(Career),   
	 Hp = tool:ceil(Physique*10),
	 Att = case Career of
			   1 -> tool:ceil(Forza*2);	%玄武--- 力量
			   2 -> tool:ceil(Agile*2);	%白虎--- 敏捷
			   3 -> tool:ceil(Agile*2);	%青龙--- 敏捷
			   4 -> tool:ceil(Wit*2);  %朱雀---智力
			   _ -> tool:ceil(Forza*2) %麒麟--- 力量
    		end,
	 Hit =tool:ceil( Info#ets_base_career.hit_forza * Forza + Info#ets_base_career.hit_agile * Agile + Info#ets_base_career.hit_wit * Wit),
	 Mp = tool:ceil(Info#ets_base_career.mp_wit * Wit),
	 [Hp,Att,Hit,Mp].

%% 一级属性转化为二级属性
batt_attribute_1_to_2(Forza, Physique, Agile, Wit, Career, Lv) ->
	if Forza == 0 andalso Physique == 0 andalso Agile == 0 andalso Wit== 0 ->
		   [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
	   true ->
		   Info = get_attribute_parameter(Career),
		   Hp = round(Info#ets_base_career.hp_init + Info#ets_base_career.hp_physique * Physique +  Info#ets_base_career.hp_lv*Lv),
		   Mp = round(Info#ets_base_career.mp_init + Info#ets_base_career.mp_wit * Wit + Info#ets_base_career.mp_lv*Lv),
		   MinAtt = round(Info#ets_base_career.att_init_min + Info#ets_base_career.att_forza * Forza + Info#ets_base_career.att_agile * Agile + Info#ets_base_career.att_wit * Wit),
		   MaxAtt = round(Info#ets_base_career.att_init_max + Info#ets_base_career.att_forza * Forza + Info#ets_base_career.att_agile * Agile + Info#ets_base_career.att_wit * Wit),
		   Def = 0,
		   Hit = round(Info#ets_base_career.hit_init  + Info#ets_base_career.hit_forza * Forza + Info#ets_base_career.hit_agile * Agile + Info#ets_base_career.hit_wit * Wit + Info#ets_base_career.hit_lv*Lv),
		   Dodge = round(Info#ets_base_career.dodge_init + Info#ets_base_career.dodge_agile * Agile + Info#ets_base_career.dodge_lv*Lv),
		   Crit = round(Info#ets_base_career.crit_init + Info#ets_base_career.crit_lv*Lv),
		   Anti_wind = 0,
		   Anti_fire = 0,
		   Anti_water = 0,
		   Anti_thunder = 0,
		   Anti_soil = 0,
		   [Hp, Mp, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Anti_wind, Anti_fire, Anti_water, Anti_thunder, Anti_soil]
	end.

%%30级前每1级在原来基础上增加50气血
addhp_per_level(Level) ->
	case Level>30 of
		true -> 30*50;
		false -> Level*50
	end.

%% 计算玩家跑速 并场景广播速度
count_player_speed(Player)->
	NewPlayer = player_speed_count(Player),
	{ok, BinData} = pt_20:write(20009, [NewPlayer#player.id, NewPlayer#player.speed]),
    mod_scene_agent:send_to_area_scene(NewPlayer#player.scene, NewPlayer#player.x, NewPlayer#player.y, BinData),
	NewPlayer.
%% 玩家速度计算
player_speed_count(Player) ->
	MountSpeed = 
		case Player#player.mount > 0 of
			true ->
				lib_mount:get_mount_speed(Player#player.id);
			false ->
				0
		end,
	[_Forza, _Physique, _Wit, _Agile,Speed] = Player#player.other#player_other.base_player_attribute,
	[_E_forza,_E_physique,_E_wit,_E_agile,E_speed] = Player#player.other#player_other.equip_player_attribute,
	[SpeedMult, Hp] = 
		if 
			Player#player.carry_mark =:= 0 orelse Player#player.carry_mark =:= 27 orelse Player#player.carry_mark =:= 28 -> 
				[1, 0];
			Player#player.carry_mark =:= 3 -> 
				[0.5, 10000];
			Player#player.carry_mark =:= 26 ->
				[0.4, 0];
			true ->
				%%运镖，跑商,运旗、魔核的时候，直接减低17%的速度
				[0.6, 0]
		end,
	Player#player{
		speed = round((Speed + E_speed + MountSpeed) * SpeedMult),
		hp = Player#player.hp + Hp,
		hp_lim = Player#player.hp_lim + Hp
	}.
	
%% 人物属性计算
count_player_attribute(Player) ->
    %% 1 角色一级属性
    [Forza, Physique, Wit, Agile,Speed] = Player#player.other#player_other.base_player_attribute,
	%% 2 装备加成一级属性
	[E_forza,E_physique,E_wit,E_agile,E_speed] = Player#player.other#player_other.equip_player_attribute,
    %% 3 灵兽加成的一级属性
    [Pet_forza,Pet_agile,Pet_wit,Pet_physique] = Player#player.other#player_other.pet_attribute,
	%% 4 灵兽技能二级属性系数加成
	[[PetMult_hp,PetMult_hpFix],[PetMult_mp,PetMult_mpFix],[PetMult_def,PetMult_defFix],[PetMult_att,PetMult_attFix],[PetMult_anti,PetMult_antiFix],[PetMult_hit,PetMult_hitFix],[PetMult_dodge,PetMult_dodgeFix],[_PetMult_r_hp,_PetMult_r_hpFix],[_PetMult_r_mp,_PetMult_r_mpFix]]=
		Player#player.other#player_other.pet_skill_mult_attribute,
	%% 5 技能BUFF加成（包括一级属性和二级属性）
	[SkillBuffHpLim, SkillBuffAgile, SkillBuffPhysique, SkillBuffDef, SkillBuffAnti, SkillBuffHit, CastleRushAtt, CastRushAnti] = 
			get_skill_buff_attr(Player#player.other#player_other.battle_status),
	%% 6被动技能加成
	All_Passive_Ids = data_passive_skill:get_skill_id_list(),
	[P_atk, P_def, P_hp_lim, P_mp_lim, P_dodge, P_hit, P_crit, P_anti_wind, 
	 P_anti_thunder, P_anti_water, P_anti_fire, P_anti_soil, P_lower_hp, P_lower_mp,
	 P_lower_anti, P_lower_speed] = lib_skill:count_passive_att(All_Passive_Ids, Player#player.other#player_other.passive_skill, []),
	%% 7 装备二级属性的系数加成
	[Mult_hp,Mult_crit,Mult_attack] = Player#player.other#player_other.equip_mult_attribute,
	%% 8 经脉二级属性加成
	[MerHp,MerDef,MerMp,MerHit,MerCrit,MerShun,MerAtt,MerTen,LgHp,LgMp,LgAtt] = Player#player.other#player_other.meridian_attribute,
    %% 9 原始二级属性
    [_Hp_lim, _Mp_lim, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil] =
							Player#player.other#player_other.base_attribute, 
	%% 10  装备二级属性加成
    [Hp_E2, Mp_E2, MaxAtt_E2, MinAtt_E2, Def_E2, Hit_E2, Dodge_E2, Crit_E2, Anti_wind_E2,Anti_fire_E2,Anti_water_E2,Anti_thunder_E2,Anti_soil_E2,Anti_rift_E2] = Player#player.other#player_other.equip_attribute, 
	%% 11 当前装备
	[WQ,YF,_Fbyf,_Spyf,_MountTypeId] = Player#player.other#player_other.equip_current,
	%% 12 坐骑信息
    [MountType,MountSpeed,MountStren] = goods_util:get_mount_info(Player),
	%% 13氏族高级技能加成[13氏族攻击，14氏族防御，15氏族气血，16氏族法力，17氏族命中，18氏族闪躲，19氏族暴击]
	#guild_h_skill{g_att = GuAttack, 
				   g_def = GuDef,
				   g_hp = GuHp, 
				   g_mp = GuMp, 
				   g_hit = GuHit, 
				   g_dodge = GuDodge, 
				   g_crit = GuCrit} = Player#player.other#player_other.guild_h_skills,
	
	%% 14 获取成就系统中八神珠的属性加成
	[AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti] =
		data_achieve:get_pearl_add(Player#player.other#player_other.ach_pearl),
	%% 神器技能属性加成
	[DpHp,DpAttack,DpDef,DpAnti] = lib_deputy:get_deputy_add_attribute(Player#player.id),
	%%坐骑加成
	[MountHp,MountMp,MountAtt,MountDef,MountHit,MountDodge,MountCrit,MountAnti_wind,MountAnti_fire,MountAnti_water,MountAnti_thunder,MountAnti_soil] = 
																				Player#player.other#player_other.mount_mult_attribute,
	%%坐骑战斗力
	Mount_Batt_val = data_mount:count_mount_batt(Player#player.other#player_other.mount_mult_attribute),
	%%封神纪元属性加成
	[FsAttack,FsHP,FsMP,FsDef,FsAntiAll] = lib_era:get_player_era_attribute(Player#player.id),
	%% 一级属性转化为二级属性
    [Hp_2, Mp_2, MaxAtt_2, MinAtt_2, Def_2, Hit_2, Dodge_2, Crit_2, Anti_wind_2,Anti_fire_2,Anti_water_2,Anti_thunder_2,Anti_soil_2] =
		attribute_1_to_2(
			Forza + E_forza,
			Physique + E_physique  + SkillBuffPhysique,
			Agile + E_agile  + SkillBuffAgile,
			Wit + E_wit,
			Player#player.career,
			Player#player.lv
		),
		%% 人物一级属性转化为二级属性
    [Batt_Hp_1, Batt_Mp_1, Batt_MaxAtt_1, Batt_MinAtt_1, Batt_Def_1, Batt_Hit_1, Batt_Dodge_1, Batt_Crit_1, Batt_Anti_wind_1,Batt_Anti_fire_1,Batt_Anti_water_1,Batt_Anti_thunder_1,Batt_Anti_soil_1] =
		batt_attribute_1_to_2(
			Forza,
			Physique,
			Agile,
			Wit,
			Player#player.career,
			Player#player.lv
		),
	%% 装备一级属性转化为二级属性
    [Batt_Hp_2, Batt_Mp_2, Batt_MaxAtt_2, Batt_MinAtt_2, Batt_Def_2, Batt_Hit_2, Batt_Dodge_2, Batt_Crit_2, Batt_Anti_wind_2,Batt_Anti_fire_2,Batt_Anti_water_2,Batt_Anti_thunder_2,Batt_Anti_soil_2] =
		batt_attribute_1_to_2(
			E_forza,
			E_physique,
			E_agile,
			E_wit ,
			Player#player.career,
			Player#player.lv
		),
	 %% 3 灵兽加成的二级属性
    [Pet_hp,Pet_att,Pet_hit,Pet_mp] = pet_attribute_1_to_2(Pet_forza,Pet_physique,Pet_agile,Pet_wit,Player#player.career,Player#player.lv),
	%%物品buff加成系数，默认为1
	%%PlayerStatus#player.other#player_other.goods_buff#goods_cur_buff
	%%30级前每1级在原来基础上增加50气血
	PerLevelHp = addhp_per_level(Player#player.lv),
    %%物品buff倍数
	
	IsChrTurn = lists:member(Player#player.other#player_other.turned, [10941,10942,10943,10944,10945,10946,10947,10948,10949,10950]),
	[{Def_4,Atk_4,Hp_4,Hit_4,Dodge_4,Crit_4,Anti_4},{Forza_4,Agile_4,Wit_4,Att_4_Per,Hp_4_Per,Def_4_Per,Anti_4_Per}] = 
	if %%用圣诞时装变身加成属性
		IsChrTurn == true ->
			[{0,0,0,0,0,0,0},{88,88,88,0.02,0.02,0.02,0.02}];
		true ->
			case  Player#player.other#player_other.goods_buff#goods_cur_buff.turned_mult =:= [] of
			true -> [{0,0,0,0,0,0,0},{0,0,0,0,0,0,0}];
			false ->
				case Player#player.other#player_other.goods_buff#goods_cur_buff.turned_mult of
					[{Fields,Value}] ->
						case Fields of
							def ->
								[{Value,0,0,0,0,0,0},{0,0,0,0,0,0,0}];
							atk ->
								[{0,Value,0,0,0,0,0},{0,0,0,0,0,0,0}];
							hp_lim ->
								[{0,0,Value,0,0,0,0},{0,0,0,0,0,0,0}];
							hit ->
								[{0,0,0,Value,0,0,0},{0,0,0,0,0,0,0}];
							dodge ->
								[{0,0,0,0,Value,0,0},{0,0,0,0,0,0,0}];
							crit ->
								[{0,0,0,0,0,Value,0},{0,0,0,0,0,0,0}];
							anti ->
								[{0,0,0,0,0,0,Value},{0,0,0,0,0,0,0}];
							_ ->
								[{0,0,0,0,0,0,0},{0,0,0,0,0,0,0}]
						end;
					_ ->						
						[{0,0,0,0,0,0,0},{0,0,0,0,0,0,0}]
				end
		end
	end,
	
	[SkillIntDef, SkillParamDef] = 
		case is_float(SkillBuffDef) of
			true ->
				[0, SkillBuffDef];
			false ->
				[SkillBuffDef, 0]
		end,
	[SkillIntHit, SkillParamHit] = 
		case is_float(SkillBuffHit) of
			true ->
				[0, SkillBuffHit];
			false ->
				[SkillBuffHit, 0]
		end,
	[SpeedMult,Hp_Carry] = if Player#player.carry_mark =:= 0 
								orelse Player#player.carry_mark =:= 27
								orelse Player#player.carry_mark =:= 28 -> [1,0];
							  Player#player.carry_mark =:= 3 -> [0.5,10000];
							  Player#player.carry_mark =:= 26 ->[0.4,0];
							  true->
								  %%运镖，跑商,运旗、魔核的时候，直接减低17%的速度
								  [0.6,0]
						 end,
	%%组队亲密度加成参数
	{_ExpParam, Mp_team, Hp_team, Ap_team, Ack_team} = lib_relationship:get_close_res(Player#player.other#player_other.team_buff_level),
	
	%%气血法力上限处理
	Hp_lim = round((Hp_2 + Hp_E2 + MerHp + Pet_hp + SkillBuffHpLim + PerLevelHp + P_hp_lim + DpHp) * Player#player.other#player_other.goods_buff#goods_cur_buff.hp_lim * (1 + Mult_hp/100 + AchHp/100 + Hp_4_Per) * (1+PetMult_hp) + GuHp + PetMult_hpFix + MountHp + Hp_Carry + Hp_team + Hp_4 + LgHp +FsHP),
    Mp_lim = round((Mp_2 + Mp_E2+MerMp+Pet_mp + P_mp_lim) * Player#player.other#player_other.goods_buff#goods_cur_buff.mp_lim * (1+PetMult_mp) * (1+AchMp/100) + GuMp + PetMult_mpFix + MountMp + Mp_team + LgMp +FsMP),

	%% 属性计算
    case Player#player.hp > Hp_lim of
		true ->  
			NewHp = Hp_lim;
		false ->
			case Player#player.lv =:=1 of
				true -> 
					NewHp = Hp_lim;
				false -> 
					NewHp = Player#player.hp
			end
	end,
    case Player#player.mp >  Mp_lim of
		true ->  
			NewMp = Mp_lim;
		false -> 
			NewMp = Player#player.mp
	end,
	%%封神霸主功勋属性[抗性穿透}_]
	[WarHonor_Anti_Rift|_] = Player#player.other#player_other.war_honor_value,
	
	%% 计算战斗力值，不包括物品技能加成属性(请按格式在此添加相关的属性值)
	%%战斗力type 1人物　2经脉　3八神珠　4装备　5被动技能　6氏族技能　7灵兽  8副法宝  9坐骑
	%%战斗力key hp_lim,mp_lim,max_attack,min_attack,def,hit,dodge,crit,anti_wind,anti_fire,anti_water,anti_thunder,anti_soil
	%%战斗力格式[{1,{hp_lim,Hp_1,1,1}}]->[{类型,{战斗力key,战斗力值,数字或百分比(1为数字,2为百分比,3是算出前面结果后再加固定值)}}]
	Batt_value_list1 = lists:append([{1,{hp_lim,Batt_Hp_1,1}},{4,{hp_lim,Batt_Hp_2,1}},{4,{hp_lim,Hp_E2,1}},{2,{hp_lim,MerHp+LgHp,1}},{7,{hp_lim,Pet_hp,1}},
									 {1,{hp_lim,PerLevelHp,1}},{5,{hp_lim,P_hp_lim,1}},{1,{hp_lim,(PetMult_hp+Mult_hp/100+AchHp/100),2}},{7,{hp_lim,PetMult_hp,2}},{4,{hp_lim,Mult_hp/100,2}},
									 {3,{hp_lim,AchHp/100,2}},{6,{hp_lim,GuHp,3}},{7,{hp_lim,PetMult_hpFix,3}},{1,{hp_lim,FsHP,1}}],[]),
	
	Batt_value_list2 = lists:append([{1,{mp_lim,Batt_Mp_1,1}},{4,{mp_lim,Batt_Mp_2,1}},{4,{mp_lim,Mp_E2,1}},{2,{mp_lim,MerMp+LgMp,1}},{7,{mp_lim,Pet_mp,1}},
									 {5,{mp_lim,P_mp_lim,1}},{1,{mp_lim,(PetMult_mp+AchHp/100),2}},{7,{mp_lim,PetMult_mp,2}},{3,{mp_lim,AchMp/100,2}},{6,{mp_lim,GuMp,3}},{7,{mp_lim,PetMult_mpFix,3}},
									{1,{mp_lim,FsMP,1}}],Batt_value_list1),
	
	Batt_value_list3 = lists:append([{1,{max_attack,MaxAtt,1}},{1,{max_attack,Batt_MaxAtt_1,1}},{4,{max_attack,Batt_MaxAtt_2,1}},{4,{max_attack,MaxAtt_E2,1}},{2,{max_attack,MerAtt+LgAtt,1}},{7,{max_attack,Pet_att,1}},
									 {5,{max_attack,P_atk,1}},{1,{max_attack,(PetMult_att+(Mult_attack+AchAtt)/100),2}},{4,{max_attack,Mult_attack/100,2}},{3,{max_attack,AchAtt/100,2}},{7,{max_attack,PetMult_att,2}},
									 {6,{max_attack,GuAttack,3}},{7,{max_attack,PetMult_attFix,3}},{1,{max_attack,FsAttack,1}}],Batt_value_list2),
	
	Batt_value_list4 = lists:append([{1,{min_attack,MinAtt,1}},{1,{min_attack,Batt_MinAtt_1,1}},{4,{min_attack,Batt_MinAtt_2,1}},{4,{min_attack,MinAtt_E2,1}},{2,{min_attack,MerAtt+LgAtt,1}},{7,{min_attack,Pet_att,1}},
									 {5,{min_attack,P_atk,1}},{1,{min_attack,(PetMult_att+(AchAtt)/100),2}},{3,{min_attack,AchAtt/100,2}},{7,{min_attack,PetMult_att,2}},
									 {6,{min_attack,GuAttack,3}},{7,{min_attack,PetMult_attFix,3}}],Batt_value_list3),
	Batt_value_list5 = lists:append([{1,{def,Def,1}},{1,{def,Batt_Def_1,1}},{4,{def,Batt_Def_2,1}},{4,{def,Def_E2,1}},{2,{def,MerDef,1}},{5,{def,P_def,1}},{1,{def,(PetMult_def+(AchDef)/100),2}},
									 {3,{def,AchDef/100,2}},{7,{def,PetMult_def,2}},{6,{def,GuDef,3}},{7,{def,PetMult_defFix,3}},{1,{def,FsDef,1}}],Batt_value_list4),
	
	if Batt_Hit_2-800 >= 0 -> NewHit = Batt_Hit_2-800;
	   true -> NewHit = 0
	end,
	Batt_value_list6 = lists:append([{1,{hit,(Hit-800),1}},{1,{hit,Batt_Hit_1,1}},{4,{hit,NewHit,1}},{4,{hit,Hit_E2,1}},{2,{hit,MerHit,1}},{5,{hit,P_hit,1}},{1,{hit,(PetMult_hit+(AchHit)/100),2}},
									 {3,{hit,AchHit/100,2}},{7,{hit,PetMult_hit,2}},{6,{hit,GuHit,3}},{7,{hit,PetMult_hitFix,3}}],Batt_value_list5),
	
	Batt_value_list7 = lists:append([{1,{dodge,Dodge,1}},{1,{dodge,Batt_Dodge_1,1}},{4,{dodge,Batt_Dodge_2,1}},{4,{dodge,Dodge_E2,1}},{2,{dodge,MerShun,1}},{5,{dodge,P_dodge,1}},{1,{dodge,(PetMult_dodge+(AchDod)/100),2}},
									 {3,{dodge,AchCrit/100,2}},{7,{dodge,PetMult_dodge,2}},{6,{dodge,GuDodge,3}},{7,{dodge,PetMult_dodgeFix,3}}],Batt_value_list6),
	
	Batt_value_list8 = lists:append([{1,{crit,Crit,1}},{1,{crit,Batt_Crit_1,1}},{4,{crit,Batt_Crit_2,1}},{4,{crit,Crit_E2,1}},{2,{crit,MerCrit,1}},{5,{crit,P_crit,1}},{1,{crit,(Mult_crit/100+AchCrit/100),2}},
									 {3,{crit,AchDod/100,2}},{4,{crit,Mult_crit/100,2}},{6,{crit,GuCrit,3}}],Batt_value_list7),
	
	Batt_value_list9 = lists:append([{1,{anti_wind,Anti_wind,1}},{1,{anti_wind,Batt_Anti_wind_1,1}},{4,{anti_wind,Batt_Anti_wind_2,1}},{4,{anti_wind,Anti_wind_E2,1}},{2,{anti_wind,MerTen,1}},{5,{anti_wind,P_anti_wind,1}},{1,{anti_wind,(PetMult_anti+AchAnti/100),2}},
									 {3,{anti_wind,AchAnti/100,2}},{7,{anti_wind,PetMult_anti,2}},{7,{anti_wind,PetMult_antiFix,3}},{1,{anti_wind,FsAntiAll,1}}],Batt_value_list8),
	
	Batt_value_list10 = lists:append([{1,{anti_fire,Anti_fire,1}},{1,{anti_fire,Batt_Anti_fire_1,1}},{4,{anti_fire,Batt_Anti_fire_2,1}},{4,{anti_fire,Anti_fire_E2,1}},{2,{anti_fire,MerTen,1}},{5,{anti_fire,P_anti_fire,1}},{1,{anti_fire,(PetMult_anti+AchAnti/100),2}},
									 {3,{anti_fire,AchAnti/100,2}},{7,{anti_fire,PetMult_anti,2}},{7,{anti_fire,PetMult_antiFix,3}},{1,{anti_fire,FsAntiAll,1}}],Batt_value_list9),
	
	Batt_value_list11 = lists:append([{1,{anti_water,Anti_water,1}},{1,{anti_water,Batt_Anti_water_1,1}},{4,{anti_water,Batt_Anti_water_2,1}},{4,{anti_water,Anti_water_E2,1}},{2,{anti_water,MerTen,1}},{5,{anti_water,P_anti_water,1}},{1,{anti_water,(PetMult_anti+AchAnti/100),2}},
									 {3,{anti_water,AchAnti/100,2}},{7,{anti_water,PetMult_anti,2}},{7,{anti_water,PetMult_antiFix,3}},{1,{anti_water,FsAntiAll,1}}],Batt_value_list10),
	
	Batt_value_list12 = lists:append([{1,{anti_thunder,Anti_thunder,1}},{1,{anti_thunder,Batt_Anti_thunder_1,1}},{4,{anti_thunder,Batt_Anti_thunder_2,1}},{4,{anti_thunder,Anti_thunder_E2,1}},{2,{anti_thunder,MerTen,1}},{5,{anti_thunder,P_anti_thunder,1}},{1,{anti_thunder,(PetMult_anti+AchAnti/100),2}},
									 {3,{anti_thunder,AchAnti/100,2}},{7,{anti_thunder,PetMult_anti,2}},{7,{anti_thunder,PetMult_antiFix,3}},{1,{anti_thunder,FsAntiAll,1}}],Batt_value_list11),
	
	Batt_value_list13 = lists:append([{1,{anti_soil,Anti_soil,1}},{1,{anti_soil,Batt_Anti_soil_1,1}},{4,{anti_soil,Batt_Anti_soil_2,1}},{4,{anti_soil,Anti_soil_E2,1}},{2,{anti_soil,MerTen,1}},{5,{anti_soil,P_anti_soil,1}},{1,{anti_soil,(PetMult_anti+AchAnti/100),2}},
									 {3,{anti_soil,AchAnti/100,2}},{7,{anti_soil,PetMult_anti,2}},{7,{anti_soil,PetMult_antiFix,3}},{1,{anti_soil,FsAntiAll,1}}],Batt_value_list12),
	
	Player2 = Player#player{
        hp = NewHp,%气血法力值，上限值不能在此再赋值
        mp = NewMp,%%注意
		hp_lim = Hp_lim,%%注意
		mp_lim = Mp_lim,%%注意
        forza = round(Forza + E_forza + Forza_4),
        agile = round(Agile + E_agile  + SkillBuffAgile + Agile_4),
        wit = round(Wit + E_wit +Wit_4 ),
        physique = round(Physique + E_physique  + SkillBuffPhysique ),
        speed = round((Speed + E_speed + MountSpeed)*SpeedMult),
		max_attack =round((MaxAtt + MaxAtt_2 + MaxAtt_E2+MerAtt+Pet_att+Ack_team+Atk_4+P_atk+DpAttack) * (1+(Mult_attack+AchAtt)/100+PetMult_att+Att_4_Per) + GuAttack + PetMult_attFix + CastleRushAtt + MountAtt + LgAtt +FsAttack),
        min_attack =round((MinAtt + MinAtt_2 + MinAtt_E2+MerAtt+Pet_att+Ack_team+Atk_4+P_atk+DpAttack) * (1+(Mult_attack+AchAtt)/100+PetMult_att+Att_4_Per) + GuAttack + PetMult_attFix + CastleRushAtt + MountAtt + LgAtt +FsAttack) ,
        def = round((Def + Def_2 + Def_E2 + MerDef + SkillIntDef + Def_4 + P_def + DpDef) * (Player#player.other#player_other.goods_buff#goods_cur_buff.def_mult * (1+ PetMult_def + SkillParamDef + Def_4_Per)+ AchDef/100) + GuDef + PetMult_defFix + MountDef+FsDef),
        hit = round((Hit + Hit_2 + Hit_E2+MerHit + Pet_hit+SkillIntHit + Hit_4 + P_hit) * (1+PetMult_hit + SkillParamHit+ AchHit/100) + GuHit + PetMult_hitFix + MountHit),
        dodge = round((Dodge + Dodge_2 + Dodge_E2+MerShun + Dodge_4 + P_dodge) * (1+PetMult_dodge+AchDod/100) + GuDodge + PetMult_dodgeFix + MountDodge) ,
        crit = round((Crit + Crit_2 + Crit_E2+MerCrit + Crit_4 + P_crit) * (1+Mult_crit /100 + AchCrit/100 ) + GuCrit + MountCrit),
        anti_wind = round((Anti_wind + Anti_wind_2 + Anti_wind_E2+MerTen + Ap_team + Anti_4 + P_anti_wind + DpAnti) * (1 + PetMult_anti + SkillBuffAnti + AchAnti/100 + Anti_4_Per) + PetMult_antiFix + CastRushAnti + MountAnti_wind + FsAntiAll),
        anti_fire = round((Anti_fire + Anti_fire_2 + Anti_fire_E2+MerTen + Ap_team + Anti_4 + P_anti_fire + DpAnti) * (1 + PetMult_anti + SkillBuffAnti + AchAnti/100 + Anti_4_Per) + PetMult_antiFix + CastRushAnti + MountAnti_fire +FsAntiAll),
        anti_water =round((Anti_water + Anti_water_2 + Anti_water_E2 + MerTen + Ap_team + Anti_4 + P_anti_water + DpAnti) * (1 + PetMult_anti + SkillBuffAnti + AchAnti/100 + Anti_4_Per) + PetMult_antiFix + CastRushAnti + MountAnti_water +FsAntiAll),
        anti_thunder = round((Anti_thunder + Anti_thunder_2 + Anti_thunder_E2+MerTen + Ap_team + Anti_4 + P_anti_thunder + DpAnti)*(1 + PetMult_anti + SkillBuffAnti + AchAnti/100 + Anti_4_Per) + PetMult_antiFix + CastRushAnti + MountAnti_thunder+FsAntiAll),
        anti_soil = round((Anti_soil + Anti_soil_2 + Anti_soil_E2+MerTen + Ap_team + Anti_4 + P_anti_soil + DpAnti)*(1 + PetMult_anti + SkillBuffAnti + AchAnti/100 + Anti_4_Per) + PetMult_antiFix + CastRushAnti + MountAnti_soil+FsAntiAll),
		anti_rift = Anti_rift_E2+WarHonor_Anti_Rift, 
        other = Player#player.other#player_other{
			mount_stren = MountStren,
			two_attribute = [Hp_2, Mp_2, MaxAtt_2, MinAtt_2, Def_2, Hit_2, Dodge_2, Crit_2, Anti_wind_2,Anti_fire_2,Anti_water_2,Anti_thunder_2,Anti_soil_2],
          	equip_current = [WQ,YF,_Fbyf,_Spyf,MountType],
			deputy_passive_att = [P_lower_hp, P_lower_mp, P_lower_anti, P_lower_speed]
      	}
   	},
	Deputy_batt_val = lib_deputy:get_player_deputy_batt_val(Player2),
	%%更新玩家的战斗力值
	Batt_value = count_player_batt_value1(Player2#player.id,Batt_value_list13,Deputy_batt_val,Mount_Batt_val), 
	Player3 = Player2#player{other = Player2#player.other#player_other{batt_value =Batt_value}},
	Player3.

%% 发送角色属性改变通知
send_player_attribute(Status, ChangeReason) ->
%% 	Status = lib_vip:check_vip_state(PlayerStatus),
    ExpLimit = next_lv_exp(Status#player.lv),
	EquipCurrent = Status#player.other#player_other.equip_current,
	[AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti] = 
		data_achieve:get_pearl_equiped_ornot(Status#player.other#player_other.ach_pearl),
 	try
    {ok, BinData} = pt_13:write(13001, [ 
            Status#player.scene,
            Status#player.x,
            Status#player.y,
            Status#player.id,
            Status#player.hp,
            Status#player.hp_lim,
            Status#player.mp,
            Status#player.mp_lim,
            Status#player.sex,
            Status#player.lv,
            Status#player.exp,
            ExpLimit,
            Status#player.career,
            Status#player.nickname,
			Status#player.max_attack,
			Status#player.min_attack,
            Status#player.def,
            Status#player.forza,
            Status#player.physique,
            Status#player.agile,
            Status#player.wit,
            Status#player.hit,
            Status#player.dodge,
            Status#player.crit,
            Status#player.guild_id,
            Status#player.guild_name,
            Status#player.guild_position,
            Status#player.realm,
            Status#player.gold,
            Status#player.cash,
            Status#player.coin,
            Status#player.bcoin,
            Status#player.att_area,
            Status#player.spirit,
            Status#player.speed,
            Status#player.att_speed,
            EquipCurrent,
			Status#player.mount,
            Status#player.pk_mode,
            Status#player.title,
            Status#player.couple_name,
            Status#player.position,
            Status#player.evil,
            Status#player.realm_honor,
            Status#player.culture,
            Status#player.state,
            Status#player.anti_wind,
            Status#player.anti_fire,
            Status#player.anti_water,
            Status#player.anti_thunder,
			Status#player.anti_soil,
            Status#player.status,
			Status#player.other#player_other.stren,
			Status#player.other#player_other.suitid,
			ChangeReason,
			Status#player.arena_score,
			Status#player.vip,
			Status#player.vip_time,
			Status#player.other#player_other.mount_stren,
			Status#player.other#player_other.titles,
			Status#player.other#player_other.is_spring,
			AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti,
			Status#player.other#player_other.batt_value,
			Status#player.other#player_other.turned,
			Status#player.other#player_other.accept,
			Status#player.other#player_other.deputy_prof_lv,
			Status#player.other#player_other.war_honor,
			Status#player.other#player_other.fullstren,
			Status#player.other#player_other.fbyfstren,
			Status#player.other#player_other.spyfstren,
			Status#player.other#player_other.pet_batt_skill
        ]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
 	catch
 		_:_ -> io:format("send_player_attribute// ~p, ~n",[ChangeReason])
 	end.

%% 发送角色属性改变通知
send_player_attribute2(Player, ChangeReason) ->
 	AttrList = [
   		Player#player.hp,
       	Player#player.hp_lim,
     	Player#player.mp,
      	Player#player.mp_lim,
    	Player#player.gold,
   		Player#player.cash,
     	Player#player.coin,
   		Player#player.bcoin,
		ChangeReason
 	],
	{ok, BinData} = pt_13:write(13011, AttrList),
   	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData).

%%计算玩家战斗力值
count_player_batt_value(Status) ->
	Batt_max_mattck = Status#player.max_attack,
	Batt_min_mattck = Status#player.min_attack,
	Batt_def = Status#player.def,
	Batt_hp = Status#player.hp_lim,
	Batt_mp = Status#player.mp_lim,
	Batt_hit = Status#player.hit,
	Batt_dodge = Status#player.dodge,
	Batt_crit = Status#player.crit,
	Batt_value = round(Batt_max_mattck*0.35 + Batt_min_mattck*0.35 + Batt_def * 0.04 + Batt_hp * 0.05 + Batt_mp * 0.01 + Batt_hit * 0.4 + Batt_dodge * 0.6 + Batt_crit * 0.7 + 
						  Status#player.anti_wind*0.1 + Status#player.anti_fire*0.1 + Status#player.anti_water*0.1 + Status#player.anti_thunder*0.1 + Status#player.anti_soil*0.1),
	Batt_value.

%%战斗力type 1人物　2经脉　3八神珠　4装备　5被动技能　6氏族技能　7灵兽  8副法宝 9坐骑
%%战斗力key hp_lim,mp_lim,max_attack,min_attack,def,hit,dodge,crit,anti_wind,anti_fire,anti_water,anti_thunder,anti_soil
%%战斗力格式[{1,{hp_lim,Hp_1,1,1}}]->[{类型,{战斗力key,战斗力值,数字或百分比(1为数字,2为百分比,3是算出前面结果后再加固定值)}}]
count_player_batt_value1(PlayerId,Batt_value_list,Deputy_batt_val,Mount_Batt_val) ->
	ResultList = filter_batt_value(Batt_value_list,[],[],[],[],[],[],[]),
	Result = count_batt_value(ResultList,Deputy_batt_val,Mount_Batt_val),
	Outpet = lib_pet:get_out_pet(PlayerId),
	if
		Result == [] -> 
			[];
		true ->
			[List1,List2,List3,List4,List5,List6,List7,List8,List9] = Result,
			if
				is_record(Outpet,ets_pet) ->
					[Type,Value] = List7,
					[List1,List2,List3,List4,List5,List6,[Type,round(Value*1)],List8,List9];
				true ->
					[List1,List2,List3,List4,List5,List6,[7,0],List8,List9]
			end
	end.

%%战斗力type 1人物,2经脉,3八神珠,4装备,5被动技能,6氏族技能,7灵兽
filter_batt_value([],List1,List2,List3,List4,List5,List6,List7) ->
	[List1,List2,List3,List4,List5,List6,List7];
filter_batt_value([H | RestList],List1,List2,List3,List4,List5,List6,List7) ->
	{Type,{_Key,Value,_ValueType}} = H,
	if Type == 1 andalso Value /= 0 ->
		   NewList1 = [H | List1],
		   filter_batt_value(RestList,NewList1,List2,List3,List4,List5,List6,List7);
	   Type == 2 andalso Value /= 0 ->
		   NewList2 = [H | List2],
		   filter_batt_value(RestList,List1,NewList2,List3,List4,List5,List6,List7);
	   Type == 3 andalso Value /= 0 ->
		   NewList3 = [H | List3],
		   filter_batt_value(RestList,List1,List2,NewList3,List4,List5,List6,List7);
	   Type == 4 andalso Value /= 0 ->
		   NewList4 = [H | List4],
		   filter_batt_value(RestList,List1,List2,List3,NewList4,List5,List6,List7);
	   Type == 5 andalso Value /= 0 ->
		   NewList5 = [H | List5],
		   filter_batt_value(RestList,List1,List2,List3,List4,NewList5,List6,List7);
	   Type == 6 andalso Value /= 0 ->
		   NewList6 = [H | List6],
		   filter_batt_value(RestList,List1,List2,List3,List4,List5,NewList6,List7);
	   Type == 7 andalso Value /= 0 ->
		   NewList7 = [H | List7],
		   filter_batt_value(RestList,List1,List2,List3,List4,List5,List6,NewList7);
	   true ->
		    filter_batt_value(RestList,List1,List2,List3,List4,List5,List6,List7)
	end.

filter_child_batt_value([],List1,List2,List3) ->
	[List1,List2,List3];
filter_child_batt_value([H | RestList],List1,List2,List3) ->
	{_Type,{Key,Value,ValueType}} = H,
	if 
		ValueType == 1 ->
			case lists:keyfind(Key, 1, List1) of
				false ->
					NewList1 = [{Key,Value} | List1],
					filter_child_batt_value(RestList,NewList1,List2,List3);
				{Key,Value1} ->
					NewList1 =  lists:keyreplace(Key, 1, List1, {Key,Value+Value1}),
					filter_child_batt_value(RestList,NewList1,List2,List3)
			end;
		ValueType == 2 ->
			case lists:keyfind(Key, 1, List2) of
				false ->
					NewList2 = [{Key,Value} | List2],
					filter_child_batt_value(RestList,List1,NewList2,List3);
				{Key,Value1} ->
					NewList2 =  lists:keyreplace(Key, 1, List2, {Key,Value+Value1}),
					filter_child_batt_value(RestList,List1,NewList2,List3)
			end;
		ValueType == 3 ->
			case lists:keyfind(Key, 1, List3) of
				false ->
					NewList3 = [{Key,Value} | List3],
					filter_child_batt_value(RestList,List1,List2,NewList3);
				{Key,Value1} ->
					NewList3 =  lists:keyreplace(Key, 1, List3, {Key,Value+Value1}),
					filter_child_batt_value(RestList,List1,List2,NewList3)
			end;
	true ->
		filter_child_batt_value(RestList,List1,List2,List3)
	end.

%%计算战斗力值
%%战斗力type 1人物　2经脉　3八神珠　4装备　5被动技能　6氏族技能　7灵兽
%%战斗力key hp_lim,mp_lim,max_attack,min_attack,def,hit,dodge,crit,anti_wind,anti_fire,anti_water,anti_thunder,anti_soil
%%战斗力格式[{1,{hp_lim,Hp_1,1,1}}]->[{类型,{战斗力key,战斗力值,数字或百分比(1为数字,2为百分比), 基数还是固定值(1是基数,2是算出前面结果后再加固定值)}}]
count_batt_value(ResultList,Deputy_batt_val,Mount_Batt_val) ->
	[List1,List2,List3,List4,List5,List6,List7] = filter_batt_value(lists:flatten(ResultList),[],[],[],[],[],[],[]),
	[NewList1,NewList11,NewList111] = filter_child_batt_value(List1,[],[],[]),
	[NewList2,NewList22,NewList222] = filter_child_batt_value(List2,[],[],[]),
	[NewList3,NewList33,NewList333] = filter_child_batt_value(List3,[],[],[]),
	[NewList4,NewList44,NewList444] = filter_child_batt_value(List4,[],[],[]),
	[NewList5,NewList55,NewList555] = filter_child_batt_value(List5,[],[],[]),
	[NewList6,NewList66,NewList666] = filter_child_batt_value(List6,[],[],[]),
	[NewList7,NewList77,NewList777] = filter_child_batt_value(List7,[],[],[]),
	%%防御，全抗从经脉中取数据作为基础数据
	
	NewList8 = [NewList1,NewList2,NewList3,NewList4,NewList5,NewList6,NewList7],
	NewList88 = [NewList11,NewList22,NewList33,NewList44,NewList55,NewList66,NewList77],
	NewList888 = [NewList111,NewList222,NewList333,NewList444,NewList555,NewList666,NewList777],
	F = fun(Num) ->
				List8 = lists:nth(Num, NewList8),
				List88 = lists:nth(Num, NewList88),
				List888 = lists:nth(Num, NewList888),
				if List8 == [] andalso List88 == [] andalso List888 == [] ->
					   [Num,0];
				   List8 == [] andalso List88 == [] andalso List888 =/= [] ->
					   F1 = fun(Key,Value) ->
									count_batt(Key,Value)
							end,
					   BattNum = lists:sum([F1(Key,Value) || {Key,Value} <- List888]),
					   [Num,BattNum];
				   List8 == [] andalso List88 =/= [] ->
					  F2 = fun(Key2,Value2) ->
										if Num =/=  1 ->
											   %%防御，全抗从经脉中取数据作为基础数据
												if  Num == 3 andalso (Key2 == def orelse Key2 == anti_wind orelse Key2 == anti_fire orelse Key2 == anti_water orelse Key2 == anti_thunder orelse Key2 == anti_soil)->
													  Fix = total_fix_by_key(Key2,NewList2),
													  count_batt(Key2,Fix*Value2);
													true ->
														{Key2,NewValue1} =
															case lists:keyfind(Key2, 1, NewList1) of
																false ->
																	{Key2,0};
																{Key2,Value1} ->
																	{Key2,Value1}
															end,
														count_batt(Key2,NewValue1*(1+Value2))
												end;
										   true ->
											   {Key2,NewValue1} =
											   case lists:keyfind(Key2, 1, NewList1) of
												   false ->
													   {Key2,0};
												   {Key2,Value1} ->
													   {Key2,Value1}
											   end,
											   count_batt(Key2,NewValue1*Value2)
										end
							end,
					  BattNum2 = lists:sum([F2(Key2,Value2) || {Key2,Value2} <- List88]),
					  F3 = fun(Key3,Value3) ->
									count_batt(Key3,Value3)
							end,
					   BattNum3 = lists:sum([F3(Key3,Value3) || {Key3,Value3} <- List888]),
					   [Num,(BattNum2+BattNum3)];
				    List8 =/= [] andalso List88 == [] ->
					   F1 = fun(Key,Value) ->
									{Key,NewValue} =
									case lists:keyfind(Key, 1, List888) of
										false ->
											{Key,0};
										{Key,Value1} ->
											{Key,Value1}
									end,
									count_batt(Key,Value+NewValue)
							end,
					   BattNum = lists:sum([F1(Key,Value) || {Key,Value} <- List8]),
					   [Num,BattNum];
				   true ->
					   F1 = fun(Key,Value) ->
									count_batt(Key,Value)
							end,
					   BattNum1 = lists:sum([F1(Key,Value) || {Key,Value} <- List8]),
					   F2 = fun(Key2,Value2) ->
										if Num =/=  1 ->
											   if Num == 7 ->
													  Fix = total_fix_by_key(Key2,NewList8),
													  count_batt(Key2,Fix*Value2);
												  %%防御，全抗从经脉中取数据作为基础数据
												  Num == 3 andalso (Key2 == def orelse Key2 == anti_wind orelse Key2 == anti_fire orelse Key2 == anti_water orelse Key2 == anti_thunder orelse Key2 == anti_soil)->
													  Fix = total_fix_by_key(Key2,List8),
													  count_batt(Key2,Fix*Value2);
												  true ->
													  {Key2,NewValue1} =
														  case lists:keyfind(Key2, 1, NewList2) of
															  false ->
																  {Key2,0};
															  {Key2,Value1} ->
																  {Key2,Value1}
														  end,
													  count_batt(Key2,NewValue1*(1+Value2))
											   end;
										   true ->
											   {Key2,NewValue1} =
											   case lists:keyfind(Key2, 1, NewList2) of
												   false ->
													   {Key2,0};
												   {Key2,Value1} ->
													   {Key2,Value1}
											   end,
											   count_batt(Key2,NewValue1*Value2)
										end
							end,
					  BattNum2 = lists:sum([F2(Key2,Value2) || {Key2,Value2} <- List88]),
					  F3 = fun(Key3,Value3) ->
									count_batt(Key3,Value3)
							end, 
					   BattNum3 = lists:sum([F3(Key3,Value3) || {Key3,Value3} <- List888]),
					   %%如果是人物属性则不加百分比
					   if Num =/= 1 ->
							  [Num,(BattNum1+BattNum2+BattNum3)];
						  true ->
							  [Num,(BattNum1+BattNum3)]
					   end
				end
		end,
	Result1 = [F(Num) || Num <- lists:seq(1, length(NewList8))],
	%%需要单独计算战斗力的根据战斗力类型顺序在后面添加新的类型
	Result1 ++ [[8,Deputy_batt_val]] ++ [[9,Mount_Batt_val]].

%%战斗力根据key的对应比率求值
count_batt(Key,Value) ->
	if Key == max_attack -> 
		   round((Value)*0.4);
	   Key == min_attack -> 
		   round((Value)*0.4);
	   Key == def -> 
		   round(Value*0.04);
	   Key == hp_lim -> 
		   round(Value*0.06);
	   Key == mp_lim -> 
		   round(Value*0.1);
	   Key == hit -> 
		   round(Value*0.4);
	   Key == dodge -> 
		   round(Value*0.6);
	   Key == crit -> 
		   round(Value*0.7);
	   Key == anti_wind -> 
		   round(Value*0.12);
	   Key == anti_fire -> 
		   round(Value*0.12);
	   Key == anti_water -> 
		   round(Value*0.12);
	   Key == anti_thunder -> 
		   round(Value*0.12);
	   Key == anti_soil -> 
		   round(Value*0.12);
	   true ->
		   0
	end.

total_fix_by_key(Key,List) ->
	List1 = lists:flatten(List),
	List2 = [Value ||{Key1,Value}  <- List1,Key1 == Key],
	lists:sum(List2).

%%战斗力值总和
count_value(BattValueList) ->
	if BattValueList == [] ->
		  0;
	   true->
		   F = fun(BattValue,Sum) ->
					if BattValue == [] ->
							   Sum;
						   true ->
							   [_Type,Value] = BattValue,
							   Value+Sum
						end
			   end,
		  lists:foldl(F, 0, BattValueList)			
	end.	   
	
%% 发送角色打坐属性改变通知
send_player_sit_attribute(Status, _Data) ->
	case Status#player.mount > 0 of %%有坐骑
		true ->
			{ok, BinData} = pt_13:write(13015, [Status#player.id, 8]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok;
		false ->
			case Status#player.status of
				0 -> %%角色状态为0时可以打坐，同时更新内存状态为6－－正在打坐,并回复气血和法力 
					case Status#player.hp > 0 of
						true ->
							startSitStatus(Status,_Data);
						false ->
							cancelSitStatus(Status)
					end;
				6 -> %%角色状态为6时停止打坐，同时更新内存状态为0正常
					  cancelSitStatus(Status);
				2 -> %%战斗中取消打坐状态
					  {ok, BinData} = pt_13:write(13015, [Status#player.id,Status#player.status]),
					  lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					  {ok,NewStatus} = cancelSitStatus(Status),
					  NewStatus2 = NewStatus#player{status = 2},
					  {ok,NewStatus2};
				_ -> %%角色状态为其它状态时，不能打坐，直接返回角色状态
					  {ok, BinData} = pt_13:write(13015, [Status#player.id,Status#player.status]),
					  lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					  ok
			end
	end.

%%开始打坐
startSitStatus(Status,_Data) ->
	%%{'ADD_ROLE_HP_MP', 0}第二个参数是城内城外类型，在后面确定需求后再处理
	NewStatus = Status#player{status = 6},
	SitStatusTimer = erlang:send_after(1000, self(), {'ADD_ROLE_HP_MP', 0}),
	put(sit_status_timer, SitStatusTimer),
	NewStatus2 = lib_peach:handle_peach_exp_spir(NewStatus),
	{ok, BinData} = pt_13:write(13015, [Status#player.id,6]),
	%%采用广播通知，附近玩家都能看到
	mod_scene_agent:send_to_area_scene(NewStatus2#player.scene, NewStatus2#player.x, NewStatus2#player.y, BinData),
	{ok,NewStatus2}.

%% 取消打坐
cancelSitStatus(Player) ->
	misc:cancel_timer(sit_status_timer),
%% 	lib_peach:cancel_peach_timer(eat_peach_timer),%%蟠桃的取消定时器
	lib_peach:cancel_auto_sit_timer(Player#player.scene, Player#player.x, Player#player.y, Player#player.mount),%%取消自动打坐+经验的定时器
	Player1 = Player#player{status = 0},
	NewPlayer = lib_marry:cancel_wedding_eat(Player1),
	{ok, BinData} = pt_13:write(13015, [Player#player.id, 0]),
	%%采用广播通知，附近玩家都能看到
	mod_scene_agent:send_to_area_scene(NewPlayer#player.scene, NewPlayer#player.x, NewPlayer#player.y, BinData),
	%%通知改变角色的的状态值
	{ok, NewPlayer}.	

%%启动双修定时器
start_double_rest(Status,[OtherPlayerId,Pid,Num]) ->
	if Num == 0 ->
		    NewStatus1 = Status#player{
							status = 10,
							other = Status#player.other#player_other{
							double_rest_id = OtherPlayerId
				}
		    },
		    lib_player:send_player_attribute(NewStatus1,2),
		    Double_Rest_Timer = erlang:send_after(lib_double_rest:get_add_exp_sprit_culture_time(), self(), {'DOUBLE_REST_ADD_EXP',[OtherPlayerId,Pid,Num+1]}),
			put(double_rest_timer,Double_Rest_Timer),
			mod_player:save_online_info_fields(NewStatus1, [{status,NewStatus1#player.status},{double_rest_id, OtherPlayerId}]),
			{ok, NewStatus1};
	   true ->
		   %%修为倍数
		   MultCulture = Status#player.other#player_other.goods_buff#goods_cur_buff.culture,
		   %%封神争霸属性加成
		   [_,WarMult|_] = Status#player.other#player_other.war_honor_value,
		   {Exp, _Spirit} = lib_peach:count_auto_sit_exp(Status#player.lv),
		   NewExp = tool:ceil(Exp*5/4),
		   NewSpirit = tool:ceil(NewExp/2),
		   NewCulture = tool:ceil((Exp/10)*10/9*(MultCulture+WarMult)),
		   NewStatus = lib_player:add_exp(Status, NewExp, NewSpirit, 17),
		   NewStatus1 = NewStatus#player{
							status = 10,
							other = NewStatus#player.other#player_other{
							double_rest_id = OtherPlayerId
				}
		   },
		   NewStatus2 = add_culture(NewStatus1,NewCulture),
		   lib_player:send_player_attribute(NewStatus2,2),
		   Double_Rest_Timer = erlang:send_after(lib_double_rest:get_add_exp_sprit_culture_time(), self(), {'DOUBLE_REST_ADD_EXP',[OtherPlayerId,Pid,Num+1]}),
		   put(double_rest_timer,Double_Rest_Timer),
		   mod_player:save_online_info_fields(NewStatus2, [{status,NewStatus2#player.status},{double_rest_id, OtherPlayerId},{exp,NewStatus2#player.exp},{spirit,NewStatus2#player.spirit},{culture,NewStatus2#player.culture}]),
		   {ok, NewStatus2}
	end.

%%添加吃桃定时器
double_rest_peach(Status) ->
	misc:cancel_timer(double_rest_peach),
	 %%添加吃桃定时器
	 Type = Status#player.other#player_other.goods_buff#goods_cur_buff.peach_mult,
	 IsPeach = lib_peach:is_local_peach(Status#player.scene, [Status#player.x, Status#player.y]), 
	 if Type =/= 1 andalso IsPeach == ok ->
			 %%添加吃桃定时器
			 Double_rest_peach = erlang:send_after(5000, self(), {'DOUBLE_TEST_PEACH'}),
			 put(double_rest_peach,Double_rest_peach),
			 {Exp, Spirit} = lib_peach:get_peach_exp_spirit(Type, Status#player.lv),
			 NewStatus = lib_player:add_exp(Status, Exp, Spirit, 6),
			 lib_player:send_player_attribute(NewStatus,2);
		 true ->
			NewStatus = Status
	 end,
	{ok, NewStatus}.

%%取消双修定时器Code 0为主动取消双修，1为被动取消双修
cancel_double_rest(Player,_Code) ->
	misc:cancel_timer(double_rest_timer),
	misc:cancel_timer(double_rest_close_timer),
%% 	Type = Player#player.other#player_other.goods_buff#goods_cur_buff.peach_mult,
%% 	IsPeach = lib_peach:is_local_peach(Player#player.scene, [Player#player.x, Player#player.y]), 
%% 	%%如果取消时在指定区别吃桃，或是被对方取消双修改，都变成打坐状态
%% 	if (Type =/= 1 andalso IsPeach == ok ) orelse Code == 1 ->
%% 			%%被动取消设置状态为打坐
%% 			Status = 6,
%% 			{ok,NewPlayer1} = startSitStatus(Player#player{status = 0},[]),
%% 			NewPlayer = NewPlayer1#player{status = Status,other = NewPlayer1#player.other#player_other{double_rest_id=0}};
%% 	true ->
%% 		Status = 0,
%% 		NewPlayer = Player#player{status = Status,other = Player#player.other#player_other{double_rest_id=0}}
%% 		%%取消桃子图标
%% 		%%	{ok, Bin12042} = pt_12:write(12042, [Status#player.id, [{1, 1}]]),
%% 		%%采用广播通知，附近玩家都能看到
%% 		%%mod_scene_agent:send_to_area_scene(Status#player.scene, Status#player.x, Status#player.y, Bin12042)
%% 	end,
	Status = 6,
	{ok,NewPlayer1} = startSitStatus(Player#player{status = 0},[]),
	NewPlayer = NewPlayer1#player{status = Status,other = NewPlayer1#player.other#player_other{double_rest_id=0}},
	{ok, BinData} = pt_13:write(13047, [Player#player.id, Status,Player#player.x,Player#player.y]),
	%%采用广播通知，附近玩家都能看到
	mod_scene_agent:send_to_area_scene(NewPlayer#player.scene, NewPlayer#player.x, NewPlayer#player.y, BinData),
	%%通知改变角色的的状态值
	{ok, NewPlayer}.	


%%处理打坐气血和法力，当气血和法力达到满值时不发送消息
%%添加严格判断，状态不为6时不加血，并且在其它状态时取消打坐
handle_role_hp_mp(Player, SenceType) ->
	case player_status(Player) of
		3 -> 
			Player; 
		6 -> 
			Hp = Player#player.hp,
			HpLim = Player#player.hp_lim,
			Mp = Player#player.mp,
			MpLim = Player#player.mp_lim,
			%% 更新人物属性
			case Hp == HpLim andalso Mp == MpLim of
				true -> 
					Player;
				false ->
					%% 灵兽技能加成效果
                    [_,_,_,_,_,_,_, [R_hp,R_hpFix], [R_mp,R_mpFix]] = Player#player.other#player_other.pet_skill_mult_attribute,
                    Rate = 
                        case SenceType of
                            0 -> 
                                0.02 ;
                            1 -> 
                                0.005
                        end,
                    R_hp_rate = (1 + R_hp),
                    R_mp_rate = (1 + R_mp),
                    NewHp = 
                        case Rate * HpLim + Hp + R_hpFix > HpLim of
                            true -> HpLim;
                            false ->round((Rate * R_hp_rate) * HpLim + Hp + R_hpFix)
                        end,
                    NewMp = 
                        case Rate * MpLim + Mp + R_mpFix > MpLim of
                            true -> MpLim;
                            false -> round((Rate * R_mp_rate) * MpLim + Mp + R_mpFix)
                        end,
					{ok, BinData} = pt_13:write(13016, [Player#player.id, NewHp, NewMp]),
					mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData),
					SitStatusTimer = erlang:send_after(1000, self(), {'ADD_ROLE_HP_MP', 0}),
					put(sit_status_timer, SitStatusTimer),
					NewPlayer = Player#player{
						hp = NewHp, 
						mp = NewMp
					},
					%% 更新队伍成员的血蓝数值信息
					lib_team:update_team_player_info(NewPlayer),
					NewPlayer
			end;
		%% 其它状态不加血和魔
		_ ->
			%% 其它状态时取消打坐
			{ok, BinData} = pt_13:write(13015, [Player#player.id,0]),
			mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData),
			Player 
	end.

%% 玩家死亡处理
%% Player 被击杀者数据
%% AttPid 攻击杀死你的玩家进程
player_die(Player, AerPid, AerId, NickName, Career, Realm) ->
	{ok, DieBinData} = pt_12:write(12009, [Player#player.id, 0, Player#player.hp_lim]),
   	lib_send:send_to_sid(Player#player.other#player_other.pid_send, DieBinData),
	
    NewPlayer = 
		case is_pid(AerPid) of
	        true ->            
	            %% 判断是否是在战场死亡
	            case lib_arena:is_arena_scene(Player#player.scene) of
	                true ->
						lib_arena:arena_die(Player, AerPid, AerId, NickName),
						Player;
					false ->
						case Player#player.scene of
							%%空岛
							?SKY_RUSH_SCENE_ID ->
								CarryMark = Player#player.carry_mark,
								if 
									CarryMark  >= 8 andalso  CarryMark =< 15->
										Param2 = [Player#player.id, Player#player.nickname, Player#player.career, Player#player.sex],
									   lib_skyrush:drop_fns_for_die(Player#player.other#player_other.pid_scene, Player#player.id, Param2, 
																	CarryMark, Player#player.x, Player#player.y, AerPid, AerId);
									CarryMark  >= 16 andalso  CarryMark =< 17->
										lib_skyrush:sky_die_reset(Player#player.other#player_other.pid_scene, Player#player.id, AerId, CarryMark);
									true ->%%更新杀敌数和死亡数
										lib_skyrush:update_skyrush_killdie(Player#player.other#player_other.pid_scene, Player#player.id, AerId)
								end,
								Player;
							
							%% 攻城战
							?CASTLE_RUSH_SCENE_ID ->
								lib_castle_rush:castle_rush_die(Player, AerId),
								Player;
							
							%% 自由PK竞技场
							119 ->
								Player;
							?WARFARE_SCENE_ID ->%%神魔乱斗场景里死亡
								%%通知被杀死了
								lib_warfare:notice_be_kill(Player, NickName),
								case Player#player.carry_mark of
									27 ->%%通知怪物控制器处理冥王之灵的交换逻辑
	%% 									?DEBUG("notice_winner_pluto, die:~p, kill:~p", [Player#player.id, AerId]),
										lib_warfare:notice_winner_pluto(Player, AerPid, AerId, NickName);
									_ ->
										skip
								end,
								red_name_punish(Player, NickName);
							SceneId ->
								%%判断是否跨服战场死亡
								case lib_war:is_fight_scene(SceneId) of
									false ->
										case lib_war2:is_fight_scene(SceneId) of
											false->
												%% 是否在竞技场
												case lib_coliseum:is_coliseum_scene(SceneId) of
													false ->
														%% 普通场景死亡
														spawn(fun() -> normal_die(Player, AerPid, AerId, Realm, NickName, Career) end),
														%% 红名惩罚
														RedNamePlayer = red_name_punish(Player, NickName),
														%% 判断是否是挂机且开了自动复活
														case RedNamePlayer#player.status of
															5 ->
																lib_hook:is_auto_revive(RedNamePlayer);
															_ ->
																%% 退出战斗状态
																lib_battle:exit_battle_status(RedNamePlayer, 3)	
														end;
													true ->
														ColiseumScenePid = mod_scene:get_scene_real_pid(SceneId),
														gen_server:cast(ColiseumScenePid, {'COLISEUM_DIE', Player#player.id}),
														Player
												end;
											true->
												%%跨服单人竞技场景死亡
												if Player#player.carry_mark /= 29->
													gen_server:cast(Player#player.other#player_other.pid_dungeon, {'WAR2_FIGHT_RES',[AerId,NickName,Player#player.id,Player#player.nickname]});
												   true->skip
												end,
												%% 设置玩家死亡时间
												DieTimes =Player#player.other#player_other.war_die_times + 1,
												Player#player{
								             		other = Player#player.other#player_other{
								             			die_time = util:unixtime(),
														war_die_times = DieTimes					  
								              		}						
											    }
										end;
									true->
										%%跨服战场死亡
										gen_server:cast(Player#player.other#player_other.pid_dungeon, {'WAR_DIE',AerId,AerPid, Player#player.id,Player#player.other#player_other.pid,Player#player.carry_mark}),
										%% 设置玩家死亡时间
										DieTimes =Player#player.other#player_other.war_die_times + 1,
										Player#player{
						             		other = Player#player.other#player_other{
						             			die_time = util:unixtime(),
												war_die_times = DieTimes					  
						              		}						
									    }
								end
						end
				end;
			false ->%%怪物击败人
	      		case Player#player.scene of
					%% 空岛
					?SKY_RUSH_SCENE_ID ->
					   	CarryMark = Player#player.carry_mark,
					   	if 
						   CarryMark  >= 8 andalso  CarryMark =< 15->
							   Param2 = [Player#player.id, Player#player.nickname, Player#player.career, Player#player.sex],
							   lib_skyrush:drop_fns_for_die(Player#player.other#player_other.pid_scene, Player#player.id, Param2, 
															CarryMark, Player#player.x, Player#player.y, AerPid, AerId);
						   CarryMark  >= 16 andalso  CarryMark =< 17->
							   lib_skyrush:sky_die_reset(Player#player.other#player_other.pid_scene, Player#player.id, AerId, CarryMark);
						   true ->%%更新杀敌数和死亡数
							   lib_skyrush:update_skyrush_killdie(Player#player.other#player_other.pid_scene, Player#player.id, AerId)
					   	end,
						Player;
					%%神魔乱斗场景里死亡
					?WARFARE_SCENE_ID ->
						lib_warfare:notice_be_kill(Player, NickName),
						Player;
					_ ->
						case Player#player.status of
							5 ->
								lib_hook:is_auto_revive(Player);
							_ ->
								%% 退出战斗状态
								lib_battle:exit_battle_status(Player, 3)	
						end
			   	end
		end,
	
	if 
		NewPlayer#player.carry_mark >= 8 andalso NewPlayer#player.carry_mark =< 17 ->%% 空岛战场
			if
				NewPlayer#player.carry_mark =< 11 ->
					Color = NewPlayer#player.carry_mark - 7,
					ParamTips = [NewPlayer#player.other#player_other.pid_send, Color],
					lib_skyrush:send_skyrush_tips(6, ParamTips);
				NewPlayer#player.carry_mark =< 15 ->
					Color = NewPlayer#player.carry_mark - 11,
					ParamTips = [NewPlayer#player.other#player_other.pid_send, Color],
					lib_skyrush:send_skyrush_tips(7, ParamTips);
				true ->
					skip
			end,
			NewPlayer1 = NewPlayer#player{carry_mark = 0},
			count_player_attribute(NewPlayer1);
		NewPlayer#player.carry_mark =:= 27 ->%%神魔乱斗死了，冥王之灵丢掉
			%% 通知客户端更新玩家属性
			{ok, BinData12041} = pt_12:write(12041, [NewPlayer#player.id, 0]),
			mod_scene_agent:send_to_area_scene(NewPlayer#player.scene, NewPlayer#player.x, NewPlayer#player.y, BinData12041),
			lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData12041),			
			NewPlayer1 = NewPlayer#player{carry_mark = 0},
			count_player_attribute(NewPlayer1);
		NewPlayer#player.carry_mark > 0 andalso NewPlayer#player.carry_mark < 8 orelse (NewPlayer#player.carry_mark >=20 andalso NewPlayer#player.carry_mark<26)->
			gen_server:cast(Player#player.other#player_other.pid_task,{'carry_lose',NewPlayer,AerPid}),
			if 
				NewPlayer#player.carry_mark < 4 orelse (NewPlayer#player.carry_mark >=20 andalso NewPlayer#player.carry_mark<26)->
	   				NewPlayer1 = NewPlayer#player{carry_mark = 0},
					count_player_attribute(NewPlayer1);
			   	true->
				   NewPlayer
			end;
		true -> 
			NewPlayer
    end.

%% 普通场景死亡
normal_die(Player, AerPid, AerId, Realm, NickName, Career) ->
	%% 击杀异族任务（战场，空战不能完成）
  	lib_task:kill_enemy_task(AerPid, Realm, Player#player.realm),
  	Close = 
	  	case lib_relationship:is_exists(Player#player.id, AerId, 1) of
		  	{RecordId1, true} ->
			  	case ets:lookup(?ETS_RELA,{RecordId1,Player#player.id,1}) of
				  	[] -> 
					  	0;
				  	[Info] -> Info#ets_rela.close
			  	end;
		  	{ok, false} -> 0
	  	end,
  	lib_relationship:add_enemy(Player, AerId, Close),%% 添加仇人
  	case Player#player.carry_mark =:= 0 andalso Player#player.nickname /= NickName of
	  	true ->
		  	MsgData = [
				get_country(Player#player.realm),
			 	Player#player.id, 
			 	Player#player.nickname,
			 	Player#player.career,
			 	Player#player.sex, 
			 	Player#player.nickname,
			 	get_country(Realm),
			 	AerId,
			 	NickName,
			 	Career,
			 	1,
			 	NickName
			],
		  	Msg = io_lib:format("<font color='#FF0000;'>[~s]</font> [<a href='event:1,~p,~s,~p,~p'><font color='#FEDB4F'>~s</font></a>] 被 <font color='#FF0000;'>[~s]</font> [<a href='event:1,~p,~s,~p,~p'><font color='#FEDB4F'>~s</font></a>] 干掉！", MsgData),
		  	lib_chat:broadcast_sys_msg(7, Msg);
	  	false ->
		  	skip
  	end.


%% 红名惩罚
red_name_punish(Player,NickName) ->
	Evil = Player#player.evil,
	[ExpParam, SpiritParam] =
		if			
			Evil >= 300 andalso Evil < 450 ->
				[0.02, 0.02];			
			Evil >= 450 andalso Evil < 600 ->
				[0.05, 0.05];
			Evil >= 600 ->
				[0.08, 0.08];
			true ->
				[0, 0]
		end,
	case ExpParam /= 0 andalso SpiritParam /= 0 of			
		true ->
			PunishExp = util:ceil(Player#player.exp * ExpParam),
			Exp = 
				case Player#player.exp > PunishExp of
					true ->
						Player#player.exp - PunishExp;
					false ->
						0
				end,
			{ok, BinData} = pt_13:write(13002, [Exp, Player#player.spirit]),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
			%%红名被杀，发送惩罚邮件
			if PunishExp > 0 ->
				   Content = io_lib:format("你处于红名状态，被【~s】干掉，损失~p经验！", [NickName,PunishExp]),
				   Title = "杀戮提示",
				   NameList = [tool:to_list(Player#player.nickname)],
				   mod_mail:send_sys_mail(NameList, Title, Content, 0, 0, 0, 0, 0, 0);
			   true ->
				   skip
			end,
			Player#player{
				exp = Exp		  
			};
		false ->
			Player
	end.

%% 获取技能Buff属性
get_skill_buff_attr(Buff) ->
	Now = util:unixtime(),
	get_skill_buff_attr_loop(Buff, Now, [0, 0, 0, 0, 0, 0, 0, 0]).
get_skill_buff_attr_loop([], _Now, SkillBuffAttr) ->
	SkillBuffAttr;
get_skill_buff_attr_loop([{Key, Val, EndTime, _SkillId, _Slv} | B], Now, [HpLim, Agile, Physique, Def, Anti, Hit, CastlrRushAtt, CastlrRushAnti]) ->
	NewSkillBuffAttr = 
        case EndTime > Now of
            true ->
                case Key of
                    hp_lim ->
                        [Val, Agile, Physique, Def, Anti, Hit, CastlrRushAtt, CastlrRushAnti];
                    agile ->
                        [HpLim, Val, Physique, Def, Anti, Hit, CastlrRushAtt, CastlrRushAnti];
                    physique ->
                        [HpLim, Agile, Val, Def, Anti, Hit, CastlrRushAtt, CastlrRushAnti];
                    def ->
                        [HpLim, Agile, Physique, Val, Anti, Hit, CastlrRushAtt, CastlrRushAnti];
					last_anti ->
						AntiVal = 
							case Val > 1 of
								true ->
									Val - 1;
								false ->
									Val
							end,
						[HpLim, Agile, Physique, Def, AntiVal, Hit, CastlrRushAtt, CastlrRushAnti];
					hit_add ->
						[HpLim, Agile, Physique, Def, Anti, Val, CastlrRushAtt, CastlrRushAnti];
					castle_rush_att ->
						[HpLim, Agile, Physique, Def, Anti, Hit, Val, CastlrRushAnti];
					castle_rush_anti ->
						[HpLim, Agile, Physique, Def, Anti, Hit, CastlrRushAtt, Val];
                    _ ->
                        [HpLim, Agile, Physique, Def, Anti, Hit, CastlrRushAtt, CastlrRushAnti]
                end;
            false ->
                [HpLim, Agile, Physique, Def, Anti, Hit, CastlrRushAtt, CastlrRushAnti]	
        end,
	get_skill_buff_attr_loop(B, Now, NewSkillBuffAttr).

%% 登录前获取玩家的BUFF信息
%% Player 玩家信息
get_skill_buff_effect(PlayerId, Pid, Now) ->
	%% BUFF定时器
%% 	put(hp_lim_buff_timer, undefined),
%% 	put(agile_buff_timer, undefined),
%% 	put(physique_buff_timer, undefined),
%% 	put(def_buff_timer, undefined),
%% 	put(last_anti_buff_timer, undefined),
%% 	put(hit_add_buff_timer, undefined),
	Fun = fun(Key) ->
		TimerKey = tool:to_atom(lists:concat([Key, "_buff_timer"])),
		put(TimerKey, undefined)
	end,
	[Fun(K) || K <- ?SKILL_BUFF_TYPE_LIST],
    case db_agent:get_player_buff_info(PlayerId) of
        [] ->
            [];
        BuffData ->
			get_skill_buff_effect_loop(BuffData, Pid, Now, [])
    end.
get_skill_buff_effect_loop([], _Pid, _Now, Buff) ->
	Buff;
get_skill_buff_effect_loop([[_Id, PlayerId, _SkillId, _Type, Effect] | B], Pid, Now, Buff) ->	
	{Key, Val, EndTime, SkillId, Slv} = util:string_to_term(tool:to_list(Effect)),
	NewBuff = 
        case EndTime > Now + 30 of
            true ->	    		
                LeftTime = (EndTime - Now) * 1000,                
                BuffTimer = erlang:send_after(LeftTime, Pid, {'UPDATE_SKILL_BUFF', Key}),
				set_skill_buff_timer(BuffTimer, Key),
                [{Key, Val, EndTime, SkillId, Slv} | Buff];			
            
            false ->
                spawn(fun()-> db_agent:delete_skill_buff(PlayerId, SkillId, Key) end),
                Buff			
        end,
	get_skill_buff_effect_loop(B, Pid, Now, NewBuff).
set_skill_buff_timer(BuffTimer, Key) ->
    case lists:member(Key, ?SKILL_BUFF_TYPE_LIST) of
        true ->            
			TimerKey = tool:to_atom(lists:concat([Key, "_buff_timer"])),
			case get(TimerKey) of
                undefined ->
             		skip;
              	Timer ->
                    catch erlang:cancel_timer(Timer)
            end,
            put(TimerKey, BuffTimer);
        false ->
            skip
    end.

%% 停掉持续BUFF定时器
stop_skill_buff_timer() ->
	F = fun(Key) ->
		TimerKey = tool:to_atom(lists:concat([Key, "_buff_timer"])),
		case get(TimerKey) of
      		undefined ->
        		skip;
      		Timer ->
             	catch erlang:cancel_timer(Timer)
      	end	
	end,
	[F(K) || K <- ?SKILL_BUFF_TYPE_LIST].

%% 添加持续技能BUFF
cast_last_skill_buff_loop([], Player, _SkillId, _Slv, _Now, Buff) -> 
	{Buff, Player};
cast_last_skill_buff_loop([{LastTime, Key, Val} | SkillEffect], Player, SkillId, Slv, Now, Buff) ->
    {NewVal, NewPlayer} = 
        case Key of
            shield ->
                {P1, P2} = Val,
				%% 朱雀盾效果显示
				ShieldPlayer = Player#player{
			  		other = Player#player.other#player_other{
			      		is_spring = 10									  
			   		}						
			   	},
                {Player#player.lv * P1 + Player#player.wit * P2, ShieldPlayer};
            _ ->
                {Val, Player}
        end,    
    EndTime = Now + LastTime,
    BuffInfo = {Key, NewVal, EndTime, SkillId, Slv},
    %% 更新数据库,小于2分钟的BUFF不写进数据库
    case LastTime > 120 of
        true ->
			spawn(fun()-> 
				db_agent:delete_skill_buff(Player#player.id, SkillId, Key),
            	Data = util:term_to_string(BuffInfo),
            	db_agent:insert_skill_buff([Player#player.id, SkillId, Key, Data])	  
			end);
        false ->
            skip
    end,	
    NewBuff = 
        case lists:keyfind(Key, 1, Buff) of
            false ->
                [BuffInfo | Buff];
            _BuffData ->
                lists:keyreplace(Key, 1, Buff, BuffInfo)
        end,
    BuffTimer = erlang:send_after(LastTime * 1000, self(), {'UPDATE_SKILL_BUFF', Key}),
	set_skill_buff_timer(BuffTimer, Key),	
	cast_last_skill_buff_loop(SkillEffect, NewPlayer, SkillId, Slv, Now, NewBuff).

%% 更新客户端玩家的BUFF信息
refresh_player_buff(PidSend, Buff, Now) ->
	NewBuff = [{K, V, T, S, L} || {K, V, T, S, L} <- Buff, T > Now],
	{ok, BinData} = pt_13:write(13013, [NewBuff, Now]),
	lib_send:send_to_sid(PidSend, BinData).

%% 更新祝福技能BUFF信息
refresh_player_goods_buff(Player, SkillKey, SkillVal, SkillTime, SkillId, SkillLv, Now) ->
	SkillInfo = {SkillKey, SkillVal, SkillTime, SkillId, SkillLv},
    Buff = Player#player.other#player_other.battle_status,
    NewBuff = 
        case lists:keyfind(SkillKey, 1, Buff) of
            false ->
                [SkillInfo | Buff];
            _ -> 
                lists:keyreplace(SkillKey, 1, Buff, SkillInfo)
        end,
    NewGoodsBuffCd = 
		 case lists:keyfind(SkillId, 1, Player#player.other#player_other.goods_buf_cd) of
            false ->
                [{SkillId, Now} | Player#player.other#player_other.goods_buf_cd];
            _ -> 
                lists:keyreplace(SkillId, 1, Player#player.other#player_other.goods_buf_cd, {SkillId, Now})
        end,
    NewPlayer = Player#player{
        other = Player#player.other#player_other{
            battle_status = NewBuff,
            goods_buf_cd = NewGoodsBuffCd								  
        }						
    },
   	refresh_player_buff(Player#player.other#player_other.pid_send, NewBuff, Now),
    mod_player:save_online_info_fields(NewPlayer, [{battle_status, NewBuff}, {goods_buf_cd, NewGoodsBuffCd}]),
    NewPlayer.

%% 获取阵营名
%% Realm 阵营ID
get_country(Realm) ->
	case Realm of
		1 ->
			"女娲";
		2 ->
			"神农";
		3 ->			
			"伏羲";
		_ ->
			"新手"	
	end.

%% 返回玩家状态
player_status(Player) ->
	if
		Player#player.hp > 0 ->
			Player#player.status;
		true ->
			3				
	end.

%% 返回玩家状态判断， 如果 HPorNormal是 normal， 则Status为当前状态, 否则HPorNormal是为当前血量
%% 如果返回true，则允许此类状态改变，否则返回的错误码为当前状态+20
%% 玩家状态（0正常、1禁止、2战斗中、3死亡、4蓝名、5挂机、6打坐、7凝神修炼、8采矿、9答题）
%% 暂时不用
%% player_status_switch(Status, NewStatus, HPorNormal) ->
%% 	OldStatus =
%% 		case HPorNormal of
%% 			normal ->
%% 				Status;
%% 			Hp ->
%% 				if
%% 					Hp > 0 ->
%% 						Status;
%% 					true ->
%% 						3
%% 				end
%% 		end,
%% 	case [OldStatus, NewStatus] of
%% 		[0, _] -> true;
%% 		[_, 0] -> true;
%% 		[2, 2] -> true;
%% 		[4, 2] -> true;
%% 		[5, 2] -> true;
%% 		[6, 2] -> true;
%% 		[8, 8] -> true;
%% 		_ -> OldStatus + 8
%% 	end.

%% 封神台/诛仙台加经验灵力荣誉
add_fst_esh(Status, Exp, Spr, Hor,ZxtHonor) ->
	NewStatus = add_exp(Status, Exp, Spr, 6),
	NewZxtHonor = NewStatus#player.other#player_other.zxt_honor + ZxtHonor,
	%% 增加诛仙台荣誉
	if 
		ZxtHonor > 0 ->
			spawn(fun()-> lib_scene_fst:update_zxt_honor(NewStatus#player.id,NewZxtHonor) end);
	   	true ->
			skip
	end,
	NewStatus#player{
		honor = NewStatus#player.honor + Hor, 
		other = NewStatus#player.other#player_other{
			zxt_honor = NewZxtHonor,
			fst_exp_ttl = Status#player.other#player_other.fst_exp_ttl + Exp, 
			fst_spr_ttl = Status#player.other#player_other.fst_spr_ttl + Spr, 
			fst_hor_ttl = Status#player.other#player_other.fst_hor_ttl + Hor+ZxtHonor
		}
	}.


%% 检查是否有未发送的封神台通知
check_fst_td_log(Uid, SceneId, Pid)->
	NewSceneId = SceneId rem 10000,
	IsFst = lib_scene:is_fst_scene(SceneId),
	IsZxt = lib_scene:is_zxt_scene(SceneId),
	if
		NewSceneId =:= 998 orelse NewSceneId =:= 999 ->
		  	case db_agent:get_log_td_unread(Uid) of
				[] -> ok;
				[Att_num, Hor_td, MapType, Endtime] ->
					case MapType of
						998 ->
							Exp = 0,
							Spr = 0,
							Content = io_lib:format("镇妖台守护结束，击退~s波，共计获得~s镇妖功勋。",[tool:to_list(Att_num),tool:to_list(Hor_td)]);
						_ ->
							Exp = lib_td:get_exp(Hor_td, MapType),
							Spr = round(Exp/2),
							Content = io_lib:format("镇妖台守护结束，击退~s波，共计获得~s经验，~s灵力和~s镇妖功勋。", [tool:to_list(Att_num),tool:to_list(Exp),tool:to_list(Spr),tool:to_list(Hor_td)])
					end,
					db_agent:insert_mail(1, Endtime, "系统", Uid, "镇妖台守护记录", Content, 0, 0, 0, 0, 0),
					erlang:send_after(5 * 1000, Pid, {'READ_TD', Att_num, Hor_td, MapType, Exp, Spr})
  			end;
		IsFst->
			case db_agent:get_log_fst(Uid) of
				[] -> ok;
				[[Hor_log, Exp_log, Spr_log, Loc, Endtime]] ->
					if Loc == 30 ->
						   GoodsType = 28814,
						   Num = 1;
					   true ->
						   GoodsType = 0,
						   Num = 0
					end,
					Content = io_lib:format("封神台闯关结束，闯至~s层，共计获得~s经验，~s灵力和~s荣誉;通关封神台30层，可获得1个封神通关礼包。", [tool:to_list(Loc),tool:to_list(Exp_log),tool:to_list(Spr_log),tool:to_list(Hor_log)]),
					db_agent:insert_mail(1, Endtime, "系统", Uid, "封神台闯关记录", Content, 0, GoodsType, Num, 0, 0),
					spawn(fun()->db_agent:add_fst_log_bak(Uid, Loc, 1,Endtime)end),
					db_agent:delete_log_fst(Uid)
  			end;
		IsZxt->%%诛仙台和风神台共用日志表
			case db_agent:get_log_fst(Uid) of
				[] -> ok;
				[[Hor_log, Exp_log, Spr_log, Loc, Endtime]] ->
					if Loc == 20 ->
						   GoodsType = 28815,
						   Num = 1;
					   true ->
						   GoodsType = 0,
						   Num = 0
					end,
					Content = io_lib:format("诛仙台闯关结束，闯至~s层，共计获得~s经验，~s灵力和~s荣誉。通关诛仙台20层，可获得1个诛仙通关礼包。", [tool:to_list(Loc),tool:to_list(Exp_log),tool:to_list(Spr_log),tool:to_list(Hor_log)]),
					db_agent:insert_mail(1, Endtime, "系统", Uid, "诛仙台闯关记录", Content, 0, GoodsType, Num, 0, 0),
					spawn(fun()->db_agent:add_fst_log_bak(Uid, Loc,2, Endtime)end),
					db_agent:delete_log_fst(Uid)
  			end;
		true->skip
	end.

%% 氏族运镖提示
guild_carry_tip(PlayerState, Player) ->
	case Player#player.carry_mark of
		3 ->
			Now = util:unixtime(),
			case Now - PlayerState#player_state.guild_carry_bc > 30 of
				true ->
					Mult = Player#player.hp / Player#player.hp_lim,
					if 
						Mult =< 0.2 ->
				   			lib_guild:send_guild(1, Player#player.id, Player#player.guild_id, guild_carry_help, [3]);
			   			Mult =< 0.5 ->
				   			lib_guild:send_guild(1, Player#player.id, Player#player.guild_id, guild_carry_help, [2]);
			   			true->
				   			lib_guild:send_guild(1, Player#player.id, Player#player.guild_id, guild_carry_help, [1])
					end,
					PlayerState#player_state{
						guild_carry_bc = Now					 
					};
				false ->
					PlayerState
			end;
		_ ->
			PlayerState
	end.

%% 同步更新ETS中的角色数据
save_online(Player) ->
	%% 更新本地ets里的用户信息
    ets:insert(?ETS_ONLINE, Player),
	%% 更新对应场景中的用户信息
    mod_scene:update_player(Player).

%%获取玩家上次的buff更新时间，并且进行更新
get_other_player_data(PlayerState, Player, Now) ->
	case db_agent:get_other_player_data(Player#player.id) of
		[] ->
			PTitles = util:term_to_string([]),
			Quickbar = [{6,3,3},{5,3,2},{4,3,1}],
			NewQuickbar = util:term_to_string(Quickbar),
			spawn(fun()-> db_agent:insert_player_other_info(Now, PTitles, NewQuickbar, Player#player.id) end),
			NewPlayerState = PlayerState#player_state{
				quickbar = Quickbar									  
			},
			{0, [], 0, NewPlayerState};
%% 		[UpTime, PTitlesStr, OPTitle, ZxtHonor, Quickbar] ->
		EtsPlayerOther ->
			NewEtsPlayerOther = list_to_tuple([ets_player_other | EtsPlayerOther]),
			#ets_player_other{
				up_t = UpTime, 
				ptitles = PTitlesStr, 
				ptitle = OPTitle, 
				zxt_honor = ZxtHonor, 
				quickbar = Quickbar,
				coliseum_time = ColiseumTime,
				coliseum_cold_time = ColiseumColdTime,							
				coliseum_surplus_time = ColiseumSurplusTime,						
				coliseum_extra_time = ColiseumExtraTime,						
				is_avatar = IsAvatar,
				coliseum_rank = ColiseumRank	
			} = NewEtsPlayerOther,
			NewQuickbar = 
				case Quickbar =/= [] of
					true ->
						case util:bitstring_to_term(Quickbar) of 
							undefined -> 
								[{6,3,3},{5,3,2},{4,3,1}];
							Qb -> 
								Qb 
						end;
					false ->
						[{6,3,3},{5,3,2},{4,3,1}]		
				end,
			
			OPTitles = util:string_to_term(tool:to_list(PTitlesStr)),
			if 
				is_list(OPTitles) ->
					LOPTitles = OPTitles;
				true ->
					LOPTitles = []
			end,
			OPTitleE = 
				if
					is_integer(OPTitle) ->
						case OPTitle =:= 0 of
							true ->
								[];
							false ->
								[OPTitle]
						end;
					true ->
						OPTitle1 = util:string_to_term(tool:to_list(OPTitle)),
						if
							is_list(OPTitle1) ->
								OPTitle1;
							true ->
								[]
						end
				end,
			NPTitle = lib_title:compare_title(LOPTitles, OPTitleE, Player#player.id),
			%%把出错的0称号 去掉
			NPTitleDZero = lists:delete(0, NPTitle),
%% 			NPTitleStr = util:term_to_string(NPTitleDZero),
%% 			NPTitlesStr = util:term_to_string(LOPTitles),
%% 			ValueLists = [{up_t, Now}, {ptitles, NPTitlesStr}, {ptitle, NPTitleStr}],
%% 			WhereLists = [{pid, PlayerId}],
%% 			spawn(fun()-> db_agent:update_player_other(player_other, ValueLists, WhereLists) end),
			NewPlayerState = PlayerState#player_state{
				quickbar = NewQuickbar,
				coliseum_time = ColiseumTime,
				coliseum_cold_time = ColiseumColdTime,							
				coliseum_surplus_time = ColiseumSurplusTime,						
				coliseum_extra_time = ColiseumExtraTime,						
				is_avatar = IsAvatar,
				coliseum_rank = ColiseumRank									  
			},
			%% 检测竞技场状态数据
			RetPlayerState = lib_coliseum:check_coliseum_state(NewPlayerState, Player, Now),
			{UpTime, NPTitleDZero, ZxtHonor, RetPlayerState}
	end.

%% 初始玩家参与度信息
init_join_data(PlayerId, Now) ->
	case db_agent:get_join_data(PlayerId, "jtime") of
		[] ->
			db_agent:init_today_join_data(PlayerId, Now);
		[Jtime] ->
			case util:is_same_date(Now, Jtime) of
				true ->
					skip;
				false ->
					db_agent:init_today_join_data(PlayerId, Now)
			end
	end.

%%角色改名
change_playername(PlayerStatus,NickName) ->
	PlayerId = PlayerStatus#player.id,
	Guild_id = PlayerStatus#player.guild_id,
	NewPlayerStatus = PlayerStatus#player{nickname = NickName},
	lib_player:send_player_attribute(NewPlayerStatus, 3),
	GoodsPid = PlayerStatus#player.other#player_other.pid_goods,
	 case gen_server:call(GoodsPid, {'goods_find', PlayerStatus#player.id, 28040}) of
		  false -> %%更名符不存在
			  {0};
		   GoodsInfo ->
				case gen_server:call(GoodsPid, {'delete_more', GoodsInfo#goods.goods_id, 1}) of
					1 ->%%扣除物品成功
						%%更新战场角色名
						spawn(fun()-> mod_arena_supervisor:change_player_name(PlayerId,NickName) end),
						%%更新封神台角色名
						spawn(fun()-> db_agent:change_fst_god_name(PlayerId,NickName) end),
						%%更新镇妖台单人角色名
						spawn(fun()-> db_agent:change_td_single_name(PlayerId,NickName) end),
						%%更新帮派角色名
						spawn(fun()-> mod_guild:change_player_name(PlayerId,Guild_id,NickName) end),
						%%更新师徒信息角色名
						spawn(fun()-> mod_master_apprentice:change_player_name(PlayerId,NickName) end),
						%%更新交易角色名
						spawn(fun()-> mod_sale:change_player_name(PlayerId,NickName) end),
						%%更新诛仙台角色名
						spawn(fun()-> db_agent:change_zxt_god_name(PlayerId,NickName) end),
						
						spawn(fun()-> db_agent:change_feedback_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_arena_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_backout_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_box_open_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_compose_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_hole_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_icompose_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_idecompose_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_identify_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_inlay_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_kick_off_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_manor_steal_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_merge_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_pay_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_practise_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_quality_out_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_quality_up_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_refine_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_sale_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_shop_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_smelt_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_stren_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_suitmerge_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_throw_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_trade_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_use_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_wash_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_log_wash_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_mon_drop_analytics_name(PlayerId,NickName) end),
						spawn(fun()-> db_agent:change_player_name(PlayerId,NickName) end),
						
						{1,NewPlayerStatus};
					_ ->%%扣除物品失败
						{0}
				end
	end.

%% 是否双倍经验活动时间
is_exp_activity() ->
	case ets:tab2list(?ETS_EXP_ACTIVITY) of
		[] ->
			false;
		[ExpActivity | _] ->
			Now = util:unixtime(),
			ExpActivity#ets_exp_activity.et > Now andalso ExpActivity#ets_exp_activity.st =< Now
	end.
%% 是否在双倍经验活动(登陆检查)
exp_activity_login_check(PidSend) ->
	case ets:tab2list(?ETS_EXP_ACTIVITY) of
		[] ->
			false;
		[ExpActivity | _] ->
			Now = util:unixtime(),
			if
				ExpActivity#ets_exp_activity.et > Now andalso ExpActivity#ets_exp_activity.st =< Now ->
					DistTime = (ExpActivity#ets_exp_activity.et - Now) * 1000,
					{ok, BinData} = pt_13:write(13061, [ExpActivity#ets_exp_activity.st, ExpActivity#ets_exp_activity.et, DistTime]),
					lib_send:send_to_sid(PidSend, BinData);
				true ->
					skip
			end
	end.

%% 查询其他玩家信息
get_other_player_info(Player, Id, PidSend) ->
	{_IdA,_IdB,Close} = 
	case lib_relationship:find_is_exists(Player#player.id,Id,1) of
				{ok, false} -> {0,0,0};
				{RelaId, true} ->
					
					          case ets:lookup(?ETS_RELA,RelaId) of
								  [] -> {0,0,0};
								  [R] -> {Player#player.id,Id,R#ets_rela.close}
							  end
	end,
	PlayerInfo =[Player#player.id,
				 Player#player.hp,
				 Player#player.hp_lim,
				 Player#player.mp,
				 Player#player.mp_lim,
				 Player#player.sex,
				 Player#player.lv,
				 Player#player.career,
				 Player#player.nickname,
				 Player#player.max_attack,
				 Player#player.min_attack,
				 Player#player.def,
				 Player#player.forza,
				 Player#player.physique,
				 Player#player.agile,
				 Player#player.wit,
				 Player#player.hit,
				 Player#player.dodge,
				 Player#player.crit,
				 Player#player.guild_id,
				 Player#player.guild_name,
				 Player#player.guild_position,
				 Player#player.realm,
				 Player#player.spirit,
				 Player#player.speed,
				 Player#player.other#player_other.equip_current,
				 Player#player.mount,
				 Player#player.pk_mode,
				 Player#player.title,
				 Player#player.couple_name,
				 Player#player.position,
				 Player#player.evil,
				 Player#player.realm_honor,
				 Player#player.culture,
				 Player#player.state,
				 Player#player.anti_wind,
				 Player#player.anti_fire,
				 Player#player.anti_water,
				 Player#player.anti_thunder,
				 Player#player.anti_soil,
				 Player#player.vip,
				 Player#player.other#player_other.titles,
				 Player#player.other#player_other.ach_pearl,
				 Player#player.other#player_other.batt_value,
				 Close,
				 Player#player.other#player_other.deputy_prof_lv,
				 Player#player.other#player_other.war_honor
				 ] ,
	
	{ok, BinData} = pt_13:write(13004, PlayerInfo),
    lib_send:send_to_sid(PidSend, BinData).

%% 减罪恶值
deduct_evil(Player) ->
	if
		Player#player.evil > 0 ->
			Evil = 
				case Player#player.evil > 20 of
					true ->
						Player#player.evil - 20;
					false ->
						0
				end,
  			{ok, BinData} = pt_12:write(12021, [Player#player.id, Evil]), 
   			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
   			NewPlayer = Player#player{
  				evil = Evil
   			},
			mod_player:save_online_info_fields(NewPlayer, [{evil, Evil}]),
			NewPlayer;
		true ->
			Player
	end.

%% 更新玩家最后登录时间
update_last_login(Player, Now, LastLoginIP) ->
	if
		%% PHP注册的原因,当第一次登陆的时候，玩家字段信息不全，需补全
		Player#player.last_login_time == 0 ->
			 ValueList = lists:nthtail(1, tuple_to_list(Player)), 
			 FieldList = record_info(fields, player),
			 KeyVal = make_update_key_val(ValueList,FieldList,[]),
			 ?DB_MODULE:update(player,KeyVal,[{id,Player#player.id}]),
			 %%完成第一个任务
			 lib_task:first_task(Player#player.id),
			 %%防止val为空[]
			 F = fun(V) ->
				case V of
					[] -> <<>> ;
					_ -> V
				end
			end,
			NewValList = lists:map(F, ValueList),
			NewPlayer = list_to_tuple([player | NewValList]);
		true ->
			NewPlayer = Player
	end,
	%% 修改最后登录时间
	spawn(fun()-> db_agent:update_last_login(Now, LastLoginIP, Player#player.id) end),
	%% 玩家登陆日志
	if
		Now - NewPlayer#player.last_login_time > 1800 ->
			spawn(fun()-> db_agent:insert_login_user(Player#player.id, Player#player.nickname, Now, LastLoginIP) end);
		true ->
			skip
	end,
	NewPlayer.

make_update_key_val([],[],Merge) ->
	Merge;
make_update_key_val([V|ValueList],[F|FieldList],Merge) ->
	make_update_key_val(ValueList,FieldList,[{F,V}|Merge]).

%% 更新在线时间
update_online_time(PlayerState, PlayerId, Now, LastLoginTime) ->
	OnlineTime =
		case util:is_same_date(Now, LastLoginTime) of
			true ->
				case db_agent:get_player_online_time(PlayerId) of
					[] ->
						spawn(fun()-> db_agent:insert_player_online_time(PlayerId, Now) end),
						0;
					[[OT]] ->
						OT
				end;
			false ->
				spawn(fun()-> db_agent:insert_player_online_time(PlayerId, Now) end),
				0
		end,
	PlayerState#player_state{
		online_time = OnlineTime
	}.

%%  1,等级不足30；2，在仙侣情缘中已被邀请；3，请先完成仙侣情缘任务；4，元宝不足；5，今天变性次数到达上限；6，提亲期间及已婚人士不能变性
check_sex_change(PlayerState) ->
	Player = PlayerState#player_state.player,
	%%1、检查等级 
	case Player#player.lv < 30 of
		true -> {1,PlayerState,[]};
		false -> 
			%%2,检查是否仙侣情缘被邀请
			case erlang:get(sex_change_invited) of
				1  -> {2,PlayerState,[]};
				undefined->
					%%3，检查仙侣情缘是否正在进行
					case lib_love:select_love(Player#player.id) of
						[] ->{6,PlayerState, []};
						[R] -> case R#ets_love.status of
								   1 -> {3,PlayerState,[]};
								   0 -> 
%% 									   %%结了婚不可以变性
									   if Player#player.sex =:= 1 ->
											  Ms = ets:fun2ms(fun(M) when M#ets_marry.boy_id =:= Player#player.id -> M end);
										  true ->
											  Ms = ets:fun2ms(fun(M) when M#ets_marry.girl_id =:= Player#player.id -> M end)
									   end,
									   case ets:select(?ETS_MARRY,Ms) of
										   []->
											   %%4,检查是否有绝情丹
											   PatternBag = #goods{ player_id=Player#player.id, goods_id=28042, location=4, _='_' },
											   case goods_util:get_ets_list(?ETS_GOODS_ONLINE, PatternBag) of
												   [] -> {4,PlayerState,[]};
												   _-> go_change_sex(PlayerState)
											   end;
										    [Marry|_Rets]->
											   %%离婚的可以变性
												case Marry#ets_marry.divorce =:= 1 of
													true ->
														PatternBag = #goods{ player_id=Player#player.id, goods_id=28042, location=4, _='_' },
														case goods_util:get_ets_list(?ETS_GOODS_ONLINE, PatternBag) of
															[] -> {4,PlayerState,[]};
															_->	go_change_sex(PlayerState)
														end;
													false ->
														{6,PlayerState,[]}
												end
									   end
							   end
					end
			end
	end.
%%物品所在位置，1 装备一，2成就背包，3 暂没用, 4 背包，5 仓库，6任务物品，7诛邪仓库 ，8氏族仓库，9临时矿包,10农场背包
%%职业 1，2，3，4，5（分别是玄武--战士、白虎--刺客、青龙--弓手、朱雀--牧师、麒麟--武尊）
%%改变性别等一系列操作
go_change_sex(PlayerState) ->
	Player = PlayerState#player_state.player,
	case get_fashion_by_career(Player) of
		false -> {6, PlayerState, []};
		[{NewTypeId,TypeId},{NewTypeId2,TypeId2},{NewTypeId3,TypeId3},{NewTypeId4,TypeId4}] ->
			%%变换身上的
			{Result,ResPlayer,ResTypeId} = real_change_equip([{NewTypeId,TypeId},{NewTypeId2,TypeId2},{NewTypeId3,TypeId3},{NewTypeId4,TypeId4}],PlayerState),
			%%变换背包的
			real_change_bag([{NewTypeId,TypeId},{NewTypeId2,TypeId2},{NewTypeId3,TypeId3},{NewTypeId4,TypeId4}],PlayerState),
			%%变换衣橱的
			lib_wardrobe:change_warbrode_sex(ResPlayer#player_state.player#player.id, ResPlayer#player_state.player#player.other#player_other.equip_current),
			%%消耗绝情丹
			gen_server:call(Player#player.other#player_other.pid_goods,{'delete_more', 28042, 1}),
			{Result,ResPlayer,ResTypeId}
	end.

%%变换身上的时装
real_change_equip([{NewTypeId,TypeId},{NewTypeId2,TypeId2},{NewTypeId3,TypeId3},{NewTypeId4,TypeId4}],PlayerState) ->
    Player = PlayerState#player_state.player,
	%%是否装备普通时装
	Pattern = #goods{ player_id=Player#player.id, goods_id=TypeId, location=1, _='_' },
	{Result, EquipPlayerState, Fashion1} = 
	case goods_util:get_ets_list(?ETS_GOODS_ONLINE, Pattern) of
		[] -> 
			%%性别 1男 2女
			%%是否装备中秋时装
			Pattern2 = #goods{ player_id=Player#player.id, goods_id=TypeId2, location=1, _='_' },
			case goods_util:get_ets_list(?ETS_GOODS_ONLINE, Pattern2) of
				[] ->
					Pattern3 = #goods{ player_id=Player#player.id, goods_id=TypeId3, location=1, _='_' },
					case goods_util:get_ets_list(?ETS_GOODS_ONLINE, Pattern3) of
						[] ->
							%%2种时装都没有穿
							%%改变称号,性别
							Pattern4 = #goods{ player_id=Player#player.id, goods_id=TypeId4, location=1, _='_' },
							case goods_util:get_ets_list(?ETS_GOODS_ONLINE, Pattern4) of
								[] ->
									NewPlayer = change_title(Player),
									{7,PlayerState#player_state{player = NewPlayer},[]};
								[Info4]->
									if Info4#goods.icon > 0 ->
										   NewIcon = NewTypeId4;
									   true ->
										   NewIcon = 0
									end,
									NewPlayer = change_title(Player),
									ets:insert(?ETS_GOODS_ONLINE,Info4#goods{goods_id = NewTypeId4, icon = NewIcon}),
									%%改变当前要显示的装备
									[Weapon,_Shirt,_Fbyf,_Spyf,Mot] =  NewPlayer#player.other#player_other.equip_current,
									if NewIcon>0 ->
										   NewPlayer2 = NewPlayer#player{other = NewPlayer#player.other#player_other{equip_current = [Weapon,NewIcon,_Fbyf,_Spyf,Mot]}};
									   true ->
										   NewPlayer2 = NewPlayer#player{other = NewPlayer#player.other#player_other{equip_current = [Weapon,NewTypeId4,_Fbyf,_Spyf,Mot]}}
									end,
									spawn(fun() -> db_agent:mid_fashion_change(Info4#goods.id, NewTypeId4, NewIcon) end),
									{7,PlayerState#player_state{player = NewPlayer2},[{Info4#goods.id, Info4#goods.location}]}
							end;
									
						[Info3] ->
						%%穿了感恩时装
							if Info3#goods.icon > 0 ->
								   NewIcon = NewTypeId3;
							   true ->
								   NewIcon = 0
							end,
							NewPlayer = change_title(Player),
							ets:insert(?ETS_GOODS_ONLINE,Info3#goods{goods_id = NewTypeId3, icon = NewIcon}),
							%%改变当前要显示的装备
							[Weapon,_Shirt,_Fbyf,_Spyf,Mot] =  NewPlayer#player.other#player_other.equip_current,
							if NewIcon>0 ->
								   NewPlayer2 = NewPlayer#player{other = NewPlayer#player.other#player_other{equip_current = [Weapon,NewIcon,_Fbyf,_Spyf,Mot]}};
							   true ->
								   NewPlayer2 = NewPlayer#player{other = NewPlayer#player.other#player_other{equip_current = [Weapon,NewTypeId3,_Fbyf,_Spyf,Mot]}}
							end,
							spawn(fun() -> db_agent:mid_fashion_change(Info3#goods.id, NewTypeId3, NewIcon) end),
							{7,PlayerState#player_state{player = NewPlayer2}, [{Info3#goods.id, Info3#goods.location}]}
					end;
				[Info2] ->
					%%穿了中秋时装
					%%改变称号,性别
					if Info2#goods.icon > 0 ->
						   NewIcon = NewTypeId2;
					   true ->
						   NewIcon = 0
					end,				
					NewPlayer = change_title(Player),
					ets:insert(?ETS_GOODS_ONLINE,Info2#goods{goods_id = NewTypeId2, icon = NewIcon}),
					[Weapon,_Shirt,_Fbyf,_Spyf,Mot] =  NewPlayer#player.other#player_other.equip_current,
					if NewIcon>0 ->
						   NewPlayer2 = NewPlayer#player{other = NewPlayer#player.other#player_other{equip_current = [Weapon,NewIcon,_Fbyf,_Spyf,Mot]}};
					   true ->
						   NewPlayer2 = NewPlayer#player{other = NewPlayer#player.other#player_other{equip_current = [Weapon,NewTypeId2,_Fbyf,_Spyf,Mot]}}
					end,
					spawn(fun() -> db_agent:mid_fashion_change(Info2#goods.id, NewTypeId2, NewIcon) end),
					{7,PlayerState#player_state{player = NewPlayer2}, [{Info2#goods.id, Info2#goods.location}]}
			end;
		[Info] ->
			%%改变称号,性别
			%%针对用过变身券的时装
			if Info#goods.icon > 0 ->
				   NewIcon = NewTypeId;
			   true ->
				   NewIcon = 0
			end,
			NewPlayer = change_title(Player),
			ets:insert(?ETS_GOODS_ONLINE,Info#goods{goods_id = NewTypeId, icon = NewIcon}),
			%%改变当前要显示的装备
			[Weapon,_Shirt,_Fbyf,_Spyf,Mot] =  NewPlayer#player.other#player_other.equip_current,
			if NewIcon>0 ->
				   NewPlayer2 = NewPlayer#player{other = NewPlayer#player.other#player_other{equip_current = [Weapon,NewIcon,_Fbyf,_Spyf,Mot]}};
			   true ->
                   %%原来代码
                   NewPlayer2 = NewPlayer#player{other = NewPlayer#player.other#player_other{equip_current = [Weapon,NewTypeId,_Fbyf,_Spyf,Mot]}}
			end,
            spawn(fun() -> db_agent:mid_fashion_change(Info#goods.id, NewTypeId, NewIcon) end),
            {7,PlayerState#player_state{player = NewPlayer2}, [{Info#goods.id, Info#goods.location}]}
	end,
	%%法宝变性
	EquipPlayer = EquipPlayerState#player_state.player,
	PatternFabao = #goods{ player_id=EquipPlayer#player.id, location=1, cell  = 15, _='_' },
	case goods_util:get_ets_list(?ETS_GOODS_ONLINE, PatternFabao) of
		[] ->
			{Result, EquipPlayerState, Fashion1};
		[FaBao] ->
			case get_fashion_fb_sp_change(FaBao#goods.goods_id) of
				0 ->
					{Result, EquipPlayerState, Fashion1};
				NFBGoodsTypeId ->
					FBNIcon = 
						if FaBao#goods.icon > 0 ->
							   NFBGoodsTypeId;
						   true ->
							   0
						end,
					NewFaBao = FaBao#goods{goods_id = NFBGoodsTypeId, icon = FBNIcon},
					ets:insert(?ETS_GOODS_ONLINE, NewFaBao),
					%%改变当前要显示的装备
					[_FBWeapon,_FBShirt,_FBFbyf,_FBSpyf,FBMot] =  EquipPlayer#player.other#player_other.equip_current,
					if 
						FBNIcon > 0 ->
							FaBaoPlayer = EquipPlayer#player{other = EquipPlayer#player.other#player_other{equip_current = [_FBWeapon,_FBShirt,FBNIcon,_FBSpyf,FBMot]}};
						true ->
							FaBaoPlayer = EquipPlayer#player{other = EquipPlayer#player.other#player_other{equip_current = [_FBWeapon,_FBShirt,NFBGoodsTypeId,_FBSpyf,FBMot]}}
					end,
					spawn(fun() -> db_agent:mid_fashion_change(FaBao#goods.id, NFBGoodsTypeId, FBNIcon) end),
					{Result, EquipPlayerState#player_state{player = FaBaoPlayer},[{NewFaBao#goods.id, NewFaBao#goods.location}|Fashion1]}
			end
	end.


%%变换背包的时装
real_change_bag([{NewTypeId,TypeId},{NewTypeId2,TypeId2},{NewTypeId3,TypeId3},{NewTypeId4,TypeId4}],PlayerState) ->
	Player = PlayerState#player_state.player,
	PatternBag = #goods{ player_id=Player#player.id, goods_id=TypeId, location=4, _='_' },
	PatternBag2 = #goods{ player_id=Player#player.id, goods_id=TypeId2, location=4, _='_' },
	PatternBag3 = #goods{ player_id=Player#player.id, goods_id=TypeId3, location=4, _='_' },
	PatternBag4 = #goods{ player_id=Player#player.id, goods_id=TypeId4, location=4, _='_' },
	case goods_util:get_ets_list(?ETS_GOODS_ONLINE, PatternBag) of
		[] ->skip;
		Fashions ->
			%%普通时装
			F = fun(Fashion) ->	
						 if Fashion#goods.icon>0 ->
								NewIcon = NewTypeId;
							true ->
								NewIcon = 0
						 end,
						ets:insert(?ETS_GOODS_ONLINE,Fashion#goods{goods_id = NewTypeId, icon = NewIcon}),
						spawn(fun() -> db_agent:mid_fashion_change(Fashion#goods.id, NewTypeId, NewIcon) end)
				end,
			[F(Fashion) || Fashion <- Fashions]
	end,
	case goods_util:get_ets_list(?ETS_GOODS_ONLINE, PatternBag2) of
		[] ->skip;
		MidFashions ->
			%%中秋时装
			F2 = fun(MidFashion) ->
						 if MidFashion#goods.icon>0 ->
								NewIcon2 = NewTypeId2;
							true ->
								NewIcon2 = 0
						 end,
						 ets:insert(?ETS_GOODS_ONLINE,MidFashion#goods{goods_id = NewTypeId2, icon = NewIcon2}),
						 spawn(fun() -> db_agent:mid_fashion_change(MidFashion#goods.id, NewTypeId2, NewIcon2) end)
				 end,
			[F2(MidFashion) || MidFashion <- MidFashions]
	end,
	case goods_util:get_ets_list(?ETS_GOODS_ONLINE, PatternBag3) of
		[] ->skip;
		GanFashions ->
			%%感恩
			F3 = fun(GanFashion) ->
						 if GanFashion#goods.icon>0 ->
								NewIcon3 = NewTypeId3;
							true ->
								NewIcon3 = 0
						 end,
						 ets:insert(?ETS_GOODS_ONLINE,GanFashion#goods{goods_id = NewTypeId3, icon = NewIcon3}),
						 spawn(fun() -> db_agent:mid_fashion_change(GanFashion#goods.id, NewTypeId3, NewIcon3) end)
				 end,
			[F3(GanFashion) || GanFashion <- GanFashions]
	end,
	case goods_util:get_ets_list(?ETS_GOODS_ONLINE, PatternBag4) of
		[] ->skip;
		NewFashions ->
			%%感恩
			F4 = fun(NewFashion) ->
						 if NewFashion#goods.icon>0 ->
								NewIcon4 = NewTypeId4;
							true ->
								NewIcon4 = 0
						 end,
						 ets:insert(?ETS_GOODS_ONLINE,NewFashion#goods{goods_id = NewTypeId4, icon = NewIcon4}),
						 spawn(fun() -> db_agent:mid_fashion_change(NewFashion#goods.id, NewTypeId4, NewIcon4) end)
				 end,
			[F4(NewFashion) || NewFashion <- NewFashions]
	end,
	%%法宝变性
	FaBaoPattern = #goods{ player_id=Player#player.id, type = 10, subtype = 26, location=4, _='_' },
	case goods_util:get_ets_list(?ETS_GOODS_ONLINE, FaBaoPattern) of
		[] ->
			skip;
		FaBaos ->
			FunFaBao = 
				fun(FaBaoElem) ->
						case get_fashion_fb_sp_change(FaBaoElem#goods.goods_id) of
							0 ->
								skip;
							NFaBaoGoodsTypeId ->
								FBNIcon = 
									if 
										FaBaoElem#goods.icon>0 ->
											NFaBaoGoodsTypeId;
										true ->
											0
									end,
								ets:insert(?ETS_GOODS_ONLINE, FaBaoElem#goods{goods_id = NFaBaoGoodsTypeId, icon = FBNIcon}),
								spawn(fun() -> db_agent:mid_fashion_change(FaBaoElem#goods.id, NFaBaoGoodsTypeId, FBNIcon) end)
						end
				end,
			[FunFaBao(EFaBao) || EFaBao <- FaBaos]
	end.


%%改变称号,性别
change_title(Player) ->
	Titles = Player#player.other#player_other.titles,
	NPlayer = 
		case Player#player.sex of
			1 ->
				NeedIds = [{801, 802},{803, 804}],
			   {Type, NTitles} = lib_title:sex_change_title(NeedIds, Titles),
			   Player#player{other = Player#player.other#player_other{titles = NTitles},
							 sex = 2};
			_ ->
				NeedIds = [{802, 801}, {804, 803}],
				{Type, NTitles} = lib_title:sex_change_title(NeedIds, Titles),
				Player#player{other = Player#player.other#player_other{titles = NTitles},
							  sex = 1}
		end,
	lib_achieve_outline:change_tieles_sex(Player#player.id, NeedIds),
	case Type =:= 1 of
		true ->
			NTitlesStr = util:term_to_string(NTitles),
			spawn(fun() -> db_agent:update_cur_title(NTitlesStr, Player#player.id) end);
		false ->
			skip
	end,
	NPlayer.

%%根据职业和性别获取时装ID
get_fashion_by_career(Player) ->
	case Player#player.career of
		1->%%玄武
           if Player#player.sex =:= 1 ->%%梵音(帅哥)
				   [{10910,10901},{10912,10911},{10922,10921},{10932,10931}];  
			   true ->
				   [{10901,10910},{10911,10912},{10921,10922},{10931,10932}]  
			end;
		3-> %%青龙
			if Player#player.sex =:= 1 ->
				   [{10904,10909},{10916,10915},{10926,10925},{10936,10935}];  
			   true ->
				   [{10909,10904},{10915,10916},{10925,10926},{10935,10936}]  
			end;
		2-> %%白虎
			if Player#player.sex =:= 1 ->
				   [{10902,10903},{10914,10913},{10924,10923},{10934,10933}];  %% 墨魂(美女)
			   true ->
				   [{10903,10902},{10913,10914},{10923,10924},{10933,10934}]  %% 墨魂(帅哥)
			end;
		4-> %%朱雀
			if Player#player.sex =:= 1 ->
				   [{10906,10905},{10918,10917},{10928,10927},{10938,10937}];  %% 栖凤(美女)
			   true ->
				   [{10905,10906},{10917,10918},{10927,10928},{10937,10938}]  %% 栖凤(帅哥)
			end;
		5->  %%麒麟
			if Player#player.sex =:= 1 ->
				   [{10908,10907},{10920,10919},{10930,10929},{10940,10939}];  %% 瑶光(美女)
			   true ->
				   [{10907,10908},{10919,10920},{10929,10930},{10939,10940}]  %% 瑶光(帅哥)
			end;
		_ ->
			false
	end.
%% 因为变性而时装变换需要转换的Ids
get_fashion_equip_change(GoodsTypeId) ->
	case GoodsTypeId of
		%%玄武女
		10910 -> 10901;
		10912 -> 10911;
		10922 -> 10921;
		10932 -> 10931;
		%%玄武男
		10901 -> 10910;
		10911 -> 10912;
		10921 -> 10922;
		10931 -> 10932;
		%%青龙女
		10904 -> 10909;
		10916 -> 10915;
		10926 -> 10925;
		10936 -> 10935;
		%%青龙男
		10909 -> 10904;
		10915 -> 10916;
		10925 -> 10926;
		10935 -> 10936; 
		%%白虎女
		10902 -> 10903;
		10914 -> 10913;
		10924 -> 10923;
		10934 -> 10933;
		%%白虎男
		10903 -> 10902;
		10913 -> 10914;
		10923 -> 10924;
		10933 -> 10934;
		%%朱雀女
		10906 -> 10905;
		10918 -> 10917;
		10928 -> 10927;
		10938 -> 10937;
		%%朱雀男
		10905 -> 10906;
		10917 -> 10918;
		10927 -> 10928;
		10937 -> 10938;
		%%麒麟女
		10908 -> 10907;
		10920 -> 10919;
		10930 -> 10929;
		10940 -> 10939;
		%%麒麟男
		10907 -> 10908;
		10919 -> 10920;
		10929 -> 10930;
		10939 -> 10940; 
		_ -> 0
	end.

%%变性法宝时装和饰品时装相应改变
get_fashion_fb_sp_change(GoodsTypeId) ->
	case GoodsTypeId of
		%%青龙男
		10820 -> 10821;
		10821 -> 10820;
		%%玄武男
		10822 -> 10823;
		10823 -> 10822;
		%%麒麟男
		10824 -> 10825;
		10825 -> 10824;
		%%白虎男
		10826 -> 10827;
		10827 -> 10826;
		%%朱雀男
		10828 -> 10829;
		10829 -> 10828;
		%%青龙男
		10830 -> 10831;
		10831 -> 10830;
		%%玄武男
		10832 -> 10833;
		10833 -> 10832;
		%%麒麟男
		10834 -> 10835;
		10835 -> 10834;
		%%白虎男
		10836 -> 10837;
		10837 -> 10836;
		%%朱雀男
		10838 -> 10839;
		10839 -> 10838;
		_ -> 0
	end.


%查询角色属性
get_palyer_properties(Player_Id,FieldList) ->
	Player = get_online_info(Player_Id),
	case Player of
		[] -> 
			db_agent:get_player_fields(FieldList,Player_Id);
		_ ->
			lib_player_rw:get_player_info_fields(Player, FieldList)
	end.

get_guild_post_title(GuildPosition) ->
	case GuildPosition of
		0 ->
%% 			?DEBUG("11111", []),
			lib_guild_inner:string_to_binary_and_len("");
		1 ->
%% 			?DEBUG("22222", []),
			lib_guild_inner:string_to_binary_and_len("族长");
		Value when Value =:= 2 orelse Value =:= 3  ->
%% 			?DEBUG("33333", []),
			lib_guild_inner:string_to_binary_and_len("长老");
		Value when Value =:= 4 orelse Value =:= 5 orelse Value =:= 6 orelse Value =:= 7 ->
%% 			?DEBUG("4444", []),
			lib_guild_inner:string_to_binary_and_len("堂主");
		_ ->
%% 			?DEBUG("55555", []),
			lib_guild_inner:string_to_binary_and_len("弟子")
	end.

%%根据充值元宝数算得玩家积分
get_player_pay_gold(PlayerId)->
	case db_agent:get_gold_for_score(PlayerId) of
		[Golds] -> Golds;
		[] -> Golds = 0
	end,		  
	%%积分消耗数
	case db_agent:get_sub_score(PlayerId) of
		[Subs] -> Subs;
		[] -> Subs = 0
	end,
	Scores = round(Golds/10),
	Scores - Subs.

%%统计玩家累计充值
calc_player_pay(PlayerId,Type,Timestamp)->
	Days= 
		case Type of
			1->2;
			2->7;
			_->0
		end,
	Time = Timestamp + Days*86400,
	PayBag = db_agent:get_player_pay(PlayerId,Time),
	calc_pay(PayBag,0).
calc_pay([],Gold)->Gold;
calc_pay([Pay|PayBag],Gold)->
	[Gold1|_] = Pay,
	calc_pay(PayBag,Gold1+Gold).

%% 保存玩家分身数据
backup_player_data(Player) ->
	Buff = Player#player.other#player_other.battle_status,
	case 
			lists:keyfind(last_zone_def, 1, Buff) == false 
			andalso lists:keyfind(last_zone_att, 1, Buff) == false 
			andalso lists:keyfind(castle_rush_att, 1, Buff) == false 
			andalso lists:keyfind(castle_rush_anti, 1, Buff) == false
	of
		true ->
			backup_player_data_action(Player);
		false ->
			skip
	end.
backup_player_data_action(Player) ->
	OutPetId = 
		case is_record(Player#player.other#player_other.out_pet, ets_pet) of
			true ->
				Player#player.other#player_other.out_pet#ets_pet.id;
			false ->
				0
		end,
	case db_agent:select_row(player_backup, "id", [{player_id, Player#player.id}]) of
		[] ->
			FieldList = [player_id, hp_lim, mp_lim, att_max, att_min, buff, hit, dodge, crit, deputy_skill, deputy_passive_skill, 
							deputy_prof_lv, anti_wind, anti_water, anti_thunder, anti_fire, anti_soil, stren, suitid, goods_ring4, 
							equip_current, out_pet_id, pet_batt_skill],
			ValueList = [
				Player#player.id,
				Player#player.hp_lim,
				Player#player.mp_lim,
				Player#player.max_attack,
				Player#player.min_attack,
				util:term_to_string(Player#player.other#player_other.battle_status),
				Player#player.hit,	
				Player#player.dodge,
				Player#player.crit,
				util:term_to_string(Player#player.other#player_other.deputy_skill),
				util:term_to_string(Player#player.other#player_other.deputy_passive_att),
				Player#player.other#player_other.deputy_prof_lv,	
				Player#player.anti_wind,
				Player#player.anti_water,	
				Player#player.anti_thunder,	
				Player#player.anti_fire,	
				Player#player.anti_soil,
				Player#player.other#player_other.stren,
				Player#player.other#player_other.suitid,
				util:term_to_string(Player#player.other#player_other.goods_ring4),
				util:term_to_string(Player#player.other#player_other.equip_current),
				OutPetId,
				util:term_to_string(Player#player.other#player_other.pet_batt_skill)
			],
			db_agent:insert(player_backup, FieldList, ValueList); 
		_ ->
			ValueList = [
				{hp_lim, Player#player.hp_lim},
				{mp_lim, Player#player.mp_lim},
				{att_max, Player#player.max_attack},
				{att_min, Player#player.min_attack},
				{buff, util:term_to_string(Player#player.other#player_other.battle_status)},
				{hit, Player#player.hit},	
				{dodge, Player#player.dodge},
				{crit, Player#player.crit},
				{deputy_skill, util:term_to_string(Player#player.other#player_other.deputy_skill)},
				{deputy_passive_skill, util:term_to_string(Player#player.other#player_other.deputy_passive_att)},
				{deputy_prof_lv, Player#player.other#player_other.deputy_prof_lv},	
				{anti_wind, Player#player.anti_wind},
				{anti_water, Player#player.anti_water},	
				{anti_thunder, Player#player.anti_thunder},	
				{anti_fire, Player#player.anti_fire},	
				{anti_soil, Player#player.anti_soil},
				{stren, Player#player.other#player_other.stren},
				{suitid, Player#player.other#player_other.suitid},
				{goods_ring4, util:term_to_string(Player#player.other#player_other.goods_ring4)},
				{equip_current, util:term_to_string(Player#player.other#player_other.equip_current)},
				{out_pet_id, OutPetId},
				{pet_batt_skill, util:term_to_string(Player#player.other#player_other.pet_batt_skill)}
			],
			db_agent:update(player_backup, ValueList, [{player_id, Player#player.id}])
	end.


%% 获取玩家信息
get_player_info(PlayerId) ->
	Player1 = lib_account:get_info_by_id(PlayerId),	
	Player2 = list_to_tuple([player | Player1]),
	Skill = lib_skill:get_all_skill(PlayerId),
	Player3 = Player2#player{
  		nickname = binary_to_list(Player2#player.nickname),
  		guild_name = binary_to_list(Player2#player.guild_name),
		other = #player_other{
			skill = Skill					  
		}					 
	},
	FieldList = "hp_lim, mp_lim, att_max, att_min, buff, hit, dodge, crit, deputy_skill, deputy_passive_skill, deputy_prof_lv, anti_wind, anti_water, anti_thunder, anti_fire, anti_soil, stren, suitid, goods_ring4, equip_current, out_pet_id, pet_batt_skill",
	case db_agent:select_row(player_backup, FieldList, [{player_id, PlayerId}]) of
		[HpLim, MpLim, AttMax, AttMin, Buff, Hit, Dodge, Crit, DeputySkill, DeputyPassiveSkill, DeputyProfLv, 
		 		AntiWind, AntiWater, AntiThunder, AntiFire, AntiSoil, Stren, Suitid, GoodsRing4, EquipCurrent, OutPetId, PetBattSkill] ->
			OutPet = 
				if
					OutPetId > 0 ->
						OutPetInfo = db_agent:select_row(pet, "*", [{id, OutPetId}]),
						list_to_tuple([ets_pet | OutPetInfo]);
					true ->
						[]
				end,
			Player3#player{
				hp = HpLim,
				hp_lim = HpLim,
				mp = MpLim,
				mp_lim = MpLim,
				max_attack = AttMax,
				min_attack = AttMin,
				hit = Hit,
				dodge = Dodge,
				crit = Crit,
				anti_wind = AntiWind,
				anti_water = AntiWater,
				anti_thunder = AntiThunder,
				anti_fire = AntiFire,
				anti_soil = AntiSoil,
				other = Player3#player.other#player_other{
            		battle_status = util:string_to_term(tool:to_list(Buff)),
					deputy_skill = util:string_to_term(tool:to_list(DeputySkill)),
					deputy_passive_att = util:string_to_term(tool:to_list(DeputyPassiveSkill)),
					deputy_prof_lv = DeputyProfLv,
					stren = Stren,
					suitid = Suitid,
					goods_ring4 = util:string_to_term(tool:to_list(GoodsRing4)),
					equip_current = util:string_to_term(tool:to_list(EquipCurrent)),
					out_pet = OutPet,
					pet_batt_skill = util:string_to_term(tool:to_list(PetBattSkill))
              	}	   
			};
		_ ->
			Player3#player{
				hp = 5000,
				hp_lim = 5000,
				max_attack = Player2#player.max_attack + 1
			}	
	end.

	
	

