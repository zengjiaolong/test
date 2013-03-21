%%%------------------------------------------------
%%% File    : record.erl
%%% Author  : ygzj
%%% Created : 2010-09-15
%%% Description: record
%%%------------------------------------------------
-include("table_to_record.hrl").

%%物品当前buff效果 要在player_othre前定义
-record(goods_cur_buff,
		{hp_lim =1,			%%气血上限
		 mp_lim =1,			%%魔法上限
		 exp_mult =1, 		%%经验倍数
		 spi_mult =1, 		%%灵力倍数
		 def_mult =1,		%%防御倍数
		 pet_mult = 1,		%%灵兽经验倍数
		 peach_mult = 1,	%%蟠桃倍数
		 turned_mult = [],    %%变身加成属性[{Fields,Value}]
		 pet_mult_exp = 1, %%灵兽经验倍数
		 culture = 1,         %%修为倍数
		 chr_fash = [],       %%圣诞礼服
		 chr_mount = 0,     %%圣诞坐骑
		 chr_pet = 0         %%圣诞灵兽
}).

-record(guild_h_skill,
		{g_att = 0,
		 g_def = 0,
		 g_hp = 0,
		 g_mp = 0,
		 g_hit = 0,
		 g_dodge = 0,
		 g_crit = 0}).

%% 战斗字典
-record(battle_dict, {
    last_dodge_time = 0,            							%% 上次躲闪时间
    last_skill_time = [],            							%% [{技能ID,上次时间}]
	pet_skill_time = []											%% [{宠物技能ID,上次时间}]
}).

