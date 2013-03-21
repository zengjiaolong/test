-define(GUILD_MEMBER, "一般族员").
-define(DEPUTY_CHIEF, "长老").
-define(CHIEF, "族长").
%% 定义加入氏族或创建氏族的最小等级(包括该等级)
-define(CREATE_GUILD_LV, 20).
%% 氏族申请最大限制人数
-define(GUILD_APPLY_NUM_LIMIT, 30).
%% 定义氏族初始化的时候的技能点
-define(GUILD_SKILL_INIT, 2).
%% 退出氏族后重新加入新氏族的时间限制
-define(QUIT_GUILD_TIME_LIMIT, 43200).
%% 一般弟子的堂ID
-define(NOMAL_GUILD_MEMBER,5).

%% 事件类型：加入氏族
-define(CREATE_GUILD_ONE, "恭喜，").
-define(CREATE_GUILD_TWO, "创建了名为").
-define(CREATE_GUILD_THREE, "的氏族！").
-define(JOIN_GUILD_ONE, "欢迎").
-define(JOIN_GUILD_TWO, "加入氏族").

%% 事件类型：退出氏族氏族
-define(QUIT_GUILD, "遗憾地退出了氏族！").
-define(KICKOUT_GUILD_ONE, "表现不佳，被").
-define(KICKOUT_GUILD_TWO, "开除出氏族！").

%% 事件类型：捐献铜币
-define(DONATE_MONEY_ONE, "慷慨地捐献了").
-define(DONATE_MONEY_TWO, "铜币").

%% 事件类型：职位变化
-define(PROMOTION_ONE, "贡献卓越，被").
-define(PROMOTION_TWO,"提拔为").
-define(DEMOTION_ONE, "玩疏职守，被").
-define(DEMOTION_TWO, "降为").
-define(DEMISE_CHIEF_ONE, "出于战略考虑，").
-define(DEMISE_CHIEF_TWO, "将族长之位传让给").
-define(POSITION_CHANGE_ONE, "被").
-define(POSITION_CHANGE_TWO, "任命为").
-define(ACCUSE_CHIEF_ONE, "成功弹劾久未上线的").
-define(ACCUSE_CHIEF_TWO, "，成为新任族长").

%% 事件类型：氏族福利计算基数
-define(WELFARE_ONE, 400).
-define(WELFARE_TWO, 1000).
-define(WELFARE_THREE, 1000).

%% 事件类型：氏族活动

-define(GUILD_CALL_BOSS_DATE, [1,3,5]).%%氏族boss能否召唤的date时间，周一三五

