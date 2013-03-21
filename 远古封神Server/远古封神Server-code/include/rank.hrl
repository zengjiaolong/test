%% 排行

-define(NUM_LIMIT, 100).                        %% 排行榜名次限制

%% 人物属性排行榜相关
-define(ROLE_RANK_TYPE_ID, Realm * 1000 + Career * 100 + Sex * 10 + TypeNum). 	%% 排行榜类型编号规则
%% -define(ROLE_RANK_TYPE_ID, Realm * 100 + Career * 10 + TypeNum). 			%% 排行榜类型编号规则
-define(REALM_NUM_LIST,  [0, 1, 2, 3]).         %% 部落列表（0所有部落、100新手,1女娲族、2神农族、3伏羲族）
-define(CAREER_NUM_LIST, [0, 1, 2, 3, 4, 5]).   %% 职业列表（0所有职业、1玄武（战士）、2白虎（刺客）、3青龙（法师）、4朱雀（牧师）、5麒麟（武尊））
-define(SEX_LIST,  [0, 1, 2]).         			%% 性别列表（0所有性别、1男、2女）
-define(ROLE_RANK_TYPE_LIST, [                  %% 排行类别列表
	{1, lv},                                	%% 等级												
   	{2, coin_sum},                          	%% 财富（铜钱）
   	{3, honor},                             	%% 荣誉（仅氏族成员属性）
   	{4, culture}                           		%% 修为							 
]).

%% 装备评分排行榜相关
-define(EQUIP_RANK_TYPE_ID, 10000 + Type).      %% 装备排行榜类型编号规则
-define(EQUIP_RANK_TYPE_LIST, [1, 2]).       	%% 装备类型列表（1法宝，2防具）

%% 氏族
-define(GUILD_RANK_TYPE_ID, 20000 + TypeNum).   %% 氏族排行榜类型编号规则
-define(GUILD_RANK_TYPE_LIST, [{1, level}]).    %% 氏族排行类别列表
%% 氏族战排行
-define(GUILDBAT_RANK_TYPE_ID, 30000).   		%% 氏族战排行榜类型编号

-define(PET_RANK_TYPE_ID, 40000). 				%% 宠物
-define(LV_RANK_TYPE_ID, 50000).  				%% 等级
-define(COIN_SUM_RANK_TYPE_ID, 60000). 			%% 财富
-define(HONOR_RANK_TYPE_ID, 70000). 			%% 荣誉
-define(CULTURE_RANK_TYPE_ID, 80000). 			%% 修为
-define(CHARM_RANK_ID, 90000).					%% 魅力值排行
-define(ACHIEVE_RANK_ID, 100000).				%% 成就值排行

-define(BATT_RANK_TYPE_ID, 11000).                %%角色战斗力排行
-define(DEPUTY_EQUIP_RANK_TYPE_ID, 12000).     %%神器战力排行
-define(MOUNT_RANK_TYPE_ID, 13000).     %%坐骑战力排行

-define(WAR_BATT_RANK_TYPE_ID,14000). %%跨服战力排行
-define(INIT_SYS_ACM, 10*1000).    				%% 第一次系统公告播报延时，10秒（10 * 1000 单位：毫秒）


%% 封神台霸主排行
%% ets_fst_god
-define(ETS_FST_GOD, ets_fst_god).                        		

-record(ets_fst_god, {
	loc = 0,												%% 封神台层数
	nick = [],												%% 霸主
	thrutime = 0											%% 通关时间
}).


%% 镇妖台（单）排行
%% ets_td_s
-define(ETS_TD_S, ets_td_s).

-record(ets_td_s, {
	id = 0,
	uid = 0,												%% 玩家ID
	att_num = 0,											%% 波数
	g_name = [],											%% 帮派名
	nick = [],												%% 昵称
	career = 0,												%% 职业
	realm = 0,												%% 阵营
	hor_td = 0,												%% 镇妖功勋
	mgc_td = 0,												%% 剩余魔力值
	vip = 0													%% 是否VIP
}).

-define(ETS_TD_S_ALL,ets_td_s_all).%%单人镇妖竞技榜
-record(ets_td_s_all, {
	id = 0,
	uid = 0,												%% 玩家ID
	att_num = 0,											%% 波数
	g_name = [],											%% 帮派名
	nick = [],												%% 昵称
	career = 0,												%% 职业
	realm = 0,												%% 阵营
	hor_td = 0,												%% 镇妖功勋
	mgc_td = 0,												%% 剩余魔力值
	vip = 0,													%% 是否VIP
	lv = 0													%%等级
}).
%% 镇妖台（多）排行
%% ets_td_m
-define(ETS_TD_M, ets_td_m).

-record(ets_td_m, {
	id = 0,													%% ID号
	hor_td = 0,												%% 镇妖功勋
	att_num = 0,											%% 波数
	mgc_td = 0,												%% 剩余魔力值
	nick = []												%% 昵称
}).

%% 诛仙台霸主排行
%% ets_zxt_god
-define(ETS_ZXT_GOD, ets_zxt_god).                        		

-record(ets_zxt_god, {
	loc = 0,												%% 诛仙台层数
	nick = [],												%% 霸主
	thrutime = 0											%% 通关时间
}).