%%用户的其他附加信息(对应player.other)
-record(player_other, {
	base_player_attribute = [], % 人物初始基础属性[forza,physique,wit,agile,speed] 
    base_attribute = [],  		% 初始二级属性列表[Hp, Mp, MaxAtt, MinAtt Def, Hit, Dodge, Crit, Anti_wind,Anti_fire,Anti_water,Anti_thunder]
	two_attribute = [],   		% 一级转二级属性列表[Hp, Mp, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Anti_wind,Anti_fire,Anti_water,Anti_thunder]
						   
	pet_attribute = [0,0,0,0],  % 宠物属性列表[力量,敏捷,智力,体质]	
	pet_skill_mult_attribute = [0,0,0,0,0,0,0,0,0],% 宠物技能对属性的系数加成 [气血，法力，防御，攻击，抗性，命中，闪躲，打坐回血，打坐回蓝]
	mount_mult_attribute = [0,0,0,0,0,0,0,0,0,0,0,0],%%坐骑的加成效果[气血1,法力2,攻击3,防御4,命中5,闪避6,暴击7,风抗8,火抗9,水抗10,雷抗11,土抗12] 
								
    equip_attrit = 0,   		% 装备磨损数，下线则清零
    equip_current = [0,0,0,0,0], 	% 当前装备类型ID - [武器, 衣服, 法宝时装, 饰品时装, 坐骑]
    equip_attribute= [], 		% 装备加成属性列表[Hp, Mp, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Anti_wind,Anti_fire,Anti_water,Anti_thunder]
	equip_player_attribute=[0,0,0,0,0],  % 装备对人物基础属性的加成[E_forza,E_physique,E_wit,E_agile,E_speed]
	equip_mult_attribute=[0,0],    % 装备对属性的系数加成;暂有[hp,crit]
	meridian_attribute =[0,0,0,0,0,0,0,0],%%经脉属性加成
    leader = 0,          		% 队伍状态，0是未组队，1为队长，2为队员, 8天龙，9地虎, 11红方，12蓝方，13攻城战攻方，14攻城战守方
    skill = [],          		% 技能
	light_skill = [], 			% 轻功技能
	passive_skill = [],         % 被动技能
	deputy_skill = [],			% 神器技能
	deputy_prof_lv = 0,			% 神器技能熟练等级
	deputy_passive_att = [],    % 神器被动技能属性列表
	stren = 0,					% 法宝的强化等级
	fbyfstren = 0,				% 法宝时装强化等级
	spyfstren = 0,				% 挂饰强化等级
	fullstren =0,				% 全套强化等级
	suitid = 0,					% 套装ID
	out_pet = [],				% 出战的宠物	
    socket = undefined,			% 当前用户的socket
	socket2 = undefined,		% 当前用户的子socket2
	socket3 = undefined,		% 当前用户的子socket3
	pid_socket = undefined,		% socket管理进程pid
    pid = undefined,          	% 用户进程Pid
    pid_goods = undefined,      % 物品模块进程Pid
    pid_send = [],				% 消息发送进程Pid(可多个)
	pid_send2 = [],				% socket2的消息发送进程Pid
	pid_send3 = [],				% socket3的消息发送进程Pid
    pid_dungeon = undefined,  	% 副本（战场）进程Pid
    pid_fst = [],  			    % 封神台进程Pid列表
    pid_team = undefined,       % 组队进程Pid
	pid_scene = undefined,	  	% 当前场景Pid
	pid_task = undefined,		% 当前任务Pid
	pid_meridian = undefinded,  % 当前经脉pid
	pid_love = undefinded,      % 当前远古情缘pid
	node = undefined,			% 进程所在节点    
    battle_status = [],   		% 战斗状态
    battle_limit = 0,           % 战斗时的一些受限制状态，1定神，2昏迷，3沉默，9无敌	
	trade_status = {0, 0},		% 交易状态信息{状态, 对方玩家ID}状态：0没在交易，1正在交易中，2交易锁定，3按了交易
	trade_list = [],			% 交易物品表，列表元素格式{物品ID，数量，是否给自己}，物品ID：1元宝，2铜币，其他，是否给自己，1：别人给自己，2自己给别人的
	goods_buff = #goods_cur_buff{},
	fst_exp_ttl = 0,			% 封神台累积经验
	fst_spr_ttl = 0,			% 封神台累积灵力
	fst_hor_ttl = 0,			% 封神台累积荣誉
	be_bless_time = 0,			% 可被祝福次数
	bless_limit_time = 0,		% 祝福限制时间
	bless_list = [],			% 对此次升级已经发送过祝福的祝福者列表,
	exc_status = 0,				% 凝神修炼标识0为非凝神修炼状态
	mount_stren = 0,			%坐骑的强化等级
	guild_h_skills = #guild_h_skill{},	%氏族高级技能加成[13氏族攻击，14氏族防御，15氏族气血，16氏族法力，17氏族命中，18氏族闪躲，19氏族暴击]
	guild_feats = 0,			%个人氏族功勋
	blacklist = false,			%是否受黑名单监控		
	charm = 0,                  %魅力值
%% 	charm_title = 0,			%魅力称号
%% 	charm_title_time = 0,      	%魅力称号到期时间	  
	peach_revel = 1,			%头上是否带着蟠桃，1：没有，2：初级，3：中级，4：高级
	privity_info=[], 			%%默契度测试基础信息  [对手，时间，默契度，当前答案，[题库]]	
	ach_pearl = [],   			%%玩家八神珠装备情况	
	goods_buf_cd = [],			% 物品buf对应的冷却时间	
	goods_ring4 = [],	     	%物品紫戒指技能和等级[{bless_skill,bless_level}]
	heartbeat = 0,              %%心跳包时间
	battle_dict = #battle_dict{},%% 战斗字典
	is_spring = 0,				%%是否在温泉里
	zxt_honor = 0,				%%诛仙台荣誉
	team_buff_level = 0 ,       %%组队亲密度buff加成等级
	die_time = 0,				%%死亡时间
	war_die_times = 0,			%%死亡次数
	love_invited = 0,           %%仙侣情缘任务中是否被邀请了
	batt_value = 0,             %%战斗力值
    turned = 0,                  %%0为未变身，大于0则是变身状态，值为NPC的ID  
	titles = [],					%%玩家当前头上的称号集
	accept = 1,                 %%是否接受双修邀请
	double_rest_id = 0,         %%双修对方的id
	realm_honor_player_list = [],		%% 上一次攻击获得荣誉的被杀者ID
	hook_pick = 0,											%% 挂机是否自动捡取
	hook_equip_list = [0, 0, 0, 0],							%% 挂机装备品质选项列表
	hook_quality_list = [0, 0, 0, 0],						%% 挂机品质选项列表
	shop_score = 0,		  									%% 商城积分
	castle_king = 0,									%% 是否拥有九霄城主BUFF，1有，0无
	g_alliance = [],				%%联盟中的氏族Id
	war_honor = [0,0,0,0,0],				%%封神争霸功勋
	war_honor_value=[0,0,0,0],		%%封神争霸功勋属性加成
	war2_scene= [],					%%封神争霸观战者场景信息
	shadow = 0,								%% 分身ID
	couple_skill=0,					%%夫妻传送技能CD
	pet_batt_skill = [] 		% 灵兽战斗功技能
}).