%% 氏族技能等级描述
-define(GUILD_SKILL_DESC, 
		[{{1, 0}, "<font color=\"#FFFF00\">当前拥有0个格子。</font><br /><font color=\"#FF0000\">氏族仓库用于存放氏族成员物品的空间。每升1级，格子数增加25。</font> <br /><font color=\"#FFFF00\">最高等级为5，最多可拥有125格。</font>"},
		 {{1, 1}, "<font color=\"#FFFF00\">当前拥有25个格子。</font><br /><font color=\"#FF0000\">氏族仓库用于存放氏族成员物品的空间。每升1级，格子数增加25。</font> <br /><font color=\"#FFFF00\">最高等级为5，最多可拥有125格。</font>"},
		 {{1, 2}, "<font color=\"#FFFF00\">当前拥有50个格子。</font><br /><font color=\"#FF0000\">氏族仓库用于存放氏族成员物品的空间。每升1级，格子数增加25。</font> <br /><font color=\"#FFFF00\">最高等级为5，最多可拥有125格。</font>"},
		 {{1, 3}, "<font color=\"#FFFF00\">当前拥有75个格子。</font><br /><font color=\"#FF0000\">氏族仓库用于存放氏族成员物品的空间。每升1级，格子数增加25。</font> <br /><font color=\"#FFFF00\">最高等级为5，最多可拥有125格。</font>"},
		 {{1, 4}, "<font color=\"#FFFF00\">当前拥有100个格子。</font><br /><font color=\"#FF0000\">氏族仓库用于存放氏族成员物品的空间。每升1级，格子数增加25。</font> <br /><font color=\"#FFFF00\">最高等级为5，最多可拥有125格。</font>"},
		 {{1, 5}, "<font color=\"#FFFF00\">当前拥有125个格子。</font><br /><font color=\"#FF0000\">氏族仓库用于存放氏族成员物品的空间。每升1级，格子数增加25。</font> <br /><font color=\"#FFFF00\">最高等级为5，最多可拥有125格。</font>"},
		 {{2, 0}, "<font color=\"#FFFF00\">当前氏族成员战斗额外获得0%经验。</font><br /><font color=\"#FF0000\">氏族福利可增加氏族成员战斗所获得的经验，每升1级获得的经验额外增加2%。</font> <br /><font color=\"#FFFF00\">最高等级为5，获得经验增加10%。</font>"},
		 {{2, 1}, "<font color=\"#FFFF00\">当前氏族成员战斗额外获得2%经验。</font><br /><font color=\"#FF0000\">氏族福利可增加氏族成员战斗所获得的经验，每升1级获得的经验额外增加2%。</font> <br /><font color=\"#FFFF00\">最高等级为5，获得经验增加10%。</font>"},
		 {{2, 2}, "<font color=\"#FFFF00\">当前氏族成员战斗额外获得4%经验。</font><br /><font color=\"#FF0000\">氏族福利可增加氏族成员战斗所获得的经验，每升1级获得的经验额外增加2%。</font> <br /><font color=\"#FFFF00\">最高等级为5，获得经验增加10%。</font>"},
		 {{2, 3}, "<font color=\"#FFFF00\">当前氏族成员战斗额外获得6%经验。</font><br /><font color=\"#FF0000\">氏族福利可增加氏族成员战斗所获得的经验，每升1级获得的经验额外增加2%。</font> <br /><font color=\"#FFFF00\">最高等级为5，获得经验增加10%。</font>"},
		 {{2, 4}, "<font color=\"#FFFF00\">当前氏族成员战斗额外获得8%经验。</font><br /><font color=\"#FF0000\">氏族福利可增加氏族成员战斗所获得的经验，每升1级获得的经验额外增加2%。</font> <br /><font color=\"#FFFF00\">最高等级为5，获得经验增加10%。</font>"},
		 {{2, 5}, "<font color=\"#FFFF00\">当前氏族成员战斗额外获得10%经验。</font><br /><font color=\"#FF0000\">氏族福利可增加氏族成员战斗所获得的经验，每升1级获得的经验额外增加2%。</font> <br /><font color=\"#FFFF00\">最高等级为5，获得经验增加10%。</font>"},
		 {{3, 0}, "<font color=\"#FFFF00\">当前氏族人数上限为50人。</font><br /><font color=\"#FF0000\">氏族人数的等级决定着氏族成员上限，每升1级成员上限+5。</font> <br /><font color=\"#FFFF00\">最高等级为10，氏族人数上限为100人。</font>"},
		 {{3, 1}, "<font color=\"#FFFF00\">当前氏族人数上限为55人。</font><br /><font color=\"#FF0000\">氏族人数的等级决定着氏族成员上限，每升1级成员上限+5。</font> <br /><font color=\"#FFFF00\">最高等级为10，氏族人数上限为100人。</font>"},
		 {{3, 2}, "<font color=\"#FFFF00\">当前氏族人数上限为60人。</font><br /><font color=\"#FF0000\">氏族人数的等级决定着氏族成员上限，每升1级成员上限+5。</font> <br /><font color=\"#FFFF00\">最高等级为10，氏族人数上限为100人。</font>"},
		 {{3, 3}, "<font color=\"#FFFF00\">当前氏族人数上限为65人。</font><br /><font color=\"#FF0000\">氏族人数的等级决定着氏族成员上限，每升1级成员上限+5。</font> <br /><font color=\"#FFFF00\">最高等级为10，氏族人数上限为100人。</font>"},
		 {{3, 4}, "<font color=\"#FFFF00\">当前氏族人数上限为70人。</font><br /><font color=\"#FF0000\">氏族人数的等级决定着氏族成员上限，每升1级成员上限+5。</font> <br /><font color=\"#FFFF00\">最高等级为10，氏族人数上限为100人。</font>"},
		 {{3, 5}, "<font color=\"#FFFF00\">当前氏族人数上限为75人。</font><br /><font color=\"#FF0000\">氏族人数的等级决定着氏族成员上限，每升1级成员上限+5。</font> <br /><font color=\"#FFFF00\">最高等级为10，氏族人数上限为100人。</font>"},
		 {{3, 6}, "<font color=\"#FFFF00\">当前氏族人数上限为80人。</font><br /><font color=\"#FF0000\">氏族人数的等级决定着氏族成员上限，每升1级成员上限+5。</font> <br /><font color=\"#FFFF00\">最高等级为10，氏族人数上限为100人。</font>"},
		 {{3, 7}, "<font color=\"#FFFF00\">当前氏族人数上限为85人。</font><br /><font color=\"#FF0000\">氏族人数的等级决定着氏族成员上限，每升1级成员上限+5。</font> <br /><font color=\"#FFFF00\">最高等级为10，氏族人数上限为100人。</font>"},
		 {{3, 8}, "<font color=\"#FFFF00\">当前氏族人数上限为90人。</font><br /><font color=\"#FF0000\">氏族人数的等级决定着氏族成员上限，每升1级成员上限+5。</font> <br /><font color=\"#FFFF00\">最高等级为10，氏族人数上限为100人。</font>"},
		 {{3, 9}, "<font color=\"#FFFF00\">当前氏族人数上限为95人。</font><br /><font color=\"#FF0000\">氏族人数的等级决定着氏族成员上限，每升1级成员上限+5。</font> <br /><font color=\"#FFFF00\">最高等级为10，氏族人数上限为100人。</font>"},
		 {{3, 10}, "<font color=\"#FFFF00\">当前氏族人数上限为100人。</font><br /><font color=\"#FF0000\">氏族人数的等级决定着氏族成员上限，每升1级成员上限+5。</font> <br /><font color=\"#FFFF00\">最高等级为10，氏族人数上限为100人。</font>"}]).


