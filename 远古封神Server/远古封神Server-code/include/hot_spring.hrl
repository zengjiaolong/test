%% =====================================================
%% player.carry_mark 
%% 标志位数值映射关系：
%% 		0			正常情况
%% 		1~~3		运镖ing
%% 		4~~7		跑商ing
%%		8~~11		神岛空战运旗ing
%% 		12~~15		神岛空战运魔核ing
%% 		16			神岛空战开旗ing
%% 		17			神岛空战占据点ing
%% 		19			温泉采莲ing
%%		20~22		普通镖（绿，蓝，紫）
%%		23~25		国运镖（绿，蓝，紫)
%%		26			封神大会运旗标志
%%		27			神魔乱斗冥王之灵标识
%%		28			结婚吃饭
%%		29			封神争霸观战模式
%% =====================================================

-define(SPRING_OUT_COORD, {300, [{47, 172}, {67, 164}]}).%%从温泉传出来的场景ID和坐标,与?COORD_LENGTH同步
-define(COORD_LENGTH, 2).%%温泉传出的坐标的个数,即[{26, 131}, {4, 138}]的长度，与?SPRING_OUT_COORD同步
-define(SPRING_FACES_NUM, 3).%%表情数量
-define(SPRING_FACES_ID, [1,2,3]).
-define(SPRING_FACE_CD, 15).%%表情CD
-define(SPRING_TABLE, ets_spring_table).
-define(SPRING_TIMER, 15000).%%温泉时间
%% -define(SPRING_SCENE_NORMAL_ID, 525).	%%大众温泉场景ID
%% -define(SPRING_SCENE_VIP_ID, 524).	%%VIP温泉ID

-define(SPRING_SCENE_VIPTOP_ID, 530).		%%钻石VIP玩家的温泉资源Id，同时也是温泉场景的Id,	对应温泉类型：1 
																%%除钻石外的VIP玩家			对应温泉类型：2 
																%%一般玩家					对应温泉类型：3

%% 玩家在温泉的位置标注，0：温泉场景外面，1：温泉里但不在泉水里，2：VIPTOP泉水里，3：VIPNORMAL泉水里，4：PUBLIC泉水里
-define(HOTSPRING_OUTSIDE, 0).
-define(HOTSPRING_WATER_OUTSIDE, 1).
-define(HOTSPRING_WATER_VIPTOP, 2).
-define(HOTSPRING_WATER_VIPNORMAL, 3).
-define(HOTSPRING_WATER_PUBLIC, 4).

-define(WALK_INOT_WATER, 2).	%%进水
-define(WALK_OUTOF_WATER, 1).	%%出水

%%玩家进水或者出水 	Type = 进水{OSite, NSite}, 出水{NSite, OSite}, lists:member(Type, ?IN_OR_OUT_WATER)
-define(IN_OR_OUT_WATER, [{?HOTSPRING_WATER_OUTSIDE, ?HOTSPRING_WATER_VIPTOP}, 
						  {?HOTSPRING_WATER_OUTSIDE, ?HOTSPRING_WATER_VIPNORMAL},
						  {?HOTSPRING_WATER_OUTSIDE, ?HOTSPRING_WATER_PUBLIC}]).

-define(SPRING_SCENE_TYPE, 22).%%温泉场景类型


%% 温泉开放时间	[{vip开放date},{normal开放date}]
-define(SPRING_ONSALE_DATE, [[1, 2, 3, 4, 5, 6, 7],[6, 7]]).
-define(LOTUS_TIMESTAMP, 5*60*1000).	%%莲花开放的时间间隔(5分钟)
-define(LOTUS_COUNT_NUM, 6).		%%刷新莲花的次数

%%保存温泉场景上的玩家信息
-record(p_info,{player_id = 0,
				spring = 0, %%524：皇家，525：大众
				name = "",
				cd = 0,
				faces = 0}).

-define(COLLECT_LOTUS_STATE, 19).	%%温泉采集莲花状态是的carry_mark的值
-define(LOTUS_MAX_NUM, 3).%%场景上最多出现的莲花的数量
-define(LOTUS_COLLECT_TIME, 5).	%%采集莲花需要的时间(秒)
-define(LOTUS_PLAYERS_FLUSH_TIME, 700).	%%莲花清理垃圾人信息的时间戳
-define(LOTUS_COORDS_MAX, 18).					%%莲花座标个数 ,== length(lists:nth(1,?LOTUS_COORDS))
%%莲花坐标s
-define(LOTUS_COORDS, [%%vip温泉
					   [{4,36},{8,52},{14,53},{22,47},{19,33},{20,23},{15,22},{7,22},{6,15},{5,8},
						{10,37},{16,39},{19,49},{17,32},{25,30},{8,46},{11,26},{11,38}],
					   %%normal温泉
					   [{14,32},{12,40},{6,33},{4,24},{11,13},{13,8},{4,8},{18,4},{19,15},{16,24},
						{10,23},{6,19},{16,18},{3,20},{22,10},{2,32},{19,39},{8,27}]
					  ]).				
%%莲花奖励
-define(LOTUS_AWARD_GOODS, [{1, 20, 24000},		%%灵兽口粮
							{21, 25, 20200},	%%初级镶嵌符
							{26, 35, 21400},	%%初阶打孔石
							{36, 36, 20100},	%%初级合成符
							{37, 41, 20000},	%%初级摘除符
							{42, 51, 21100},	%%低阶锋芒灵石
							{52, 61, 21200},	%%低阶坚韧灵石
							{62, 77, 29101},	%%加速药剂
							{78, 82, 21001},	%%蓝色鉴定石
							{83, 83, 21101},	%%中阶锋芒灵石
							{84, 84, 21201},	%%中阶坚韧灵石
							{85, 85, 23107},	%%小法力包
							{86, 86, 23007},	%%小气血包
							{87, 91, 23413},	%%紫玄果
							{92, 92, 28002},	%%高级铜币卡
							{93, 93, 28018},	%%9朵玫瑰
							{94, 95, 24100},		%%灵兽升级果实
							{96, 100, 21800}	%%蓝色洗练石])
							]).