%% 物品掉落表
-record(ets_goods_drop, {
    id = 0,             	%% 编号
    mon_id = 0,             %% 怪物ID
    player_id = 0,      	%% 角色ID
    team_pid = undefined,  	%% 组队进程PID
    drop_goods = [],    	%% 掉落物品[[物品类型ID,物品类型,物品数量,物品品质]...]
    expire_time = 0,     	%% 过期时间
	scene = 0,				%% 掉落物所在场景
	unique_key = {0, 0}		%% 唯一标示
}).

%% 排行分类：
%% 	——个人排行：
%% 			等级排行
%% 			财富排行
%% 			荣誉排行
%% 			修为排行
%% 	——装备排行：
%% 			法宝排行
%% 			防具排行
%% 	——帮会排行：
%% 	——帮战排行：
%% 	——国战排行：
%% 	——我的排行：功能按键，点击后自动进入该玩家排行所在页面，该玩家角色名用红色表示。若玩家未进入100名，提示玩家“很遗憾，您未进入100名”

%% 排行榜
%% rank_list : [Object]（分三大类——1.个人排行、2.装备排行、3.帮会排行）
%%    Object : 1. [排名，角色ID，角色名，性别，职业，部落，帮会，排行值]
%%             2. [排名，物品ID，物品名，所有者，帮会，装备评分]
%%             3. [排名，氏族ID，氏族名，部落，等级]
-record(ets_rank, {
    type_id,            %% 排行类型ID
    rank_list           %% 排行信息列表
    }).

%% 物品状态表
-record(goods_status, {
    player_id = 0,              % 用户ID
    null_cells = [],            % 背包空格子位置
	pid_send = undefined,		% 玩家pid_send 进程组
    equip_current = [0,0,0],    % 当前装备类型ID - [武器, 衣服, 坐骑]
    equip_suit = [],            % 套装属性
    cd_list = [],               % 使用药品的冷却时间
	box_remain_cells = 500		% 诛邪仓库的剩余容量
    }).

%%队伍资料 
-record(team, {
    leaderid = 0,       		%% 队长id
    leaderpid= undefined,    	%% 队长pid
	leadername = [],			%% 队长名字
    teamname = [],      		%% 队名
    member = [],        		%% 队员列表
    dungeon_pid = undefined,    %% 副本进程id
	dungeon_scene_res_id = undefined,    %% 副本场景资源id
    fst_pid = [],    	%% 封神台进程id
    auto_access = 1,	%% 是否自由进入，0不能自由进入，1可以自由进入
    allot = 2,                   %% 队伍分配方式，1自由拾取，2投骰子随机分配
	close = [],
	close_rela =[],
	team_type = 0		%%队伍类型（0默认，1~4通过招募建立的队伍)
}).

%% 队员数据
-record(mb,  {
    id = 0,         		%% 队员id
    pid = undefined,     	%% 队员pid
    nickname = [],   		%% 队员名字
    state = 1,				%% 是否在线，0不在线，1在线
    career = 0,				%%如果玩家不在线，则发生以下信息
    lv = 0,
    hp = 0,
    hp_lim = 0,
    mp = 0, 
    mp_lim = 0,
    sex = 0,
	realm = 0,
	pid_send = undefined
}).

%%氏族正在升级记录总汇
-record(ets_guild_upgrade_status,	
		{guild_id,				%%氏族Id
		 guild_name,			%%氏族名字
		 current_level,			%%氏族当前等级（升级前）
		 upgrade_succeed_time	%%氏族升级成功的时间
}).

%%诛邪系统 的物品数据列表，其中X：职业类型，Y：妖洞类型
%%box_goods_CareerHoleType => box_goods_XY
-record(box_status, 
		{ets_box_goods_type = 1,
		 box_goods_11 = [],
		 box_goods_12 = [],
		 box_goods_13 = [],
		 box_goods_14 = [],
		 box_goods_21 = [],
		 box_goods_22 = [],
		 box_goods_23 = [],
		 box_goods_24 = [],
		 box_goods_31 = [],
		 box_goods_32 = [],
		 box_goods_33 = [],
		 box_goods_34 = [],
		 box_goods_41 = [],
		 box_goods_42 = [],
		 box_goods_43 = [],
		 box_goods_44 = [],
		 box_goods_51 = [],
		 box_goods_52 = [],
		 box_goods_53 = [],
		 box_goods_54 = []
}).