%%======================= 神岛空战 ================================
-record(skyrush, {boss_num = {3, [{43001, 1}, {43002, 1}, {43003, 1}]},				%%空岛上的boss数量
				  white_flags = {0, []},			%%目前在战场上的白旗数据
				  green_flags = {0, []},			%%目前在战场上的绿旗数据
				  blue_flags = {0, []},				%%目前在战场上的蓝旗数据
				  purple_flags = {0, []},			%%目前在战场上的紫旗数据
				  one_exist_flags = {0, []},		%%当前战场上开着的旗	({旗色，[{time, player_id}]})
				  two_exist_flags = {0, []},		%%当前战场上开着的旗	({旗色，[{time, player_id}]})	
				  three_exist_flags = {0, []},		%%当前战场上开着的旗	({旗色，[{time, player_id}]})	  	  
				  drop_flags = [],					%%丢落的旗数据
				  count = 0,						%%刷出旗的历史记录
				  purple_reflesh = 0,				%%是否该刷紫旗了,0为不刷，1为刷
				  
				  white_nuts = {0, []},				%%目前在战场上的白魔核数据
				  green_nuts = {0, []},				%%目前在战场上的绿魔核数据
				  blue_nuts = {0, []},				%%目前在战场上的蓝魔核数据
				  purple_nuts = {0, []},			%%目前在战场上的紫魔核数据
				  
				  point_l_read = [], 				 %%{Time, PlayerId, GuildId, GuildName}
				  point_h_read = [],
				  point_l = {0, ""},				%%占有中级据点的氏族ID
				  point_h = {0, ""},		      	 	%%占有高级据点的氏族ID
				  drop_id = 1
				}).
-record(g_feats_elem, {guild_id = 0,				%%氏族id
					   guild_name = "",				%%氏族名字
					   guild_feats = 0				%%氏族功勋
					  }).

-record(mem_feats_elem, {player_id = 0,				%%玩家Id
						 player_name = "",
						 guild_id = 0,  			%%玩家所属氏族
						 kill_foe = 0,				%%杀敌数
						 die_count = 0,				%%死亡次数
						 get_flags = 0,				%%夺旗数
						 magic_nut = 0,				%%魔核数
						 feats = 0					%%此次战斗功勋
					  }).
