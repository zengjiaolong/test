%%%---------------------------------------
%%% @Module  : data_guild
%%% @Author  : shebiao
%%% @Email   : shebiao@jieyou.com
%%% @Created : 2010-06-24
%%% @Description:  帮派配置
%%%---------------------------------------
-module(data_guild).
-compile(export_all).

-record(guild_config, {
        % 创建帮派最小等级
        create_level = 1,
        % 创建帮派所需铜币
        create_coin  = 100000,
        % 创建帮派所需建设卡
        create_contribution_card = [41, 10, 10],
        % 解散确认天数
        disband_confirm_day = 3,
        % 加入时的默认职位
        default_position = 5,
        % 帮派贡献和所捐钱币的比率
        donate_money_ratio = 10000,
        % 帮派贡献和所捐建设卡的比率
        donate_contribution_card_ratio = 10,
        % 帮派建设和建设卡的比率
        contribution_card_ratio = 10,
        % 解散确认过期天数
        disband_expired_day = 3,
        % 创建帮派后免收建设费的天数
        contribution_free_day = 3,
        % 降为0级后的解散延迟天数
        disband_lv0_delay_day = 3
    }).

get_guild_config(Type, _Args) ->
    GuildConfig = #guild_config{},
    case Type of
        create_level ->                    GuildConfig#guild_config.create_level;
        create_coin  ->                    GuildConfig#guild_config.create_coin;
        create_contribution_card  ->       GuildConfig#guild_config.create_contribution_card;
        disband_confirm_day ->             GuildConfig#guild_config.disband_confirm_day;
        default_position ->                GuildConfig#guild_config.default_position;
        donate_money_ratio ->              GuildConfig#guild_config.donate_money_ratio;
        donate_contribution_card_ratio ->  GuildConfig#guild_config.donate_contribution_card_ratio;
        contribution_card_ratio ->         GuildConfig#guild_config.contribution_card_ratio;
        disband_expired_day ->             GuildConfig#guild_config.disband_expired_day;
        contribution_free_day ->           GuildConfig#guild_config.contribution_free_day;
        disband_lv0_delay_day  ->          GuildConfig#guild_config.disband_lv0_delay_day
    end.

% 职位说明
get_position_define(Position) ->
    PositionDefineInfo = [{1, "帮主"}, {2, "副帮主"},{3, "长老"}, {4, "堂主"}, {5, "帮众"} ],
    {value, {_, PositionDefine}}  = lists:keysearch(Position, 1, PositionDefineInfo),
    PositionDefine.

% 日福利
get_paid_daily(Level, Position) ->
    PaidDailyInfo = [{1,[4000,2000,1000,500,100]},{2,[8000,4000,2000,1000,200]},{3,[12000,6000,3000,1500,300]},{4,[16000,8000,4000,2000,400]},{5,[20000,10000,5000,2500,500]},{6,[24000,12000,6000,3000,600]},{7,[28000,14000,7000,3500,700]},{8,[32000,16000,8000,4000,800]},{9,[36000,18000,9000,4500,900]},{10,[40000,20000,10000,5000,1000]}],
    {value, {_, PaidDaily}}  = lists:keysearch(Level, 1, PaidDailyInfo),
    lists:nth(Position, PaidDaily).

% 级别信息{帮派等级, 成员数量基础, 成员数量上限, 需要消耗帮派建设卡数量, 帮派建设上限, 每日建设}
get_level_info(Level) ->
    LevelInfo = [{1,1,10,0,500,50},{2,10,15,50,2000,200},{3,15,20,200,4500,450},{4,20,25,450,8000,800},{5,25,30,800,12500,1250},{6,30,35,1250,18000,1800},{7,35,40,1800,24500,2450},{8,40,45,2450,32000,3200},{9,45,50,3200,40500,4050},{10,50,55,4050,40500,5000}],
    {value, {_, MemberCapacityBase, MemberCapcity, ContributionCardNum,  ContributionThreshold, ContributionDaily}}  = lists:keysearch(Level, 1, LevelInfo),
    [MemberCapacityBase, MemberCapcity, ContributionCardNum,  ContributionThreshold, ContributionDaily].

% 仓库信息{仓库等级, 仓库大小, 升级所需铜币, 升级所需帮派建设卡}
get_depot_info(Level) ->
    DepotInfo = [{1,0.5,0,0},{2,1,500000,50},{3,1.5,1000000,100},{4,2,2000000,200},{5,2.5,3000000,300},{6,3,4000000,400},{7,3.5,5000000,500},{8,4,6000000,600},{9,4.5,8000000,800},{10,5,10000000,1000}],
    {value, {_, Area, Coin, ContributionCardNum}}  = lists:keysearch(Level, 1, DepotInfo),
    [Area, Coin, ContributionCardNum].

% 大厅信息{大厅等级, 大厅大小, 升级所需铜币, 升级所需帮派建设卡}
get_hall_info(Level) ->
    HallInfo = [{1,0.5,0,0},{2,1,500000,50},{3,1.5,1000000,100},{4,2,2000000,200},{5,2.5,3000000,300},{6,3,4000000,400},{7,3.5,5000000,500},{8,4,6000000,600},{9,4.5,8000000,800},{10,5,10000000,1000}],
    {value, {_, Area, Coin, ContributionCardNum}}  = lists:keysearch(Level, 1, HallInfo),
    [Area, Coin, ContributionCardNum].

