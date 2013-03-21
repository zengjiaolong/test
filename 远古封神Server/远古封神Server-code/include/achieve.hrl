-define(UPDATE_ACH_STATISTICS_TIMESTAMP, 300000).			%%玩家成就信息保存数据库的时间戳
-define(UPDATE_NUM, 10000).																			%%需要更新
-define(ACH_TASK_INIT, [0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 
						0,0,0,0,0,0,0,0]).									%%任务成就
-define(ACH_TASK_LENGTH, 28).																			%%长度
-define(ACH_TASK_FIELDS, [pid,t1,t2,t3,t4,t5,t6,t7,t8,t9,t10,
						  t11,t12,t13,t14,t15,t16,t17,t18,t19,t20,
						  t21,t22,t23,t24,t25,t26,t27,tf]).
-define(ACH_EPIC_INIT, [0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 
						0,0,0,0,0,0,0,0]).						%%神装成就
-define(ACH_EPIC_LENGTH, 28).																			%%长度	
-define(ACH_EPIC_FIELDS, [pid,e1,e2,e3,e4,e5,e6,e7,e8,e9,e10,
						  e11,e12,e13,e14,e15,e16,e17,e18,e19,e20,
						  e21,e22,e23,e24,e25,e26,e27,ef]). 
-define(ACH_TRIALS_INIT, [0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 
						  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 
						  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
						  0,0,0,0]).	%%试炼成就
-define(ACH_TRIALS_LENGTH, 64).																			%%长度
-define(ACH_TRIALS_FIELDS, [pid,tr1,tr2,tr3,tr4,tr5,tr6,tr7,tr8,tr9,tr10,
							tr11,tr12,tr13,tr14,tr15,tr16,tr17,tr18,tr19,tr20,
							tr21,tr22,tr23,tr24,tr25,tr26,tr27,tr28,tr29,tr30,
							tr31,tr32,tr33,tr34,tr35,tr36,tr37,tr38,tr39,tr40,
							tr41,tr42,tr43,tr44,tr45,tr46,tr47,tr48,tr49,tr50,
							tr51,tr52,tr53,tr54,tr55,tr56,tr57,tr58,tr59,tr60,
							tr61,tr62,tr63,trf]).
-define(ACH_YG_INIT, [0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 
					  0,0,0,0,0,0]).							%%远古成就
-define(ACH_YG_LENGTH, 26).																				%%长度
-define(ACH_YG_FIELDS, [pid,y1,y2,y3,y4,y5,y6,y7,y8,y9,y10,
						y11,y12,y13,y14,y15,y16,y17,y18,y19,y20,
						y21,y22,y23,y24,y25,yf]).
-define(ACH_FS_INIT, [0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
					  0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
					  0,0,0,0,0,0,0,0,0,0, 0]).								%%封神成就
-define(ACH_FS_LENGTH, 51).																				%%长度
-define(ACH_FS_FIELDS, [pid,f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,
						f11,f12,f13,f14,f15,f16,f17,f18,f19,f20,
						f21,f22,f23,f24,f25,f26,f27,f28,f29,f30,
						f31,f32,f33,f34,f35,f36,f37,f38,f39,f40,
						f41,f42,f43,f44,f45,f46,f47,f48,f49,f50,
						ff]).
-define(ACH_INTERACT_INIT, [0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,
							0,0,0,0,0,0,0,0,0,0, 0,0,0]).					%%互动成就
-define(ACH_INTERACT_LENGTH, 33).																		%%长度
-define(ACH_INTERACT_FIELDS, [pid,in1,in2,in3,in4,in5,in6,in7,in8,in9,in10,
							  in11,in12,in13,in14,in15,in16,in17,in18,in19,in20,
							  in21,in22,in23,in24,in25,in26,in27,in28,in29,in30,
							  in31,in32,inf]).
-define(ACH_TREASURE_INIT, [0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0, 
							0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0]).			%%奇珍异宝
-define(ACH_TREASURE_LENGTH, 36).																	%%长度
-define(ACH_TREASURE_FIELDS, [pid,ach,ts1,ts2,ts3,ts4,ts5,ts6,ts7,ts8,ts9,ts10,
							  ts11,ts12,ts13,ts14,ts15,ts16,ts17,ts18,ts19,ts20,
							  ts21,ts22,ts23,ts24,ts25,ts26,ts27,ts28,ts101,ts102,
							  ts103,ts104,ts105,ts106,ts107,ts108]).

