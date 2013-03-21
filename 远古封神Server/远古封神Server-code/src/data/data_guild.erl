%%%---------------------------------------
%%% @Module  : data_guild
%%% @Author  : ygzj
%%% @Created : 2010.10.06
%%% @Description:  氏族配置
%%%---------------------------------------
-module(data_guild).
-compile(export_all).
%% 职位标志位意义
%% 1族长
%% 2、3长老
%% 4东方堂堂主
%% 5西门堂堂主
%% 6南岭堂堂主
%% 7北斗堂堂主
%% 8东方堂弟子
%% 9西门堂弟子
%% 10南岭堂弟子
%% 11北斗堂弟子
%% 12一般弟子

-include("guild_info.hrl"). 
-record(guild_config, {
        % 创建氏族所需铜币
        create_coin  = 80000,
        % 创建氏族所需要的建帮卡ID和数目
        create_guild_card = [28300, 1],
        % 加入时的默认职位
        default_position = 12,
        % 氏族贡献和所捐钱币的比率
        donate_money_ratio = 100,
        % 氏族贡献和所捐建设卡的比率
        donate_contribution_card_ratio = 10,
		%%氏族仓库升级后仓库的大小指数：仓库大小 = 基数*氏族仓库技能等级
		guild_skill_storage_base = 0.25,
		%%氏族福利，氏族成员战斗结束后，可额外获得原经验的2%*k
		guild_skill_exp_base = 0.02,
		%%氏族人口上限基数
		guild_member_base = 50,
		%%氏族等级上限
		guild_level_limit = 10,
		%%氏族仓库数量基数：仓库容量 = SkillLevel* guild_warehouse_base
		guild_warehouse_base = 25
    }).


get_guild_config(Type, _Args) ->
    GuildConfig = #guild_config{},
    case Type of
        create_coin  ->                    GuildConfig#guild_config.create_coin;
        create_guild_card  ->    		   GuildConfig#guild_config.create_guild_card;
        default_position ->                GuildConfig#guild_config.default_position;
        donate_money_ratio ->              GuildConfig#guild_config.donate_money_ratio;
        donate_contribution_card_ratio ->  GuildConfig#guild_config.donate_contribution_card_ratio;
		guild_skill_storage_base ->		   GuildConfig#guild_config.guild_skill_storage_base;
		guild_skill_exp_base ->			   GuildConfig#guild_config.guild_skill_exp_base;
		guild_member_base ->			   GuildConfig#guild_config.guild_member_base;
		guild_level_limit -> 			   GuildConfig#guild_config.guild_level_limit;
		guild_warehouse_base ->			   GuildConfig#guild_config.guild_warehouse_base
    end.

%% % 职位说明
%% get_position_define(Position) ->
%%     PositionDefineInfo = [{1, "族长"}, {2, "副族长"},{3, "长老"}, {4, "堂主"}, {5, "帮众"} ],
%%     {value, {_, PositionDefine}}  = lists:keysearch(Position, 1, PositionDefineInfo),
%%     PositionDefine.

%%暂时不用了
%% % 级别信息{氏族等级, 成员数量基础, 成员数量上限}
%% get_level_info(Level) ->
%%     LevelInfo = [{1,1,10},
%% 				 {2,10,15},
%% 				 {3,15,20},
%% 				 {4,20,25},
%% 				 {5,25,30},
%% 				 {6,30,35},
%% 				 {7,35,40},
%% 				 {8,40,45},
%% 				 {9,45,50},
%% 				 {10,50,55}],
%%     {value, {_, MemberCapacityBase, MemberCapcity}}  = lists:keysearch(Level, 1, LevelInfo),
%%     [MemberCapacityBase, MemberCapcity].

%此方法不用了
%% % 仓库信息{仓库等级, 仓库大小, 升级所需铜币, 升级所需氏族建设卡}
%% get_depot_info(Level) ->
%%     DepotInfo = [{1,0.5,0,0},
%% 				 {2,1,500000,50},
%% 				 {3,1.5,1000000,100},
%% 				 {4,2,2000000,200},
%% 				 {5,2.5,3000000,300},
%% 				 {6,3,4000000,400},
%% 				 {7,3.5,5000000,500},
%% 				 {8,4,6000000,600},
%% 				 {9,4.5,8000000,800},
%% 				 {10,5,10000000,1000}],
%%     {value, {_, Area, Coin, ContributionCardNum}}  = lists:keysearch(Level, 1, DepotInfo),
%%     [Area, Coin, ContributionCardNum].