-record(fns_elem, {player_id = 0,					%%玩家id
					 type = 0						%%白1，绿2，蓝3，紫4
					}).
-record(df_elem, {time = 30,						%%掉落倒数时间(30秒)
				  coord = {0,0},					%%丢落的坐标
				  type = 0							%%旗类型
				 }).
-record(guild_skyrush_rank, {guild_id = 0,
							 guild_name = "",
							 lv = 0,
							 jion_m_num = 0,
							 feat_last = 0,
							 feat_week = 0,
							 feat_all = 0,
							 last_join_time = 0}).

-record(guild_mem_skyrush_rank, {player_id = 0,
								 player_name = "",
								 guild_id = 0,
								 career = 0,
								 sex = 0,
								 lv = 0,
								 kill_foe = 0,
								 die_num = 0,
								 get_flags = 0,
								 magic_nut = 0,
								 feats = 0
								 }).
%%======================= 神岛空战 ================================


%% ================================================================
%% =======================	氏族相关macro	=======================
%% ================================================================

-define(ETS_GUILD,        ets_guild).                          	 			%% 氏族
-define(ETS_GUILD_MEMBER, ets_guild_member).                    			%% 氏族成员
-define(ETS_GUILD_APPLY,  ets_guild_apply).                    				%% 氏族申请
-define(ETS_GUILD_INVITE, ets_guild_invite).                    			%% 氏族邀请
-define(ETS_LOG_GUILD, ets_log_guild).										%% 氏族日志
-define(ETS_GUILD_SKILLS_ATTRIBUTE, ets_guild_skills_attribute).			%% 氏族技能属性表
-define(ETS_GUILD_UPGRADE_STATUS, ets_guild_upgreade_status).				%% 氏族正在升级记录总汇
-define(ETS_GUILD_WAREHOUSE_INIT_TRACE, ets_guild_warehouse_init_trace).	%% 记录氏族仓库是否已经被加载
-define(ETS_GUILD_WAREHOUSE_GOODS, ets_guild_warehouse_goods).				%% 氏族仓库物品表
-define(ETS_GUILD_WAREHOUSE_ATTRIBUTES, ets_guild_goods_attributes).		%% 氏族仓库物品属性表
-define(GUILDTOKENTIME, 1200).												%% 回氏族的CD时间
-define(GUILD_MANOR_COORD,[{29, 104}, {28, 105}, {30, 103}, {27, 106}]).	%% 氏族领地对应的坐标
-define(GUILD_MANOR_PID, 10000).											%% 氏族领地场景计算出的基数id
-define(GUILD_SCENE_ID, 500).												%% 帮派领地的场景Id

-define(SKY_RUSH_SCENE_ID, 520).												%%空岛神战的场景Id
-define(SKY_RUSH_FUNDS_NEED, 100000).											%%神岛空战报所需要的资金
-define(GUILD_SKYRUSH_COORD, [{2, 150}, {7, 161}]).							%%神岛进去的时候对应的坐标
-define(SKYRUSH_REVIVE_COORD, [8, 155]).										%%神岛复活坐标
-define(LMON_REFLESH_TIME, 3*60*1000).											%%小怪刷新的时间间隔(3分钟)
%% -define(LMON_REFLESH_TIME, 60*1000).%%小怪刷新的时间间隔(测试)
-define(COORD_DIST_LIMIT, 2).													%%据点、刷棋点的坐标 限制距离					
-define(G_FEATS_ELEM, ets_g_feats_elem).
-define(MEM_FEATS_ELEM, ets_mem_feats_elem).
-define(GUILD_SKYRUSH_RANK, ets_guild_skyrush_rank).
-define(GUILD_MEM_SKYRUSH_RANK, ets_guild_mem_skyrush_rank).
-define(GUILD_UNION, guild_union).