-define(ETS_ACHIEVE, ets_achieve).																%%成就系统数据ets
-record(ets_achieve, {
					  pid = 0,								%%玩家Id
					  ach_task = ?ACH_TASK_INIT,			%%任务成就
					  ach_epic = ?ACH_EPIC_INIT,			%%神装成就
					  ach_trials = ?ACH_TRIALS_INIT,		%%试炼成就
					  ach_yg = ?ACH_YG_INIT,				%%远古成就
					  ach_fs = ?ACH_FS_INIT,				%%封神成就
					  ach_interact = ?ACH_INTERACT_INIT,	%%互动成就
					  ach_treasure = ?ACH_TREASURE_INIT,	%%奇珍异宝
					  ach_titles = []}).					%%称号集			
-record(p_title_elem, {
					   tid = 0,								%%称号id
					   expi = 0								%%时间戳，0：能够领取了，但是还未领取；1：领取了，而且是无限时间的；N：领取了，而且将在N时间过期
					  }).

-record(p_ach_pearl, {gid = 0,%%物品id
					  goods_id = 0,%%物品类型Id
					  cell = 0,%%装备的位置
					  add_type = null, %%加成类型
					  effect = 0%%加成的效果
					 }).
%%八神珠装备时高级低级的等级限制列表
-define(PEARL_LEVEL_LIMIT, [{30037,[30036,30035]},		%%新手朱雀神珠
							{30036,[]},					%%朱雀神珠·真
							{30035,[30036]},			%%朱雀神珠
							{30032,[30031,30030]},		%%新手勾陈神珠
							{30031,[]},					%%勾陈神珠·真
							{30030,[30031]},			%%勾陈神珠
							{30027,[30026,30025]},		%%新手六合神珠
							{30026,[]},					%%六合神珠·真
							{30025,[30026]},			%%六合神珠
							{30022,[30021,30020]},		%%新手太阴神珠
							{30021,[]},					%%太阴神珠·真
							{30020,[30021]},			%%太阴神珠
							{30017,[30016,30015]},		%%新手腾蛇神珠
							{30016,[]},					%%腾蛇神珠·真
							{30015,[30016]},			%%腾蛇神珠
							{30012,[30011,30010]},		%%新手直符神珠
							{30011,[]},					%%直符神珠·真
							{30010,[30011]},			%%直符神珠
							{30007,[30006,30005]},		%%新手九天神珠
							{30006,[]},					%%九天神珠·真
							{30005,[30006]},			%%九天神珠
							{30002,[30001,30000]},		%%新手九地神珠
							{30001,[]},					%%九地神珠·真
							{30000,[30001]}				%%九地神珠
						   ]).

-define(ACHIEVE_LOG, ets_log_ach_f).			%%记录玩家成就系统完成日志

-define(ACHIEVE_STATISTICS, ets_ach_stats). %%玩家成就系统的统计数据

-define(REALM_HONOR_LIMIT, 500).		%%部落英雄称号的最小部落荣誉值
-define(ADORE_DISDAIN_LIMIT, 100).		%%能够获取称号是的被崇拜或者鄙视的最少次数
-define(BATT_VALUE_LIMIT, 2400).		%%能够获取到战斗力称号的最少战斗力值

-define(ACH_FINISH_RATE,1). %%默认的成就总进度
-define(ACH_FINISH_NOT,0).%%默认成就没完成情况

-define(TASK_RC_ONE, 10). %%日常任务
-define(TASK_RC_TWO, 100). %%日常任务
-define(TASK_GUILD_ONE, 30).%%氏族任务
-define(TASK_GUILD_TWO, 200).
-define(TASK_GUILD_THREE, 900).
-define(TASK_FB_ONE, 30).%%副本任务
-define(TASK_FB_TWO, 200).
-define(TASK_FB_THREE, 900).
-define(TASK_CULTURE_ONE, 15).%%修为任务
-define(TASK_CULTURE_TWO, 45).
-define(TASK_CARRY_ONE, 30).%%运镖任务
-define(TASK_CARRY_TWO, 120).
-define(TASK_BUS_ONE, 30).%%跑商任务
-define(TASK_BUS_TWO, 120).
-define(TASK_FST_ONE, 30).%%封神帖任务
-define(TASK_FST_TWO, 120).
-define(TASK_CYCLE_ONE, 450).%%循环任务
-define(TASK_CYCLE_TWO, 4500).