%% % 大厅信息{大厅等级, 大厅大小, 升级所需铜币, 升级所需氏族建设卡}
%% get_hall_info(Level) ->
%%     HallInfo = [{1,0.5,0,0},
%% 				{2,1,500000,50},
%% 				{3,1.5,1000000,100},
%% 				{4,2,2000000,200},
%% 				{5,2.5,3000000,300},
%% 				{6,3,4000000,400},
%% 				{7,3.5,5000000,500},
%% 				{8,4,6000000,600},
%% 				{9,4.5,8000000,800},
%% 				{10,5,10000000,1000}],
%%     {value, {_, Area, Coin, ContributionCardNum}}  = lists:keysearch(Level, 1, HallInfo),
%%     [Area, Coin, ContributionCardNum].

%%氏族等级升级信息{等级数， 氏族资金， 氏族经验， 所需时间， 增加技能点}
get_guild_upgrade_info(Level) ->
	UpgradeInfo = [{1, 0, 0, 0, 0},
					{2, 10000, 50000, 7200, 2},
					{3, 50000, 100000, 18000, 2},
					{4, 140000, 250000, 36000, 2},
					{5, 250000, 500000, 61000, 2},
					{6, 400000, 1000000, 86400, 2},
					{7, 600000, 2000000, 10800, 2},
					{8, 900000, 4000000, 129600, 2},
					{9, 1200000, 6000000, 151200, 2},
					{10, 1500000, 10000000, 172800, 2}],
	Level1 = 
		if Level <1 orelse Level > length(UpgradeInfo) ->
			   1;
		   true ->
			   Level
		end,
	{value, {_, Funds, Exp, NeedTime, AddSkills}} = lists:keysearch(Level1, 1, UpgradeInfo),
	[Funds, Exp, NeedTime, AddSkills].

%%返回氏族技能升级信息{技能ID，最高等级上限，氏族等级条件A*Level+B{A，B}， 氏族资金}
get_guild_skill_upgrade_info(SkillId) ->
	SkillUpGradeInfo = [{1, 5, {2, -1}, 10000},
						{2, 5, {2, 0}, 100000},
						{3, 10, {1, 0}, 10000},
						{4, 10, {1, 0}, 50000},
						{5, 10, {1, 0}, 50000},
						{6, 10, {1, 0}, 50000},
						{7, 10, {1, 0}, 50000},
						{8, 10, {1, 0}, 50000},
						{9, 10, {1, 0}, 50000},
						{10, 10, {1, 0}, 50000}],
	{value, {_, LevelLimit, LevelBase, FundsBase}} = lists:keysearch(SkillId, 1, SkillUpGradeInfo),
	[LevelBase, LevelLimit, FundsBase].

%%返回氏族等级对应的每天资金消耗[等级，日消耗的资金]
get_guild_funds_consume(Level) ->
	ConsumeFundsInfo = [{1, 20000},
					{2, 23000},
					{3, 26000},
					{4, 29000},
					{5, 32000},
					{6, 35000},
					{7, 38000},
					{8, 41000},
					{9, 44000},
					{10, 47000}],
	{value, {LevelBase, ConsumeFunds}} = lists:keysearch(Level, 1, ConsumeFundsInfo),
	[LevelBase, ConsumeFunds].
	

%%获取氏族技能名字
get_skills_names(Type) ->
	SkillsNames = [{1, "氏族仓库"}, 
				   {2, "氏族福利"}, 
				   {3, "人口"},
				   {4,"氏族攻击"},
				   {5,"氏族防御"},
				   {6,"氏族气血"},
				   {7,"氏族法力"},
				   {8,"氏族命中"},
				   {9,"氏族闪躲"},
				   {10,"氏族暴击"}],
	case Type of
		0 ->
			SkillsNames;
		_ ->
			{value, {_TypeBase, SkillName}} = lists:keysearch(Type, 1, SkillsNames),
			SkillName
	end.
		