%%记录玩家开封印的特殊物品数量
-record(ets_open_boxgoods_trace,
		{player_id = 0,
		 goods_trace = []
}).

%%采集所需属性
-record(collect_status, {
    id,
    name,
    scene,                  %% 所属场景
    lv, 
    hp, 
	mp,
    hp_lim,
    x,                      %% 默认出生X
    y,                      %% 默认出生y
    pid = undefined,        %% 玩家进程
    cid = undefined,        %% 采集进程
    collect_status = [],     %% 采集状态
	type=0,
    pid_team = undefined 
}).


%%黑名单操作记录表
-record(ets_blacklist,{
		id,
		player_id,
		cmd,
		scene,
		x,
		y,
		gold,
		coin,
		bcoin,
		cash,
		time		
	}).
%% 关系列表	
%% relationship ==> ets_rela 	
-record(ets_rela, {	
      	id,                                     %% id
	  	pid,                              	  	%% 当前角色id
      	rid = 0,                                %% 对方角色的id	
      	rela = 0,                               %% 与B的关系(0:没关系1:好友2:黑名单3:仇人)	
      	time_form = 0,                          %% 建交时间
		nickname = [],      					%% 对方角色名字
    	sex = 0,            					%% 对方角色性别
    	lv = 0,             					%% 对方角色等级
    	career = 0 ,         					%% 对方角色职业
		close = 1,								%%总亲密度
		pk_mon=0,								%%每天打怪亲密度上限
		timestamp = 0							%%每日时间戳
    }).

%% 信息延时器列表	
%% ets_delayer 	
-record(ets_delayer, {
											id,
											dungeon_pid = undefined, 
											fst_pid = [], 
											team_pid = undefined
											}).
											
%% 招募组队小黑板	
%% ets_blackboard
-record(ets_blackboard, {
											id,			%% 招募者的ID
											nickname = [], %% 招募者的名字
											leader, %% 是否队长
											condition_1 = 0,
											condition_2 = 0,
											condition_3 = 0,
											min_lv	= 0,
											max_lv	= 0,
											career	= 0,
											lv			= 0,
											sex			= 0
											}).

-record(ets_spar, {
				   spar_id = 0,				%%水晶ID
				   x = 0,					%%水晶坐标X
				   y = 0,					%%水晶坐标Y
				   type = 0,				%%水晶类型
				   goods_id = 0				%%该水晶所产生的物品
				  }).
-record(ets_box_mon,{mon_id = 0,
					 coord = {0, 0},
					 lv = 0}).

%%答题角色ets的answer属性,注意两个ets定义先后顺序
-record(answer_properties,{
					opt = "",
					tool = 0,
					reference_id = 0 %%引用指定角色答案的映射
				   }).

%%答题角色ets
-record(ets_answer,{
					player_id = 0, %%角色id
					nickname = "", %%角色名字
					realm = 0,   %%角色部落
					status = 0,  %%角色状态
					score = 0, %%角色场景
				   	tool1 = 0, %%道具1
					tool2 = 0, %%道具2
					tool3 = 0, %%道具3
					answer1 = #answer_properties{},
					answer2 = #answer_properties{},
					answer3 = #answer_properties{},
					answer4 = #answer_properties{},
					answer5 = #answer_properties{},
					answer6 = #answer_properties{},
					answer7 = #answer_properties{},
					answer8 = #answer_properties{},
					answer9 = #answer_properties{},
					answer10 = #answer_properties{},
					answer11 = #answer_properties{},
					answer12 = #answer_properties{},
					answer13 = #answer_properties{},
					answer14 = #answer_properties{},
					answer15 = #answer_properties{},
					answer16 = #answer_properties{},
					answer17 = #answer_properties{},
					answer18 = #answer_properties{},
					answer19 = #answer_properties{},
					answer20 = #answer_properties{},
					answer21 = #answer_properties{},
					answer22 = #answer_properties{},
					answer23 = #answer_properties{},
					answer24 = #answer_properties{},
					answer25 = #answer_properties{},
					answer26 = #answer_properties{},
					answer27 = #answer_properties{},
					answer28 = #answer_properties{},
					answer29 = #answer_properties{},
					answer30 = #answer_properties{}					
				   }).