-define(TRIALS_TRM_ONE, 10000).%%击杀怪物
-define(TRIALS_TRM_TWO, 5000000).
-define(TRIALS_BOSS_ONE, 50).%%击杀火凤
-define(TRIALS_BOSS_TWO, 50).%%击杀千年老龟
-define(TRIALS_BOSS_THREE, 50).%%击杀烈焰麒麟兽
-define(TRIALS_BOSS_FOUR, 100).%%击杀灵狐
-define(TRIALS_BOSS_FIVE, 100).%%击杀裂地斧魔
-define(TRIALS_BOSS_SIX, 100).%%击杀千年猴妖
-define(TRIALS_TRBC_ONE, 5).%%成功劫镖次数
-define(TRIALS_TRBC_TWO, 3).%%成功劫商次数
-define(TRIALS_TRBC_THREE, 3).%%成功打劫紫色商车次数
-define(TRIALS_TRBUS_ONE, 2).%%成功紫商车次数1
-define(TRIALS_TRBUS_TWO, 20).%%成功紫商车次数2
-define(TRIALS_TRFST_ONE, 50).%%封神台通关次数12层
-define(TRIALS_TRFST_TWO, 50).%%封神台通关次数21层
-define(TRIALS_TRFST_THREE, 50).%%封神台通关次数45层
-define(TRIALS_TRAR_ONE, 100).%%战场杀敌次数
-define(TRIALS_TRAR_TWO, 500).
-define(TRIALS_TRAR_THREE, 5000).
-define(TRIALS_TRF_ONE, 10).%%氏族战运旗次数
-define(TRIALS_TRF_TWO, 100).
-define(TRIALS_TRF_THREE, 300).
-define(TRIALS_TRSTD_ONE, 30).%%单人镇妖台杀怪物次数，千年毒尸
-define(TRIALS_TRSTD_TWO, 15).%%单人镇妖台杀怪物次数，龙骨甲兽
-define(TRIALS_TRSTD_THREE, 10).%%单人镇妖台杀怪物次数，食腐树妖
-define(TRIALS_TRMTD_ONE, 30).%%多人镇妖台杀怪物次数，龙骨甲兽
-define(TRIALS_TRMTD_TWO, 15).%%多人镇妖台杀怪物次数，龙骨甲兽
-define(TRIALS_TRMTD_THREE, 10).%%多人镇妖台杀怪物次数，龙骨甲兽
-define(TRIALS_TRFBB_ONE, 100).%%击杀副本boss次数，雷公
-define(TRIALS_TRFBB_TWO, 150).%%击杀副本boss次数，狐小小
-define(TRIALS_TRFBB_THREE, 200).%%击杀副本boss次数，河伯
-define(TRIALS_TRFBB_FOUR, 200).%%击杀副本boss次数，蚩尤
-define(TRIALS_TRSIXFB_ONE, 30).%%击杀大boss次数,穷奇
-define(TRIALS_TRSIXFB_TWO, 100).%%击杀大boss次数,赤尾狐
-define(TRIALS_TRSIXFB_THREE, 200).%%击杀大boss次数,瑶池圣母
-define(TRIALS_TRZXT_ONE, 30).%%诛仙台通关次数12层
-define(TRIALS_TRZXT_TWO, 30).%%诛仙台通关次数21层
-define(TRIALS_TRZXT_THREE, 30).%%诛仙台通关次数45层
-define(TRIALS_TRSM_ONE, 50).%%神魔乱斗参与击败哈迪斯次数1
-define(TRIALS_TRSM_TWO, 100).%%神魔乱斗参与击败哈迪斯次数2
-define(TRIALS_TRTRAIN_ONE, 50).%%击败试炼之祖次数1
-define(TRIALS_TRTRAIN_TWO, 100).%%击败试炼之祖次数2
-define(TRIALS_TRGG_NUM, 200).%%击败共工200次
-define(TRIALS_TRDS_NUM, 100).%%击败千年毒尸
-define(TRIALS_TRJL_NUM, 100).%%击败蛮荒巨龙



-define(FS_FSB_ONE, 1200).%%诛邪次数，百年
-define(FS_FSB_TWO, 1200).%%诛邪次数，千年
-define(FS_FSB_THREE, 1200).%%诛邪次数，万年
-define(FS_FSSH, 100).%%商城购买道具次数
-define(FS_FSC_ONE, 50).%%物品石头合成次数
-define(FS_FSC_TWO, 1000).%%物品装备分解次数
-define(FS_FSSA_ONE, 100).%%市场挂售次数
-define(FS_FSSA_TWO, 100).%%市场购买次数
-define(FS_FSLG_ONE, 200*60).%%离线挂机次数1	(改为分钟--2011-10-15)
-define(FS_FSLG_TWO, 500*60).%%离线挂机次数2 (改为分钟--2011-10-15)

-define(YG_COIN_ONE, 1000000).%%远古成就铜币
-define(YG_COIN_TWO, 100000000).
-define(YG_CULTURE_ONE, 10000).%%修为
-define(YG_CULTURE_TWO, 150000).
-define(YG_CULTURE_THREE, 500000).
-define(YG_HONOR_ONE,10000).%%封神台荣誉
-define(YG_HONOR_TWO,100000).
-define(YG_HONOR_THREE,200000).

