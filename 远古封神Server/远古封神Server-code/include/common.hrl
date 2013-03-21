%%%------------------------------------------------
%%% File    : common.hrl
%%% Author  : ygzj
%%% Created : 2010-09-15
%%% Description: 公共定义
%%%------------------------------------------------

-define(ALL_SERVER_PLAYERS, 10000).

%%数据库模块选择 (db_mysql 或 db_mongo)
-define(DB_MODULE, db_mongo).			

%%mongo主数据库链接池
-define(MASTER_POOLID,master_mongo).

%%mongo主数据库链接池
-define(LOG_POOLID,log_mongo).

%%mongo从数据库链接池
-define(SLAVE_POOLID,slave_mongo).

%%Mysql数据库连接 
-define(DB_POOL, mysql_conn). 

%% 每个场景的工作进程数
-define(SCENE_WORKER_NUMBER, 150).

%% 氏族进程的工作进程数
-define(GUILD_WORKER_NUMBER, 100).

%% 师徒关系的工作进程数
-define(MASTAR_APPRENTICE_WORKER_NUMBER, 50).

%% 延时信息器的工作进程数
-define(DELAYER_WORKER_NUMBER,50).

%%安全校验
-define(TICKET, "SDFSDESF123DFSDF"). 

%%flash843安全沙箱
-define(FL_POLICY_REQ, <<"<polic">>).
-define(FL_POLICY_FILE, <<"<cross-domain-policy><allow-access-from domain='*' to-ports='*' /></cross-domain-policy>">>).

%%tcp_server监听参数
-define(TCP_OPTIONS, [binary, {packet, 0}, {active, false}, {reuseaddr, true}, {nodelay, false}, {delay_send, true}, {send_timeout, 5000}, {keepalive, true}, {exit_on_close, true}]).
-define(RECV_TIMEOUT, 5000).

%%ets read-write 属性
-define(ETSRC,{read_concurrency,true}).
-define(ETSWC,{write_concurrency,true}).

%% 心跳包时间间隔
-define(HEARTBEAT_TICKET_TIME, 24*1000).	%%seconds
%% 最大心跳包检测失败次数
-define(HEARTBEAT_MAX_FAIL_TIME, 3).
%%出师等级限制 
-define(FINISHED_MASTER_LV,40).
%%徒弟未汇报时间
-define(UNREPORT_DAYS,3).
%%师傅未登陆时间
-define(UNLOGIN_DAYS,3).

%%自然对数的底
-define(E, 2.718281828459).

%%用户进入农场信息
-define(ETS_MANOR_ENTER, ets_manor_enter).  
%%田地信息
-define(ETS_FARM_INFO, ets_form_info). 
 %%偷菜信息
-define(ETS_MANOR_STEAL, ets_manor_steal).

%% ---------------------------------
%% Logging mechanism
%% Print in standard output
-define(PRINT(Format, Args),
    io:format(Format, Args)).
-define(TEST_MSG(Format, Args),
    logger:test_msg(?MODULE,?LINE,Format, Args)).
-define(DEBUG(Format, Args),
    logger:debug_msg(?MODULE,?LINE,Format, Args)).
-define(INFO_MSG(Format, Args),
    logger:info_msg(?MODULE,?LINE,Format, Args)).
-define(WARNING_MSG(Format, Args),
    logger:warning_msg(?MODULE,?LINE,Format, Args)).
-define(ERROR_MSG(Format, Args),
    logger:error_msg(?MODULE,?LINE,Format, Args)).
-define(CRITICAL_MSG(Format, Args),
    logger:critical_msg(?MODULE,?LINE,Format, Args)).

%% ===========一些特殊处理相关参数的定义=======
%% 新手村场景ID
-define(NEW_PLAYER_SCENE_ID, 100).
-define(NEW_PLAYER_SCENE_ID_TWO, 110).
-define(NEW_PLAYER_SCENE_ID_THREE, 111).
-define(FREE_PK_SCENE_ID, 119).
-define(HOMECITY_NW,200).%%女娲主城
-define(SUBURBS_NW,201).%%女娲城郊
-define(HOMECITY_FX,250).%%伏羲主城
-define(SUBURBS_FX,251).%%伏羲城郊
-define(HOMECITY_SN,280).%%神农主城
-define(SUBURBS_SN,281).%%神农城郊
-define(LEIZE,101).%%雷泽
-define(LEIZE2,190).%%雷泽
-define(LEIZE3,191).%%雷泽
%%打开发送消息客户端进程数量  修改固定数值为2,与程序算法关联，勿改。
-define(SEND_MSG, 2).