%%氏族战奖励物品列表,修改时需要与?SKYRUSH_AWARD_ZERO同步
-define(SKYRUSH_AWARD_GOODS,
		[[{28702, 8}, {23303, 5}, {28023, 10}, {24000, 10}, {23406, 5}, {23400, 5}, {23403, 5}],
		 [{28702, 6}, {23303, 4}, {28023, 8}, {24000, 8}, {23406, 4}, {23400, 4}, {23403, 4}],
		 [{28702, 4}, {23303, 3}, {28023, 6}, {24000, 6}, {23406, 3}, {23400, 3}, {23403, 3}],
		 [{28702, 3}, {23303, 2}, {28023, 4}, {24000, 4}, {23406, 2}, {23400, 2}, {23403, 2}],
		 [{28702, 2}, {23303, 1}, {28023, 2}, {24000, 2}, {23406, 1}, {23400, 1}, {23403, 1}]]).

%% 攻城战奖励
-define(CASTLE_RUSH_AWARD_GOODS,
		[[{28702, 6}, {23303, 5}, {28023, 8}, {24000, 8}, {23406, 5}, {23400, 5}, {23403, 5}],
		 [{28702, 5}, {23303, 4}, {28023, 6}, {24000, 5}, {23406, 4}, {23400, 4}, {23403, 4}],
		 [{28702, 3}, {23303, 3}, {28023, 4}, {24000, 4}, {23406, 3}, {23400, 3}, {23403, 3}],
		 [{28702, 2}, {23303, 2}, {28023, 2}, {24000, 2}, {23406, 2}, {23400, 2}, {23403, 2}],
		 [{28702, 1}, {23303, 1}, {28023, 1}, {24000, 1}, {23406, 1}, {23400, 1}, {23403, 1}]]).

%%默认没有数据时的直接返回值,修改时需要与?SKYRUSH_AWARD_GOODS同步
-define(SKYRUSH_AWARD_ZERO, 
		[{28702, 0}, {23303, 0}, {28023, 0}, {24000, 0}, {23406, 0}, {23400, 0}, {23403, 0}]).
-define(AWARDGOODS_NUM_LIMIT, 3).%%获取同一样物品的最大数量限制

%% ================================================================

-define(PLAYER_WISH_PRODIST,{20, 40, 60, 80, 100}).				%%玩家运势随机概率分布
%%不同的玩家运势对应能刷出的任务颜色的概率分布
-define(TASK_COLOR_LUCK, [{50, 70, 85, 95, 100},		%%白色一星玩家运势的任务颜色概率分布	{白色一星,绿色二星,蓝色三星,金色四星,紫色五星}
						  {15, 65, 80, 90, 100},		%%绿色二星玩家运势的任务颜色概率分布	{白色一星,绿色二星,蓝色三星,金色四星,紫色五星}
						  {15, 30, 70, 85, 100},		%%蓝色三星玩家运势的任务颜色概率分布	{白色一星,绿色二星,蓝色三星,金色四星,紫色五星}
						  {10, 20, 30, 80, 100},		%%金色四星玩家运势的任务颜色概率分布	{白色一星,绿色二星,蓝色三星,金色四星,紫色五星}
						  {5, 15, 30, 50, 100}]			%%紫色五星玩家运势的任务颜色概率分布	{白色一星,绿色二星,蓝色三星,金色四星,紫色五星}
	   ).

-define(LOG_F5_GWISH, log_f5_gwish).							%%玩家帮忙玩家刷新氏族任务祝福的日志表
-define(GUILD_WISH_TASK_ID, 83150).								%%氏族祝福的任务Id
-define(WISH_TASK_FLUSH_TIME, 60*15).							%%氏族祝福任务刷新时间
-define(F5_GWISH_LIMIT, 50).									%%氏族帮助日志的最大数量
-define(GWISH_HELP_LIMIT, 5).									%%帮助别人刷新任务运势的最大次数
-define(MEMBER_GWISH, member_gwish).							%%氏族成员的氏族祝福运势数据
-define(GWISH_GOODS_ID, 28813).									%%氏族祝福运势礼包Id
-record(mem_gwish, {pid = 0,		%%玩家Id
					gid = 0,		%%氏族Id
					pname = "",		%%玩家名字
					sex = 0,		%%玩家性别
					career = 0,	%%玩家职业
					luck = 0,		%%玩家当天的运势
					tid = 0,		%%任务Id
					t_color = 0,	%%任务星级
					tstate = 0,		%%任务状态
					help = 0,		%%助人次数
					bhelp = 0		%%被助次数
				   }).