%% 用户进入农场信息
%% ets_manor_enter
%% Add By ZKJ
-record(ets_farm_info,{mid = 0,		%%主键，当前时间+pid+fid
						pid = 0,		%%玩家信息
                        fid = 0,		%%田地信息
						fstate = 0,		%%田地状态,0:原始状态，1：待开垦，2：已开垦（包括已经种植和未种植植物），3 ：需要元宝开垦，4 ： 需要铜币开垦
                        sgoodsid = 0,	%%种子类型
						sstate = 0,		%%种子的状态， 0：原始状态，1，播种状态，2，成长状态，3收获状态 
						plant = 0,		%%播种时间
						grow = 0,		%%成长时间
						fruit = 0,		%%剩余果实
						celerate = 0}).	%%已使用的加速器次数

%% 用户进入农场信息
%% ets_manor_enter
%% Add By ZKJ
-record(ets_manor_enter,{
					player_id = 0,				%%玩家ID
					target_player_id = 0,		%%农场玩家ID
					player_pid_send = 0			%%玩家ID的进程ID
					}).

%% 用户返回农场信息
%% ets_manor_enter
%% Add By ZKJ
-record(ets_farm_info_back,{
							fid = 0,
            				fstate = 0,
							sgoodsid = 0,
							sstate = 0,
							max_fruit = 0,
							remain_fruit = 0,
							remain_time = 0,
							player_lv = 0,
							gold_use = 0,
							fruit_id = 0,
							all_time = 0,
							steal_times = 0,
							res_id = 0			%%资源ID	
					}).

%% 用户偷菜信息
%% ets_manor_enter
%% Add By ZKJ
-record(ets_manor_steal,{
					steal_id = 0,		%%主键:时间戳+pid+fid
					player_id = 0,		%%玩家ID
					steal_time = 0,		%%发生的时间
					actions = 0, 		%%行为：1：收获，2：偷取，3：卖出，4：取出 5：被偷, 6：播种，7：使用加速器，9：开垦
					pid = 0,			%%偷取的对象ID
					nickname = 0,		%%玩家名
					fid = 0,			%%偷取的田地
					sgoodsid = 0,		%%偷取的物品
					count = 0,			%%偷取的数量
					read = 0			%%被偷取者是否已读取	1：未读取，2： 已读取								
					}).

%%每日在线奖励(非新手)
-record(ets_daily_online_award,{
	  pid,                                    %%玩家ID
	  gain_times,                             %%今天已获取次数
	  timestamp							      %%最后获取时间
	}).

%% 基础_场景怪物唯一信息
-record(ets_base_scene_unique_mon, {
	id = 0,
	mon = []									
}).


%% 基础_场景怪物唯一信息
-record(ets_exp_activity, {
	st = 0,
	et = 0
}).

%% 挂机设置
-record(hook_config, {
	skill = 0,											%% 自动使用技能
	skill_list = [0, 0, 0, 0, 0],						%% 技能列表
	coliseum_skill_list = [0, 0, 0, 0, 0],				%% 竞技场技能列表
	hook_num = 0,										%% 免费挂机次数
	equip_list = [1, 1, 1, 1],							%% 装备品质选项列表
	quality_list = [1, 1, 1, 1],						%% 品质选项列表
	pick = 1,											%% 自动捡取
	hp_pool = 0,										%% 自动使用气血包
	mp_pool = 0,										%% 自动使用法力包
	repair = 0,											%% 自动修理
	hp = 1,												%% 自动回血
	hp_val = 75,										%% 回血的值
	mp = 1,												%% 自动回蓝
	mp_val = 75,										%% 回蓝的值
	revive = 0,											%% 自动复活
	revive_style = 0,									%% 复活方式
	pet = 1,											%% 灵兽快乐值
	exp = 0,											%% 自动使用经验
	exp_style = 0,										%% 经验卷类型
	hp_list = 0,										%% 血药选项，0是从低到高，1是从高到底
	mp_list = 0	,										%% 蓝药选项，0是从低到高，1是从高到底
	task_mon_first = 1									%% 任务怪优先
}).