-define(DIFF_SECONDS_1970_1900, 2208988800).
-define(DIFF_SECONDS_0000_1900, 62167219200).
-define(ONE_DAY_SECONDS, 86400).					%%一天的时间（秒）
-define(ONE_DAY_MILLISECONDS, 86400000).				%%一天时间（毫秒）

%%ETS
-define(ETS_SERVER, ets_server).
-define(ETS_GET_SERVER,ets_get_server).
-define(ETS_SYSTEM_INFO,  ets_system_info).						%% 系统配置信息
-define(ETS_MONITOR_PID,  ets_monitor_pid).						%% 记录监控的PID
-define(ETS_STAT_SOCKET, ets_stat_socket).						%% Socket送出数据统计(协议号，次数)
-define(ETS_STAT_DB, ets_stat_db).								%% 数据库访问统计(表名，操作，次数)

-define(ETS_BASE_MON, ets_base_mon).							%% 基础_怪物信息
-define(ETS_BASE_NPC, ets_base_npc).							%% 基础_NPC信息

-define(ETS_BASE_SCENE, ets_base_scene).						%% 基础_场景信息
-define(ETS_BASE_SCENE_POSES, ets_base_scene_poses).			%% 基本_场景坐标表
-define(ETS_BASE_SCENE_MON, ets_base_scene_mon).				%% 基础_场景怪物信息
-define(ETS_BASE_SCENE_UNIQUE_MON, ets_base_scene_unique_mon).	%% 基础_场景怪物唯一信息
-define(ETS_BASE_SCENE_NPC, ets_base_scene_npc).				%% 基础_场景NPC信息
-define(ETS_BASE_DUNGEON, ets_base_dungeon).					%% 基础_副本信息

-define(ETS_SCENE, ets_scene).									%% 本节点场景
-define(ETS_SCENE_MON, ets_mon).								%% 本节点场景中怪物
-define(ETS_SCENE_NPC, ets_npc).								%% 本节点场景中NPC
-define(ETS_ONLINE, ets_online).								%% 本节点在线玩家
-define(ETS_ONLINE_SCENE, ets_online_scene).					%% 本节点场景中玩家
-define(ETS_BLACKLIST,ets_blacklist).							%% 黑名单记录表

-define(ETS_BASE_CAREER, ets_base_career).                        			%% 基础职业属性
-define(ETS_BASE_GOODS, ets_base_goods).                        			%% 物品类型表
-define(ETS_BASE_GOODS_ADD_ATTRIBUTE, ets_base_goods_add_attribute).      	%% 装备类型附加属性表
-define(ETS_BASE_GOODS_SUIT_ATTRIBUTE, ets_base_goods_suit_attribute).    	%% 装备套装属性表
-define(ETS_BASE_GOODS_SUIT,ets_base_goods_suit).							%% 装备套装基础表 
-define(ETS_BASE_GOODS_STRENGTHEN, ets_base_goods_strengthen).            	%% 装备强化规则表
-define(ETS_BASE_GOODS_STRENGTHEN_ANTI,ets_base_goods_strengthen_anti).     %% 防具强化抗性规则表
-define(ETS_BASE_GOODS_STRENGTHEN_EXTRA,ets_base_goods_strengthen_extra).   %% 装备强化额外规则表
-define(ETS_BASE_GOODS_PRACTISE,ets_base_goods_practise).                   %% 法宝修炼规则表
-define(ETS_BASE_GOODS_COMPOSE, ets_base_goods_compose).                  	%% 宝石合成规则表
-define(ETS_BASE_GOODS_INLAY, ets_base_goods_inlay).                      	%% 宝石镶嵌规则表
-define(ETS_BASE_GOODS_DROP_NUM, ets_base_goods_drop_num).                	%% 物品掉落个数规则表
-define(ETS_BASE_GOODS_DROP_RULE, ets_base_goods_drop_rule).              	%% 物品掉落规则表
-define(ETS_BASE_GOODS_IDECOMPOSE,ets_base_goods_idecompose).				%% 装备分解规则表
-define(ETS_BASE_GOODS_ICOMPOSE,ets_base_goods_icompose).					%% 材料合成规则表
-define(ETS_BASE_GOODS_ORE,ets_base_goods_ore).
-define(ETS_BASE_SHOP, ets_shop).                                    		%% 商店表
-define(ETS_BASE_TALK, ets_base_talk).                        				%% 基础对话
-define(ETS_BASE_TASK, ets_base_task).                        				%% 基础任务
-define(ETS_BASE_SKILL, ets_base_skill).                        			%% 基础技能
-define(ETS_BASE_GOODS_FASHION, ets_base_goods_fashion).           %%时装洗炼属性表
-define(ETS_DEPUTY_EQUIP,ets_deputy_equip).							%%副法宝数据表
-define(ETS_GOODS_ONLINE, ets_goods_online).                    %% 在线玩家的背包物品表
-define(ETS_GOODS_ATTRIBUTE, ets_goods_attribute).              %% 在线玩家的物品属性表
-define(ETS_GOODS_DROP, ets_goods_drop).                        %% 物品掉落表
-define(ETS_GOODS_CD ,ets_goods_cd).							%% 物品cd时间表