-record(p_gwish, {luck = 0, 		%%玩家当天运势，N：N颗星
				  t_color = 0,		%%任务运势等级，N：N星
				  tid = 0,			%%刷出来的任务Id
				  tstate = 0,		%%任务状态
				  task = 0,			%%任务完成情况，此值会根据不同的任务情况，做不同的数值保存
				  help = 0,			%%助人次数
				  bhelp = 0,		%%被帮助次数
				  flush = 0,		%%任务刷新时间
				  time = 0,			%%玩家运势刷新时间
				  finish = []		%%玩家当天已经完成的任务Ids
				 }).

-define(GWISN_COIN_NEED, 500).%%刷新时间所需要的  铜币/分钟

%%氏族祝福任务 的  任务Id和等级相关数据
-define(GWISH_TASK_LIST, [{1, 35}, {2, 35}, {3, 35}, {4, 35}, {5, 35}, {6, 35}, {7, 36}, {8, 40}, {9, 35}, {10, 55}, 
						  {11, 35}, {12, 35}, {13, 35}, {14, 35}, {17, 35}, {18, 35}, {19, 35}, {20, 35}, 
						  {21, 35}, {22, 35}, {24, 35}, {26, 35}, {29, 35}, {30, 35}, 
						  {31, 35}, {32, 35}, {33, 35}, {34, 35}, {35, 35}, {36, 35}, {37, 35}, {38, 35}, {39, 35}]).

%%最大任务Id是39 值等于length(?GWISH_TASK_TIDS_LIST)
-define(GWISH_TASK_LIMIT_NUM, 39).
%%氏族祝福 任务 内容列表(当前最大任务Id是39)
-define(GWISH_TASK_TIDS_LIST,[[1], [2,30], [3,31], [4], [5,32,33], [6], [7], [8], [9], [10], 
							  [11], [12], [13,34,35], [14], [15], [16], [17], [18], [19], [20,36,37], 
							  [21], [22], [23], [24,38,39], [25], [26], [27], [28], [29], [2,30], 
							  [3,31], [5,32,33], [5,32,33], [13,34,35], [13,34,35], [20,36,37], [20,36,37], [24,38,39], [24,38,39]]).

%%需要进行即时触发判断的任务Id 氏族祝福任务触发立即完成(跟活跃度的完成情况挂钩)
-define(GWISH_TASK_FINISH_RIGHTNOW, [2,30, 3,31, 4, 5,32,33, 9, 13,34,35, 17, 18, 19, 20,36,37, 21, 22, 24,38,39, 26]).

%%氏族祝福任务内容数据limit值
-define(TASK_2, 2).
-define(TASK_11, [21301, 21311, 21321, 31331, 21341, 21351, 21361]).%%二级宝石Id
-define(TASK_12, 100).
-define(TASK_14, 2).
-define(TASK_19, 10).


-define(WARFARE_SCENE_ID, 780).%神魔乱战的场景Id
-define(WARFARE_REVIVE_COST, 3).	%%神魔乱斗场景立即复活花费元宝
-define(WARFARE_MON_IDS, [43101,43102,43103,43104,43105]).		%%神魔乱斗的怪物Id
-define(ADD_EXP, 8000).					%%冥王之灵经验加成参数
-define(ADD_SPRI, 50000).				%%冥王之灵灵力加成参数
-define(WARFARE_OUT_SCENE, {300, 74, 129}).		%%离开神魔乱斗的场景
-define(WARFARE_REVIVE_COORD, [5, 74]).		%%神魔乱斗复活坐标
-define(MON_ADD_HP, 50000).			%%神魔乱斗小怪涨血基数
-define(MON_ADD_ATT, 200).			%%神魔乱斗小怪涨攻击基数
-define(BOSS_ADD_HP, 200000).		%%神魔乱斗boss涨血基数
-define(BOSS_ADD_ATT, 500).			%%神魔乱斗boss涨攻击基数

-define(GUILD_ALLIANCE, ets_g_alliance).				%%氏族联盟数据表
-define(GUILD_ALLIANCE_APPLY, ets_g_alliance_apply).	%%氏族联盟申请表

%%绑定铜一次性刷新的数量
-define(BCOIN_NUM_LIMIT, 400).