%%获取氏族技能描述
get_skill_description(SkillId,SkillLevel) ->
	SkillsDesc = ?GUILD_SKILL_DESC,
	{value, {_SkillsId, Description}} = lists:keysearch({SkillId, SkillLevel}, 1, SkillsDesc),
	[Description].
	

get_departmemt_names(Post, DepartId) ->
	DpartNames = [{{0, 0}, "东风堂,西门堂,南岭堂,北斗堂"},
				  {{1, 5}, "长老"},
				  {{2, 1}, "堂主"},
				  {{2, 2}, "堂主"},
				  {{2, 3}, "堂主"},
				  {{2, 4}, "堂主"},
				  {{3, 1}, "弟子"},
				  {{3, 2}, "弟子"},
				  {{3, 3}, "弟子"},
				  {{3, 4}, "弟子"},
				  {{3, 5}, "一般弟子"}],
	{value, {_PostId, DepartName}} = lists:keysearch({Post, DepartId}, 1, DpartNames),
	DepartName.
%%获取从氏族领地传送到外面的坐标{场景id，X，Y}
get_manor_send_out(SceneId) ->
%% 	io:format("get_manor_send_out,SceneId: ~p\n", [SceneId]),
	Info = [{200, {200, 73, 193}},%%女娲族
			{280, {280, 76, 186}},%%神农族
			{250, {250, 72, 187}},%%伏羲族
			{300, {300, 44, 92}},%%九霄的主城
			{520, {300, 44, 92}},%%默认九霄主城
			{0, {300, 44, 92}}],%%从空岛出来,默认九霄主城
	 case lists:keysearch(SceneId, 1, Info) of
		 {value,{_SceneId, {NewSceneId, X, Y}}} ->
			 {NewSceneId, X, Y};
		 false ->
			 {300, 44, 92}%%默认九霄主城
	end.
		  
%%return -> {增加的技能效果值，升级需要的资金，升级需要的技能令数}
get_guild_h_skill_base(HSkillId, NewHKLevel) ->
	Info = [{{4, 0}, 0, 0, 0}, {{4, 1}, 25, 50000, 1}, {{4, 2}, 51, 100000, 2}, {{4, 3}, 56, 150000, 2}, {{4, 4}, 66, 20000, 3}, {{4, 5}, 82, 250000, 3}, {{4, 6}, 106,  300000, 4}, {{4, 7}, 138, 350000, 4}, {{4, 8}, 180, 400000, 5}, {{4, 9}, 231, 450000, 5}, {{4, 10}, 293, 500000, 6},
			{{5, 0}, 0, 0, 0}, {{5, 1}, 25, 50000, 1}, {{5, 2}, 50, 100000, 2}, {{5, 3}, 100, 150000, 2}, {{5, 4}, 150, 20000, 3}, {{5, 5}, 200, 250000, 3}, {{5, 6}, 250,  300000, 4}, {{5, 7}, 300, 350000, 4}, {{5, 8}, 350, 400000, 5}, {{5, 9}, 400, 450000, 5}, {{5, 10}, 450, 500000, 6},
			{{6, 0}, 0, 0, 0}, {{6, 1}, 100, 50000, 1}, {{6, 2}, 204, 100000, 2}, {{6, 3}, 224, 150000, 2}, {{6, 4}, 264, 20000, 3}, {{6, 5}, 328, 250000, 3}, {{6, 6}, 424,  300000, 4}, {{6, 7}, 552, 350000, 4}, {{6, 8}, 720, 400000, 5}, {{6, 9}, 924, 450000, 5}, {{6, 10}, 1172, 500000, 6},
			{{7, 0}, 0, 0, 0}, {{7, 1}, 25, 50000, 1}, {{7, 2}, 50, 100000, 2}, {{7, 3}, 70, 150000, 2}, {{7, 4}, 90, 20000, 3}, {{7, 5}, 110, 250000, 3}, {{7, 6}, 130,  300000, 4}, {{7, 7}, 150, 350000, 4}, {{7, 8}, 170, 400000, 5}, {{7, 9}, 190, 450000, 5}, {{7, 10}, 210, 500000, 6},
			{{8, 0}, 0, 0, 0}, {{8, 1}, 10, 50000, 1}, {{8, 2}, 20, 100000, 2}, {{8, 3}, 30, 150000, 2}, {{8, 4}, 40, 20000, 3}, {{8, 5}, 50, 250000, 3}, {{8, 6}, 60,  300000, 4}, {{8, 7}, 70, 350000, 4}, {{8, 8}, 80, 400000, 5}, {{8, 9}, 90, 450000, 5}, {{8, 10}, 100, 500000, 6},
			{{9, 0}, 0, 0, 0}, {{9, 1}, 10, 50000, 1}, {{9, 2}, 20, 100000, 2}, {{9, 3}, 30, 150000, 2}, {{9, 4}, 40, 20000, 3}, {{9, 5}, 50, 250000, 3}, {{9, 6}, 60,  300000, 4}, {{9, 7}, 70, 350000, 4}, {{9, 8}, 80, 400000, 5}, {{9, 9}, 90, 450000, 5}, {{9, 10}, 100, 500000, 6},
			{{10, 0}, 0, 0, 0}, {{10, 1}, 10, 50000, 1}, {{10, 2}, 20, 100000, 2}, {{10, 3}, 30, 150000, 2}, {{10, 4}, 40, 20000, 3}, {{10, 5}, 50, 250000, 3}, {{10, 6}, 60,  300000, 4}, {{10, 7}, 70, 350000, 4}, {{10, 8}, 80, 400000, 5}, {{10, 9}, 90, 450000, 5}, {{10, 10}, 100, 500000, 6}],
	{value,{{HSkillId, NewHKLevel}, Add, Funds, Reputation}} = lists:keysearch({HSkillId, NewHKLevel}, 1, Info),
	{Add, Funds, Reputation}.