-define(ETS_ROLE_TASK, ets_role_task). 							%% 角色任务记录
-define(ETS_ROLE_TASK_LOG, ets_role_task_log).					%% 角色任务历史记录
-define(ETS_TASK_QUERY_CACHE, ets_task_query_cache).            %% 当前所有可接任务

-define(ETS_RELA, ets_rela).                                    %% 玩家关系表
-define(ETS_DELAYER, ets_delayer).                              %% 信息延时器列表
-define(ETS_BLACKBOARD, ets_blackboard).						%% 组队小黑板	

-define(ETS_PET,          ets_pet).                             %% 宠物
-define(ETS_BASE_PET,     ets_base_pet).                        %% 宠物道具配置
-define(ETS_PET_BUY, ets_pet_buy).                            %%灵兽购买
-define(ETS_PET_SPLIT_SKILL, ets_pet_split_skill).             %%灵兽分离技能     
-define(ETS_BASE_PET_SKILL_EFFECT,ets_base_pet_skill_effect). %%灵兽技能效果表

-define(ETS_HOLIDAY_INFO,	  ets_holiday_info).					%% 节日活动辅助信息表
-define(ETS_FS_ERA,ets_fs_era). 								%%封神纪元信息记录表


-define(ETS_RANK, ets_rank).                                    %% 排行榜

-define(ETS_BASE_MERIDIAN, ets_base_meridian).                   %% 经脉基础属性
-define(ETS_MERIDIAN, ets_meridian).                             %% 玩家经脉属性

-define(ETS_SALE_GOODS, ets_sale_goods).						%% 交易市场表
-define(ETS_SALE_GOODS_ONLINE, ets_sale_goods_online).			%%交易物品信息表
-define(ETS_SALE_GOODS_ATTRIBUTE, ets_sale_goods_attribute).	%%交易物品额外属性表
-define(ETS_BUY_GOODS, ets_buy_goods).							%%市场求购数据表

-define(ETS_ONLINE_GIFT,ets_online_gift).						%%在线奖励 
-define(ETS_BASE_ONLINE_GIFT,ets_base_online_gift).               %%在线奖励物品
-define(ETS_CARRY_TIME,ets_carry_time).                           %%国运时间
-define(ETS_BASE_MAP,ets_base_map).								%%场景分类管理
-define(ETS_TASK_CACHE,ets_task_cache).                      %%玩家任务缓存

-define(ETS_BASE_BOX_GOODS_ONE, ets_base_box_goods_one).						%%记录诛邪系统物品信息ONE
-define(ETS_BASE_BOX_GOODS_TWO, ets_base_box_goods_two).						%%记录诛邪系统物品信息TWO
-define(ETS_LOG_BOX_OPEN, ets_log_box_open).									%%记录诛邪系统玩家诛邪后得到的高级装配信息日志
%% -define(ETS_OPEN_BOXGOODS_PRO, ets_open_boxgoods_pro).						    %%用于额外存储特殊情况的诛邪物品概率
-define(BOX_GOODS_STORAGE, 750).												%%诛邪系统仓库容量
-define(ETS_BOX_SCENE, ets_box_scene).											%%记录玩家进入的诛邪副本场景数据
-define(BOX_SCENE_BASE_ID, 10000).												%诛邪副本场景的转换基数ID
-define(BOX_SCENE_ID, 700).														%%诛邪副本的原始场景ID
-define(BOX_SCENE_ONE_ID, 710).													%%诛邪副本的入口场景ID 
-define(BOXS_PIECE_ID, 720).													%%新秘境的副本ID
-define(BOX_SCENE_ENTER_TIMES, 15).												%%秘境令使用的次数限制