%%节日活动辅助信息表
-record(ets_holiday_info,{ 
	pid = 0,											%% 玩家id
	full_stren = 0,										%% 全身强化等级
	has_full_stren_info = 0								%% 数据表是否已经有全身强化信息											
}).

%%提亲信息表
-record(ets_propose_info,{
	boy_id,												%%男方Id
	girl_id												%%女方Id					
}).

%%进入婚宴的玩家表
-record(ets_wedding_player,{							
	player_id
						   }).
-record(ets_voters,{
					playerid
				   }).

%% 玩家数据
-record(player_state, {    
	player = #player{},									%% 玩家RECORD
	arena_revive = 0,   								%% 战场死亡复活次数
	arena_mark = 0,										%% 战场标记
	bless_times = 0,									%% 每日已用祝福次数
	last_bless_time = 0,								%% 上次祝福好友的时间
	dungeon_exp = 0,									%% 前3次进副本经验加成，1有，0否
	guild_carry_bc = 0,									%% 氏族运镖广播时间间隔
	online_time = 0,									%% 在线时间
	sex_change_time = 0,                                %% 上次改变性别的时间
	bottle_exp = 0,                                     %% 祝福瓶存储的经验
	bottle_spr = 0,					                    %% 祝福瓶存储的灵力
	quickbar = [],										%% 快捷键
	coliseum_time = 0,									%% 竞技场挑战时间
	coliseum_win = 0,									%% 竞技场连胜次数
	coliseum_cold_time = 0,								%% 竞技场挑战冷却时间
	coliseum_surplus_time = 0,							%% 竞技场剩余挑战次数
	coliseum_extra_time = 0,							%% 竞技场额外添加的挑战次数
	is_avatar = 0,										%% 竞技场是否使用替身
	coliseum_d_scene = 300,								%% 进入竞技场原来的场景
	coliseum_d_x = 64,									%% 进入竞技场原来的X坐标
	coliseum_d_y = 119,									%% 进入竞技场原来的Y坐标
	coliseum_rank = 0									%% 竞技场排行
}).

%% 攻城战 -- 氏族战功
-record(ets_castle_rush_guild_score, {
	guild_id = 0,										%% 氏族ID
	guild_name = [],									%% 氏族名
	guild_lv = 0,										%% 氏族等级
	member = [],										%% 参战成员
	score = 0,									  		%% 氏族战功
	hp = 0												%% 当前击杀BOSS血量
}).

%% 攻城战 -- 伤害积分
-record(ets_castle_rush_harm_score, {
	guild_id = 0,										%% 氏族ID
	guild_name = [],									%% 氏族名
	score = 0,									  		%% 伤害积分
	hp = 0												%% 当前击杀BOSS血量
}).

%% 攻城战 -- 个人战功
-record(ets_castle_rush_player_score, {
	player_id = 0,										%% 玩家ID
	nickname = [],										%% 玩家名
	guild_id = 0,										%% 氏族ID					
	career = 0,											%% 职业
	lv = 0,												%% 等级
	kill = 0,											%% 杀人数
	die = 0,											%% 死亡数
	guild_score = 0,									%% 氏族战功
	score = 0,											%% 个人战功
	hp = 0												%% 当前击杀BOSS血量
}).

%% 攻城战排行（1氏族排行，2个人排行）
-record(ets_castle_rush_rank, {
	id = 0,
	data = []							   
}).

%% 攻城战奖励成员
-record(ets_castle_rush_award_member, {
	guild_id = 0,
	data = []							   
}).

%% 竞技场数据(1、前20排名)
-record(ets_coliseum_data, {
	id = 0,
	data = []							   
}).

-record(raise_team,{
				   team_pid = 0,			%%队伍PID
				   player_id = 0,	%%队长id
				   nickname='',		%%队长名字
				   lv = 0,			%%等级
				   nums=0,			%%队员人数
				   type = 0,		%%类型1试炼2镇妖，3封神，4诛仙
				   auto = 0,		%%是否开启自动加入
				   msg_time = 0,	%%招募公告时间
				   timestamp=0		%%创建时间 
				  }).

-record(raise_member,{
					 pid = 0,			%%玩家id
					 nickname = '',		%%玩家名字
					 lv = 0,			%%玩家等级
					 career = 0 ,		%%玩家职业
					 type = 0,		%%类型1试炼2镇妖，3封神，4诛仙
					 timestamp=0 		%%等级时间
					 }).