-define(INTERACT_APPRENTICE_ONE, 1).%%1个徒弟出师
-define(INTERACT_APPRENTICE_TOW, 2).%%2个徒弟出师
-define(INTERACT_APPRENTICE_THREE, 3).%%3个徒弟出师
-define(INTERACT_GUILD_DONATE, 10000).%%氏族贡献达到10000
-define(INTERACT_FRIENDS_ONE, 5).%%拥有5个好友
-define(INTERACT_FRIENDS_TWO, 20).%%拥有20个好友
-define(INTERACT_FRIENDS_THREE, 30).%%拥有30个好友
-define(INTERACT_INFL_ONE, 1).%%玩家送花朵书数1
-define(INTERACT_INFL_TWO, 99).%%玩家送花朵书数2
-define(INTERACT_INFO_THREE, 3000).%%玩家送花朵书数3
-define(INTERACT_LOVE_ONE, 20).%%魅力值达到20点
-define(INTERACT_LOVE_TWO, 1314).%%魅力值达到1314点
-define(INTERACT_LOVE_THREE, 3344).%%魅力值达到3344点
-define(INTERACT_INLV_ONE, 1).%%完成仙侣情缘次数1
-define(INTERACT_INLV_TWO, 20).%%完成仙侣情缘次数2
-define(INTERACT_INLVED_ONE, 1).%%仙侣情缘中被邀请次数1
-define(INTERACT_INLVED_TWO, 40).%%仙侣情缘中被邀请次数2
-define(INTERACT_INFAI_ONE, 100).%%庄园收获次数1
-define(INTERACT_INFAI_TWO, 1000).%%庄园收获次数2
-define(INITERACT_INFAO_ONE, 100).%%庄园偷取次数1
-define(INTERACT_INFAO_TWO, 1000).%%庄园偷取次数2
-define(INTERACT_FARM_NUM, 9). %%庄园田地的数量
-define(INTERACT_BS_ONE, 100).	%%被鄙视次数1
-define(INTERACT_BS_TWO, 2000).	%%被鄙视次数2
-define(INTERACT_CB_ONE, 100).	%%被崇拜次数1
-define(INTERACT_CB_TWO, 2000).	%%被崇拜次数2

%%普通称号{称号Id，时效(0：无限制)，是否完成(0-未完成  1-完成)}
-define(COMMON_TITLES,[{801, 432000, 0, 0}, %%	人气王子
					   {802, 432000, 0, 0}, %%	人气宝贝
					   {803, 604800, 0, 0},  %%	多情公子
					   {804, 604800, 0, 0}  %%	魅力宝宝
					  ]).
%%特殊称号{称号Id，时效(0：无限制)，是否完成(0-未完成  1-完成)}
-define(SPECIAL_TITLES, [{901, 259200, 0, 0}, 	%%	封神霸主
						 {902, 259200, 0, 0}, 	%%	天下无敌
						 {903, 259200, 0, 0},	%%	女娲英雄
						 {904, 259200, 0, 0},	%%	神农英雄
						 {905, 259200, 0, 0},	%%	伏羲英雄
						 {906, 259200, 0, 0},	%%	不差钱
						 {907, 259200, 0, 0},	%%	八神之主
						 {908, 259200, 0, 0},	%%	绝世神兵
						 {909, 259200, 0, 0},	%%	诛仙霸主
						 {910, 259200, 0, 0},	%%	全民偶像
						 {911, 259200, 0, 0},	%%	全民公敌
						 {912, 259200, 0, 0},	%%	远古战神
						 {913, 259200, 0, 0},	%%	九霄城主
						 {914, 259200, 0, 0},	%%	天下第一
						 {915, 604800, 0, 0},	%%	远古无双
						 {916, 259200, 0, 0}	%%	一骑绝尘
						]).

%%称号的数值集合(与上面的两个macro同步)
-define(PLYAER_TITLES_MEMBERS, [801, 802, 803, 804, %%普通称号
								901, 902, 903, 904, 905, 906, 907, 908, 909, 910, 911, 912, 913, 914, 915, 916]).%%特殊称号
%%全服需要特殊更新的称号集，与特殊称号集SPECIAL_TITLES 同步
-define(SERVER_TITLE_IDS, [901, 902, 903, 904, 905, 906, 907, 908, 909, 910, 911, 912, 913, 914, 915, 916]).

-record(server_titles, {fst = [],			%%封神霸主
						area_king = [],		%%天下无敌
						nwfirst = [],		%%女娲英雄
						snfirst = [],		%%神农英雄 
						fxfirst = [],		%%伏羲英雄
						rich = [],			%%不差钱
						ach = [],			%%八神之主
						equip = [],			%%绝世神兵
						zxt = [],			%%诛仙霸主
						adore = [],			%%全民偶像
						disdain = [],		%%全民公敌
						ygzs = [],			%%远古战神
						castle = [],		%%九霄城主
						world_first = [],	%%天下第一
						yg_unique = [],		%%远古无双
						mount_king = []		%%一骑绝尘
					  }).