-define(DUNGEON_SINGLE_SCENE_ID,909).											%% 单人副本场景ID

-define(ETS_MASTER_APPRENTICE, ets_master_apprentice).			%% 师徒关系表
-define(ETS_MASTER_CHARTS, ets_master_charts).			        %% 伯乐表

-define(ADVANCED_REVIVE_COST, 5).								%% 高级稻草人复活消耗金币数
-define(REVIVE_COST, 2).										%% 稻草人复活消耗金币数

-define(EXIT_BATTLE_INTERVAL, 5000).							%% 脱离战斗状态的时间间隔

-define(ETS_REALM,ets_realm).									%% 阵营玩家人数统计

-define(MON_LIMIT_NUM, 100000000).								%% 怪物数量限制数

%%	1*60*60*1000ms = 1h
-define(TIMESTAMP, 2*60*60*1000).								%%诛邪物品的自动检查更新时间
%%-define(TIMESTAMP, 20*1000).		%%测试用							
-define(TIMESTAMPLOG, 2*60*60*1000).							%%全服的诛邪日志检查更新时间
%%-define(TIMESTAMPLOG, 30*1000).		%%测试用							
-define(LIMIT_PURPLE_EQUIT_TIME, 20).							%%玩家刷出紫装后不能在出现紫装的时间限制(以秒为单位)

-define(ETS_BASE_TARGET_GIFT,ets_base_target_gift).              %%目标奖励基础表
-define(ETS_TARGET_GIFT,ets_target_gift).                        %%玩家领取目标奖励表

-define(TEAM_X_RANGE, 14).								        %% 队伍效用范围的X范围
-define(TEAM_Y_RANGE, 14).								        %% 队伍效用范围的Y范围


-define(BATTLE_LEVEL, 24).										%% 战斗等级限制

-define(ETS_TASK_CONSIGN, ets_task_consign).                    %%委托任务


-define(ORE_START_TIME,15 * 3600).					%%天降彩石开始时间 15 * 3600
-define(ORE_END_TIME,?ORE_START_TIME + 1800).					%%天降彩石结束时间
-define(ORE_AREA,2).											%%采石点误差范围
-define(ORE_NUM,10).											%%采石点数量
-define(ORE_NUM_LIMIT,15).										%%采石点上限限制（需小于采石点数量）
-define(ORE_GOODS_LIMIT,30).									%%采出矿石数量限制
-define(ORE_RATIO_35_DOWN,60).									%%35级以下采矿成功率
-define(ORE_RATIO_35_UP,80).									%%35级以上采矿成功率
-define(ORE_LEVEL_LIMIT,30).									%%采矿等级限制

-define(ETS_CONSIGN_TASK,ets_consign_task). %%玩家委托任务
-define(ETS_CONSIGN_PLAYER,ets_consign_player).%%委托任务玩家表
-define(ETS_CARRY,ets_carry). %%玩家运接镖表

-define(CARRY_BC_START_CHANGE, 71400).								%% 国运时间切换19*3600+50*60
-define(CARRY_BC_START_THREE, 72120).								%% 国运前三分钟广播20*3600+2*60
-define(CARRY_BC_START_ONE, 72240).									%% 国运前一分钟广播20*3600+4*60
-define(CARRY_BC_START, 72300).										%% 国运开始时间20*3600 + 5*60
-define(CARRY_BC_END_THREE, 73620).									%% 国运结束前三分钟广播20*3600+27*60
-define(CARRY_BC_END_ONE, 73740).									%% 国运结束前1分钟广播20*3600+29*60
-define(CARRY_BC_END, 73800).										%% 国运结束时间20*3600+30*60
-define(CARRY_BC_END_CHANGE, 74100).								%% 国运结束检查时间20*3600+35*60