%% 物品拍卖表	
%% sale_goods ==> ets_sale_goods 	
-record(ets_sale_goods, {	
      id,                                     %% 拍卖纪录ID	
	  unprice = 0,							  %% 商品单价
      sale_type = 1,                          %% 拍卖类型（1，实物；2，元宝或铜钱）	
      gid = 0,                                %% 物品ID，当ID为0时，表示拍卖的为元宝	
      goods_id = 0,                           %% 品物基本类型ID	
      goods_name = "",                        %% 物品名字	
      goods_type = 0,                         %% 物品类型当类型为0时，表示拍卖的为元宝,	
      goods_subtype = 0,                      %% 物品子类型当子类型为0时，表示拍卖的为元宝,	
      player_id = 0,                          %% 拍卖的玩家ID	
      player_name = "",                       %% 拍卖的玩家名字	
      num = 0,                                %% 货币（拍卖的物品是元宝或铜钱时，此值存在数值，不是元宝时，此值为该物品的数量）	
      career = 0,                             %% 职业,	
      goods_level = 0,                        %% 物品等级	
      goods_color = 99,                       %% 物品颜色，0 白色，1 绿色，2 蓝色，3 金色，4 紫色; 99 为不限 	
      price_type = 1,                         %% 拍卖价格类型：1铜钱，2元宝	
      price = 0,                              %% 拍卖价格	
      sale_time = 12,                         %% 拍卖时间：6小时，12小时，24小时	
      sale_start_time = 0,                    %% 拍卖开始时间	
      md5_key = ""                            %% 客户端发送的md5验证串	
    }).	

%% 市场求购数据表	
%% buy_goods ==> ets_buy_goods 	
-record(ets_buy_goods, {	
      id,                                     %% 求购Id(自增Id)	
	  price = 0,                              %% 求购的物品能给出的价格	      
      pid = 0,                                %% 玩家ID	
      pname = "",                             %% 玩家名字	
      buy_type = 0,                           %% 求购类型(1，实物；2，元宝或铜钱)	
      gid = 0,                                %% 求购的物品类型Id，当为元宝或者铜钱是，此值为0	
      gname = "",                             %% 求购的物品名字	
      gtype = 0,                              %% 求购的物品类型，当为元宝或者铜钱是，此值为0	
      gsubtype = 0,                           %% 求购的物品子类型，当为元宝或者铜钱是，此值为0	
      num = 0,                                %% 求购数量	
      career = 0,                             %% 求购 的物品职业类型	
      glv = 0,                                %% 求购的物品等级，由base_goods表中的level决定	
      gcolor = 99,                            %% 求购的物品颜色，0 白色，1 绿色，2 蓝色，3 金色，4 紫色; 99 为不限	
      gstren = 0,                             %% 求购物品要求的最小强化等级	
      gattr = 0,                              %% 求购的物品要求的对应的额外属性	
      unprice = 0,                            %% 求购的物品能给出的单价	
      price_type = 1,                         %% 求购的物品价格类型：1铜钱，2元宝	
      continue = 12,                          %% 求购的持续时间：6小时，12小时，24小时	
      buy_time = 0                            %% 求购信息发布的时间	
    }).

%%衣橱数据ets表
-record(ets_fashion_equip, {pid = 0,			%%玩家Id
							yfid = 0,			%%时装icon Id
							yftj = [],			%%已经激活的时装Ids
							fbid = 0,			%%法宝icon Id
							fbtj = [],			%%已经激活的法宝Ids
							gsid = 0,			%%挂饰icon Id
							gstj = []			%%已经激活的挂饰Ids
							}).

%%坐骑战斗属性
%%Hp,Mp,Att,Def,Hit,Dodge,Crit, level,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil
-record(ets_mount_battle, {
	 mount_id,
	 player_id,
	 hp = 0,
	 mp = 0,
	 atk = 0,
	 def = 0,
	 hit = 0,
	 dodge = 0,
	 crit = 0,
	 anti_wind = 0,
	 anti_fire = 0,
	 anti_water = 0,
	 anti_thunder = 0,
	 anti_soil = 0,	 
	 level = 1,
	 skills = [],  %%[{skillid,skilllv}]
	 val = 0,
	 speed
	}).

%%斗兽竞技奖励信息
-record(ets_mount_award,{
	 pid = 0,
	 mid = 0,
	 rank = 0}).