%%转化捐款数
get_donate_money(Type) ->
	Info = [1000, 5000, 10000, 50000, 100000],
	lists:nth(Type, Info).
%%获取氏族boss信息[NeedLv, NeedFunds, MonId, MonName, X, Y]
get_guild_call_boss(Type) ->
	Info = [{3, 50000, 41045, "烈焰女巫", 21, 61},
			{5, 120000, 41046, "寒冰女巫", 21, 61},
			{8, 200000, 41046, "寒冰女巫", 21, 61}],
	lists:nth(Type, Info).
make_boss_type(BossSv) ->
	case BossSv of
		41045 -> 
			1;
		41046 ->
			2;
		41047 ->
			3
	end.

%%氏族祝福任务奖励
%%获取经验，灵力，铜币，绑定铜，氏族贡献 氏族经验 奖励
%% {Exp, Spri, Coin, BCoin, Contribute, GuildExp}
get_gwish_award(PLv, TColor) ->
	%%先获取白色的运势数据
	{Exp, Spri, Coin, BCoin, Contribute, GuildExp} =
		if
			PLv >= 35 andalso PLv =< 44 ->	%%35~~44
				{10000, 5000, 1200, 1200, 100, 500};
			PLv >= 45 andalso PLv =< 54 ->	%%45~~54
				{20000, 10000, 1400, 1400, 200, 1000};
			PLv >= 55 andalso PLv =< 64 ->	%%55~~64
				{32000, 16000, 1600, 1600, 300, 1500};
			PLv >= 65 andalso PLv =< 74 ->	%%65~~74
				{45000, 22500, 2000, 2000, 400, 2000};
			PLv >= 75 andalso PLv =< 84 ->	%%75~~84
				{60000, 30000, 2200, 2200, 400, 2000};
			PLv >= 85 andalso PLv =< 94 ->	%%85~~94
				{75000, 37500, 2400, 2400, 400, 2000};
			PLv >= 95 andalso PLv =< 99 ->	%%95~~99
				{90000, 45000, 2600, 2600, 400, 2000};
			true ->%%这个，随便给
				{0, 0, 0, 0, 0, 0}
		end,
	FBNum = 
		if
			PLv >= 35 andalso PLv =< 44 ->%%35-44
				2;
			PLv >= 45 andalso PLv =< 54 ->%%45-54
				3;
			PLv >= 55 andalso PLv =< 64 ->%%55-64
				3;
			PLv >= 65 andalso PLv =< 69 ->%%65-69
				4;
			PLv >= 70 andalso PLv =< 99 ->%%70以上
				4;
			true ->%%其他的没得给
				0
		end,
	{trunc(TColor * Exp), trunc(TColor * Spri), trunc(Coin), 
	 trunc(BCoin), trunc(Contribute), trunc(GuildExp), FBNum}.