-define(BUSINESS_DOUBLE_START_CHANGE, 51480).  						%% 跑商时间切换开始 14 * 3600 + 18 * 60 
-define(BUSINESS_DOUBLE_END_CHANGE, 53820).    						%% 跑商时间切换结束 14 * 3600 + 57 * 60
-define(BUSINESS_DOUBLE_START_TIME, 51900).     					%% 跑商双倍奖励开启时间 14 * 3600 + 25 * 60 
-define(BUSINESS_DOUBLE_BROAD_TIME, 51720).      					%% 跑商双倍奖励广播开始时间 14 * 3600 + 22 * 60
-define(BUSINESS_DOUBLE_END_TIME, 53700).         					%% 跑商双倍奖励结束时间 14 * 3600 + 55 * 60
-define(BUSINESS_DOUBLE_DAY, 7).       								%% 跑商双倍奖励开启的日期

-define(GOODSTYPE,[{4,28406},{5,28407},{6,28408},{7,28409}]).

-define(ETS_BASE_ANSWER,ets_base_answer).%%答题题库ETS
-define(ETS_ANSWER,ets_answer).%%答题ETS

-define(ETS_OFFLINE_AWARD,ets_offline_award). %%离线经验累积奖励
-define(ETS_ONLINE_AWARD,ets_online_award). %%连续在线累积奖励

-define(Goods_Expire_Time, 120).								%% 掉落物品存在时间
-define(PEACH_ADD_EXP_SPIRIT_STAMPTIME, 5000).					%%吃蟠桃增加经验和灵力的时间戳
-define(PEACH_NUM_LIMIT, 4).									%%一天吃蟠桃的数量限制
-define(AUTO_SIT_ADD_EXP_STAMPTIME, 20000).						%%自动加经验的事件监测间隔时间戳(20秒)

-define(ETS_VIP_MAIL,ets_vip_mail).                             %%vip邮件发送日志
-define(ETS_TITLE_MAIL,ets_title_mail).							%%称号邮件发送日志

-define(ETS_BUSINESS,ets_business). %%跑商
-define(ETS_BASE_BUSINESS,ets_base_business).  %%跑商奖励基础表
-define(ETS_SAME_CAR,ets_same_car). %%劫同一商车
-define(ETS_LOG_ROBBED,ets_log_robbed).%%劫商日志

-define(ETS_ONLINE_AWARD_HOLIDAY,ets_online_award_holiday).%%节日登陆奖励表（五一）

-define(HOLIDAY_GOODS_ID_EVERY_DAY,21201).%%假日每天登陆奖励物品id
-define(HOLIDAY_GOODS_NUM_EVERY_DAY,1).%%假日每天登陆奖励物品数量
-define(HOLIDAY_GOODS_ID_CON_DAY,20303).%%假日连续登陆奖励物品id
-define(HOLIDAY_GOODS_NUM_CON_DAY,3).%%假日连续登陆奖励物品数量

-define(ETS_HERO_CARD,ets_hero_card). %%英雄帖
-define(ETS_BASE_HERO_CARD,ets_base_hero_card).%%英雄帖奖励表

-define(ETS_LOVE,ets_love).%%仙侣情缘
-define(LOVE_SCENE,214). %%天涯海角场景id

-define(PLAYER_SPEED, 170). 				%%玩家速度

-define(ETS_BASE_PRIVITY,ets_base_privity).%%默契度测试题库

-define(HEROCARD_NUM_LIMIT,3).%%封神贴使用次数

-define(ETS_LUCKYDRAW,ets_luckydraw). %%登陆抽奖
-define(ETS_TARGETLEAD,ets_targetlead).%%目标引导

-define(ETS_LOGIN_AWARD,ets_login_award). %%新登录奖励


-define(ETS_DUNGEON,ets_dungeon). %%副本信息

-define(ETS_BASE_DAILY_GIFT,ets_base_daily_gift). %%每日在线奖励物品表
-define(ETS_DAILY_ONLINE_AWARD,ets_daily_online_award). %%领奖信息表
-define(DAILY_AWARD_TIME_INTERVAL,[{0,1*60},{1,5*60},{2,10*60},{3,30*60},{4,60*60}]).%%领取奖励物品的时间间隔
-define(DAILY_AWARD_MAX_TIMES, 5).%%每天领取次数上线

-define(BOSSID,[42001, 42003, 42005, 42007, 42009, 42011, 42013, 42015, 42017, 42019, 42021 ,42023, 42025, 42027, 42029, 42031, 42033, 42035, 42037, 42039, 42041]).%%需要显示倒计时的BOSS

-define(ETS_EXP_ACTIVITY, ets_exp_activity).		%% 双倍经验活动

-define(ETS_TOWER_AWARD,ets_tower_award).  %%塔奖励基础表
-define(BUFF_AND_SITADDEXP_TIMESTAMP, 20*1000).	%%buff和自动打坐加经验 时间戳(20秒)
-define(ETS_BASE_MAGIC,ets_base_magic).  %%基础附魔属性

-define(ETS_CYCLE_FLUSH,ets_cycle_flush).%%循环任务奖励倍数

-define(ETS_WAR_PLAYER,ets_war_player). %%跨服竞技玩家表
-define(ETS_WAR_TEAM,ets_war_team).%%跨服竞技队伍表
-define(ETS_WAR_VS,ets_war_vs).%%跨服竞技对战表

-define(ETS_APPRAISE,ets_appraise).%%玩家评价表
-define(ADORE_TWICE,10).%%玩家每天允许评价次数

-define(HOLIDAY_BEG_TIME, 1319155200).%%节日活动开始时间 1319155200 国庆开始
-define(HOLIDAY_END_TIME, 1319472000).%%节日活动结束时间 1319472000 国庆结束
-define(HOLIDAY_ACTIVITY_NEED,180). %%节日活动 活跃度需求值
-define(HOLIDAY_HOT_FANS_TIME,43200). %%中午12点触发 43200

%%挂机区开放开始时间
-define(HOOKING_OPEN,17*3600+30*60).
%%挂机区开放结束时间
-define(HOOKING_CLOSE,23*3600+0*60). 

%% -define(WAR_SIGN_UP_OPEN,22*3600+05*60).%%跨服开放报名/初始化服务器分组
%% -define(WAR_SIGN_UP_CLOSE,22*3600+10*60).%%跨服结束报名
%% -define(INIT_WAR_TEAM_TIME,22*3600+12*60).%%初始化参赛队伍玩家信息时间
%% -define(WAR_ENTER_OPEN,22*3600+15*60).%%跨服开放进入
-define(WAR_SIGN_UP_OPEN,14*3600+0*60).%%跨服开放报名/初始化服务器分组
-define(WAR_SIGN_UP_CLOSE,15*3600+0*60).%%跨服结束报名
-define(INIT_WAR_TEAM_TIME,15*3600+5*60).%%初始化参赛队伍玩家信息时间
-define(WAR_ENTER_OPEN,15*3600+30*60).%%跨服开放进入

-define(ETS_VIP,ets_vip).%%VIP功能表

-define(ETS_NOVICE_GIFT,ets_novice_gift).%%新手礼包
-define(ETS_PET_EXTRA,ets_pet_extra).%%灵兽额外信息表
-define(ETS_PET_EXTRA_VALUE,ets_pet_extra_value).%%灵兽额外信息日志表

-define(HOLIDAY_START,1320969600). %%11月11号8点
-define(HOLIDAY_END,1321027200). %%11月12号零点
%% -define(HOLIDAY_START,1320945316).%%测试时间
%% -define(HOLIDAY_END,1321027200). %%测试时间

-define(CAVE_RES_SCENE_ID, 961).										%% 天回阵副本的资源ID

-define(CASTLE_RUSH_SCENE_ID, 800).										%% 九霄攻城战场景ID
-define(ETS_CASTLE_RUSH_INFO, ets_castle_rush_info).					%% 攻城战数据
-define(ETS_CASTLE_RUSH_JOIN, ets_castle_rush_join).					%% 攻城战氏族报名数据
-define(ETS_CASTLE_RUSH_RANK, ets_castle_rush_rank).					%% 攻城战排行
-define(ETS_CASTLE_RUSH_GUILD_SCORE, ets_castle_rush_guild_score).		%% 攻城战 -- 氏族战功
-define(ETS_CASTLE_RUSH_HARM_SCORE, ets_castle_rush_harm_score).		%% 攻城战 -- 伤害积分
-define(ETS_CASTLE_RUSH_PLAYER_SCORE, ets_castle_rush_player_score).	%% 攻城战 -- 个人战功
-define(ETS_CASTLE_RUSH_AWARD_MEMBER, ets_castle_rush_award_member).	%% 攻城战奖励成员

-define(ETS_WAR_AWARD,ets_war_award).%%跨服战场玩家积分奖励表

-define(ETS_WEDDING,ets_wedding).    %%婚宴
-define(ETS_MARRY,ets_marry).        %%结婚
-define(MARRY_COST,518720).          %%结婚成功费用
-define(ETS_PROPOSE_INFO,ets_propose_info). %%提亲信息表
-define(WEDDING_INTERVAL,10000).           %%检测的间隔时间10分钟(毫秒)
-define(WEDDING_SCENE_ID,215).       %%婚宴场景ID
-define(WEDDING_LOVE_SCENE_ID,216).   %%结婚洞房场景
-define(WEDDING_TIMEMER_DELAY,900).  %%提前15分钟启动检测时间(秒)
-define(WEDDING_BROACAST_1,180).     %%婚宴开始前3分钟公告
-define(WEDDING_BROACAST_2,60).      %%婚宴开始前1分钟公告
-define(WEDDING_TIMER, 3000).		 %%婚宴定时器
-define(WEDDING_PLAYER,ets_wedding_player).
-define(WEDDING_TIME,[{1,32400,34200},{2,36000,37800},{3,39600,41400},{4,43200,45000},{5,46800,48600},{6,50400,52200},{7,54000,55800},{8,57600,59400},{9,61200,63000},{10,64800,66600},{11,68400,70200},{12,72000,73800},{13,75600,77400},{14,79200,81000},{15,82800,84600}]).%%9点——23点
-define(ETS_LOVEDAY,ets_loveday).%%情人节活动，表白表
-define(ETS_VOTERS,ets_voters).%%情人节活动，投票表

-define(ETS_MOUNT,ets_mount).         %%坐骑
-define(ETS_MOUNT_SKILL_EXP,ets_mount_skill_exp).         %%坐骑技能经验槽
-define(ETS_MOUNT_SKILL_SPLIT,ets_mount_skill_split).         %%坐骑技能精魂
-define(ETS_MOUNT_ARENA, ets_mount_arena).
-define(ETS_MOUNT_BATTLE,ets_mount_battle).
-define(ETS_BATTLE_RESULT, ets_battle_result).
-define(ETS_MOUNT_RECENT,ets_mount_recent).
-define(MAX_CGE_TIMES,10). %%每日斗兽最大挑战数
-define(MAX_MOUNT_NUM,500).   %%竞技榜最大斗兽数量
-define(ETS_MOUNT_AWARD,ets_mount_award).%%斗兽奖励竞技奖励表
-define(ETS_LOG_AWARD,ets_log_award).   %%斗兽领取奖励日志表
-define(ETS_FIND_EXP,ets_find_exp).		%%经验找回
-define(TaskRB,[20361,20219,20201,61008,61012,61013,61014,61038,61039,80000,81000,81001,81002,81003,81004,81005,73000,73001,73002,73003,73004,73005,84010]).%%需要立即回写的任务
-define(ETS_SINGLE_TD_AWARD,ets_single_td_award).%%单人镇妖竞技奖励表

-define(ARENA_RES_SCENE_ID, 600).			                      			%% 战场资源ID
-define(NEW_ARENA_RES_SCENE_ID, 650).			                      		%% 新战场资源ID
-define(ETS_ARENA, ets_arena).			                      				%% 战场排行榜
-define(ETS_ARENA_WEEK, ets_arena_week).			          				%% 战场周排行榜

-define(ETS_COLISEUM_RANK, ets_coliseum_rank).							%% 竞技场排行
-define(ETS_WAR2_RECORD,ets_war2_record).%%跨服单人竞技记录
-define(ETS_WAR2_ELIMINATION,ets_war2_elimination).%%跨服单人淘汰赛记录
-define(ETS_WAR2_HISTORY,ets_war2_history).%%跨服单人竞技历史记录
-define(ETS_WAR2_BET,ets_war2_bet).%%跨服下注
-define(ETS_COLISEUM_INFO, ets_coliseum_info).								%% 竞技场信息
-define(COLISEUM_RES_SCENE_ID, 970).			                      		%% 竞技场资源ID
-define(ETS_COLISEUM_DATA, ets_coliseum_data).								%% 竞技场数据

-define(ETS_WAR2_PAPE,ets_war2_pape).%%跨服战报
-define(ETS_FASHION_EQUIP, ets_fashion_equip).		%%衣橱数据ets表
-define(APPOINT_TASK_ID, 84020).		%%点名任务id
-define(ETS_TARGET,ets_target).%%新目标