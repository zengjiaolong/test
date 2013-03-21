%%%------------------------------------------------
%%% File    : record.erl
%%% Author  : xyao
%%% Created : 2010-04-15
%%% Description: record
%%%------------------------------------------------

%% 所有线路记录
-record(server, {
        id,
        ip,
        port,
        node,
        num = 0
    }
).
%%玩家物品记录
-record(goods, {
        id=0,           %% 物品Id
        player_id=0,    %% 角色Id
        goods_id=0,     %% 物品类型Id，对应ets_goods_type.goods_id
        type=0,         %% 物品类型
        subtype=0,      %% 物品子类型
        equip_type=0,   %% 装备类型：0为无，1为武器，2为防具，3为饰品
        price_type=0,   %% 价格类型：1 铜钱, 2 银两，3 金币，4 绑定的铜钱
        price=0,        %% 购买价格
        sell_price=0,   %% 出售价格
        bind=0,         %% 绑定状态，0为不可绑定，1为可绑定还未绑定，2为可绑定已绑定
        trade=0,        %% 交易状态，0为可交易，1为不可交易
        sell=0,         %% 出售状态，0为可出售，1为不可出售
        isdrop=0,        %% 丢弃状态，0为可丢弃，1为不可丢弃
        level=0,        %% 物品等级
        vitality = 0,   %% 体力
        spirit = 0,     %% 灵力
        hp = 0,         %% 血量
        mp = 0,         %% 内力
        forza=0,        %% 力量
        agile=0,        %% 敏捷
        wit=0,          %% 智力
        att=0,          %% 攻击
        def=0,          %% 防御
        hit = 0,        %% 命中
        dodge = 0,      %% 躲避
        crit = 0,       %% 暴击
        ten = 0,        %% 坚韧
        speed=0,        %% 速度
        attrition=0,    %% 耐久度上限，当前耐久度由lib_goods:get_goods_attrition(UseNum)算得
        use_num=0,      %% 可使用次数，由lib_goods:get_goods_use_num(Attrition)算得
        suit_id=0,      %% 套装ID，0为无
        quality=0,      %% 品质数
        quality_his=0,  %% 历史最高品质数
        quality_fail=0, %% 历史最高品质升级失败次数
        stren=0,        %% 强化等级
        stren_his=0,    %% 历史最高强化数
        stren_fail=0,   %% 历史最高强化失败次数
        hole=0,         %% 镶孔数
        hole1_goods=0,  %% 孔1所镶物品ID
        hole2_goods=0,  %% 孔2所镶物品ID
        hole3_goods=0,  %% 孔3所镶物品ID
        location=0,     %% 物品所在位置，1 装备一，2 装备二，3 装备三, 4 背包，5 仓库
        cell=0,         %% 物品所在格子位置
        num=0,          %% 物品数量
        color=0,        %% 物品颜色，0 白色，1 绿色，2 蓝色，3 紫色，4 橙色
        expire_time=0   %% 有效期，0为无
    }).

%%玩家物品属性表
-record(goods_attribute, {
        id,             %% 编号
        player_id,      %% 角色Id
        gid,            %% 物品Id
        attribute_type, %% 属性类型，1 附加，2 强化，3 品质，4 镶嵌
        attribute_id,   %% 属性类型Id
        value_type,     %% 属性值类型，0为数值，1为百分比
        hp,             %% 气血
        mp,             %% 内力
        att,            %% 攻击
        def,            %% 防御
        hit,            %% 命中
        dodge,          %% 躲避
        crit,           %% 暴击
        ten             %% 坚韧
    }).

%%装备套装属性表
-record(suit_attribute, {
        id,             %% 编号
        suit_id,        %% 套装ID
        suit_num,       %% 套装件数
        attribute_id,   %% 属性类型Id
        value_type,     %% 属性值类型，0为数值，1为百分比
        hp,             %% 气血
        mp,             %% 内力
        att,            %% 攻击
        def,            %% 防御
        hit,            %% 命中
        dodge,          %% 躲避
        crit,           %% 暴击
        ten             %% 坚韧
    }).

%% 物品掉落表
-record(ets_goods_drop, {
        id=0,             %% 编号
        player_id=0,      %% 角色ID
        team_id=0,        %% 组队ID
        drop_goods=[],    %% 掉落物品[[物品类型ID,物品类型,物品数量,物品品质]...]
        expire_time=0     %% 过期时间
    }).

%%###########ETS##################
-record(ets_online, {
        id = 0,
        nickname = none,
        pid = 0,
        sid = 0,
        career=0,
        scene = 0,
        x = 0,
        y = 0,
        hp = 0,
        hp_lim = 0,
        mp = 0,
        mp_lim = 0,
        att = 0,             % 攻击
        def = 0,             % 防御
        hit = 0,             % 命中率
        dodge = 0,           % 躲避
        crit = 0,            % 暴击
        ten = 0,             % 坚韧
        lv = 1,
        guild_id = 0,        % 帮派ID
        guild_position = 0,  % 帮派职位
        pid_dungeon = none,  % 副本进程
        speed = 0,	     % 移动速度
        pid_team = 0,        % 组队进程
        equip_current = [0,0,0],   % 当前装备类型ID - [武器, 衣服, 坐骑]
        equip = 1,           % 当前装备，1 装备一 2 装备二 3 装备三
        leader = 0,          % 是否队长
        sex = 0,
        battle_status = []   % 战斗状态
    }).

%% 场景数据结构
-record(ets_scene,
    {
        id = 0,              %% 场景唯一ID
        sid = 0,             %% 资源id
        name = <<>>,         %% 场景名称
        type = 0,            %% 场景类型(0:安全场景, 1:野外场景, 2:副本场景)
        x = 0,               %% 默认开始点
        y = 0,               %% 默认开始点
        elem=[],             %% 场景元素
        requirement = [],    %% 进入需求
        mask = "",
        npc = [],
        mon = [],
        safe
    }
).

-record(ets_mon, {
         id,
         name,
         scene,           %%所属场景
         mid,
         icon = 0,        %% 资源
         lv,
         hp,
         hp_lim,
         mp,
         mp_lim,
         hp_num,          %% 回血数值
         mp_num,          %% 回魔数值
         att,             %% 攻击
         def,             %% 防御值
         speed,           %% 移动速度
         att_speed,       %% 攻击速度
         hit = 0,         %% 命中
         dodge = 0,       %% 躲避
         crit = 0,        %% 暴击
         ten = 0,         %% 坚韧
         skill = [],      %% 技能
         att_area,        %% 攻击范围
         trace_area,      %% 追踪范围
         x,
         y,
         d_x,             %% 默认出生X
         d_y,             %% 默认出生y
         aid = none,      %% 怪物活动进程
         bid = none,      %% 战斗进程
         retime,          %% 重生时间
         type = 0,        %% 怪物类型（0被动，1主动）
         exp,             %% 怪物经验
         coin,            %% 怪物掉落铜钱
         drop_goods,      %% 怪物可掉落物品[{Goodsid1, DropRate1}, {Goodsid2, DropRate2}, ...]
         battle_status = []   %% 战斗状态
     }).

-record(ets_npc, {
        id = 0,
        nid = 0,
        icon = 0,         %% 资源
        name,
        scene,
        x,
        y,
        talk
}).

%%物品类型记录
-record(ets_goods_type, {
        goods_id,           %% 物品类型Id
        goods_name,         %% 物品名称
        type,               %% 物品类型, 1 装备类， 2 增益类，3 任务类 4 坐骑类
        subtype,            %% 物品子类型，
                            %% 装备子类型：1 武器，2 衣服，3 头盗，4 手套，5 鞋子，6 项链，7 戒指
                            %% 增益子类型：1 药品，2 经验
                            %% 坐骑子类型：1 一人坐骑 2 二人坐骑 3 三人坐骑
        equip_type=0,       %% 装备类型：0为无，1为武器，2为防具，3为饰品
        price_type=1,       %% 价格类型：1 铜钱, 2 银两，3 金币，4 绑定的铜钱
        price=0,            %% 购买价格
        sell_price=0,       %% 出售价格
        bind=0,             %% 是否绑定，0为不可绑定，1为可绑定还未绑定，2为可绑定已绑定
        trade=0,            %% 是否交易，1为不可交易，0为可交易
        sell=0,             %% 是否出售，1为不可出售，0为可出售
        isdrop=0,            %% 是否丢弃，1为不可丢弃，0为可丢弃
        level=0,            %% 等级限制
        career=0,           %% 职业限制，0为不限
        sex=0,              %% 性别限制，0为不限，1为男，2为女
        job=0,              %% 职位限制，0为不限
        forza_limit=0,      %% 力量需求，0为不限
        wit_limit=0,        %% 智力需求，0为不限
        agile_limit=0,      %% 敏捷需求，0为不限
        vitality = 0,       %% 体力
        spirit = 0,         %% 灵力
        hp = 0,             %% 基础属性 - 血量
        mp = 0,             %% 基础属性 - 内力
        forza=0,            %% 基础属性 - 力量
        wit=0,              %% 基础属性 - 智力
        agile=0,            %% 基础属性 - 敏捷
        att=0,              %% 基础属性 - 攻击
        def=0,              %% 基础属性 - 防御
        hit = 0,            %% 基础属性 - 命中
        dodge = 0,          %% 基础属性 - 躲避
        crit = 0,           %% 基础属性 - 暴击
        ten = 0,            %% 坚韧
        speed=0,            %% 基础属性 - 速度
        attrition=0,        %% 耐久度，0为永不磨损
        suit_id=0,          %% 套装ID，0为无
        max_hole=0,         %% 最大镶孔数
        max_stren=0,        %% 最大强化等级
        max_quality=0,      %% 最大品质数
        max_overlap=0,      %% 可叠加数，0为不可叠加
        color,              %% 物品颜色，0 白色，1 绿色，2 蓝色，3 紫色，4 橙色
        expire_time=0       %% 有效期，0为无
    }).

%%装备类型附加属性表
-record(ets_goods_add_attribute, {
        id,             %% 编号
        goods_id,       %% 物品类型ID
        attribute_id,   %% 属性类型Id
        value_type,     %% 属性值类型
        min_value,      %% 最小值
        max_value       %% 最大值
    }).

%%装备附加属性规则表
-record(ets_goods_attribute_rule, {
        id,             %% 编号
        goods_id,       %% 物品类型ID
        attribute_id,   %% 属性类型Id
        value,          %% 属性值
        factor,         %% 浮动系数
        ratio           %% 出现机率
    }).

%%装备品质升级规则表
-record(ets_goods_quality_upgrade, {
        id,             %% 编号
        goods_id,       %% 品质石物品类型Id，对应ets_goods_type.goods_id
        quality,        %% 装备品质
        ratio,          %% 成功率
        min_expected,   %% 最少品质石数
        max_expected,   %% 最多品质石数
        coin            %% 消耗铜钱数
    }).

%%装备品质拆除规则表
-record(ets_goods_quality_backout, {
        id,             %% 编号
        quality,        %% 装备品质
        ratio,          %% 机率
        goods_num,      %% 拆出的品质石个数
        goods_id,       %% 拆出的品质石物品编号ID
        coin            %% 消耗铜钱数
    }).

%%装备强化规则表
-record(ets_goods_strengthen, {
        id,             %% 编号
        goods_id,       %% 强化石物品类型Id，对应ets_goods_type.goods_id
        strengthen,     %% 装备强化等级
        ratio,          %% 成功率
        min_expected,   %% 最少强化石数
        max_expected,   %% 最大强化石数
        coin            %% 消耗铜钱数
    }).

%%宝石合成规则表
-record(ets_goods_compose, {
        id,             %% 编号
        goods_id,       %% 宝石物品类型Id，对应ets_goods_type.goods_id
        goods_num,      %% 宝石数量
        ratio,          %% 合成成功率
        new_id,         %% 合成新的宝石
        coin            %% 消耗铜钱数
    }).

%%宝石镶嵌规则表
-record(ets_goods_inlay, {
        id,             %% 编号
        goods_id,       %% 宝石物品类型Id，对应ets_goods_type.goods_id
        ratio,          %% 合成成功率
        coin,           %% 消耗铜钱数
        equip_types     %% 可以镶嵌的装备类型
    }).

%%物品掉落数量规则表
-record(ets_goods_drop_num, {
        id,             %% 编号
        mon_id,         %% 怪物编号
        drop_num,       %% 掉落个数
        ratio           %% 机率
    }).

%%物品掉落规则表
-record(ets_goods_drop_rule, {
        id,             %% 编号
        mon_id,         %% 怪物编号
        goods_id,       %% 物品类型编号
        type,           %% 物品类型
        goods_num,      %% 掉落数量
        ratio,          %% 掉落机率
        time_rule=[]    %% 掉落时间 [开始时间，结束时间]
    }).

%%商店表
-record(ets_shop, {
        id,             %% 编号
        shop_type,      %% 商店类型，1为商城，2为武器店，3为防具店，5为杂货店
        shop_subtype,   %% 商店子类型，如商城的子类：1为新品上市，2为最火热卖，3为特价优惠，4为普通，5为人物，6为宝石，7为宠物
        goods_id        %% 物品类型ID
    }).


%% 任务数据
-record(task,
    {
        id
        ,name = <<"">>
        ,desc = <<"">>			%% 描述

        %% 部分限制条件
        ,class = 0              %% 任务分类，0普通任务，1运镖任务，2帮会任务
        ,type = 0				%% 类型
        ,kind = 0				%% 种类
        ,level = 1				%% 需要等级
        ,repeat = 0				%% 可否重复
        ,realm = 0              %% 阵营
        ,career = 0				%% 职业限制
        ,prev = 0				%% 上一个必须完成的任务id

        ,start_item = []		%% 开始获得物品{ItemId, Number}
        ,end_item = []			%% 结束回收物品

        ,start_npc = 0			%% 开始npcid
        ,end_npc = 0			%% 结束npcid
        ,start_talk = 0		    %% 开始对话
        ,end_talk = 0			%% 结束对话
        ,unfinished_talk = 0 	%% 未完成对话

        ,condition = []			%% 条件内容	[{task, 任务id}, {item, 物品id, 物品数量}]
        ,content = []			%% 任务内容 [[State, 1, kill, NpcId, Num, NowNum], [State, 0, talk, NpcId, TalkId], [State, 0, item, ItemId, Num, NowNum]]
        ,state = 0      		%% 完成任务需要的状态值 state = length(content)

        %% 任务奖励
        ,exp = 0				%% 经验
        ,coin = 0				%% 金钱
        ,binding_coin = 0       %% 绑定金
        ,spt = 0                %% 灵力
        ,attainment	= 0			%% 修为
        ,contrib = 0			%% 贡献
        ,guild_exp = 0			%% 帮会经验

        ,award_select_item_num = 0%% 可选物品的个数
        ,award_item = []		%% 奖励物品
        ,award_select_item = [] %% 奖励可选物品
        ,award_gift = []		%% 礼包奖励

        ,start_cost = 0         %% 开始时是消耗铜币
        ,end_cost = 0 			%% 结束时消耗游戏币
        ,next = 0				%% 结束触发任务id
        ,next_cue = 0           %% 是否弹出结束npc的对话框
    }
).

%% 角色任务记录
-record(role_task,
    {
        id,
        role_id=0,
        task_id=0,
        trigger_time=0,
        state=0,
        end_state=0,
        mark=[]        %%任务记录器格式[State=int(),Finish=bool(), Type=atom((), ...]
    }
).

%% 角色任务历史记录
-record(role_task_log,
    {
        role_id=0,
        task_id=0,
        trigger_time=0,
        finish_time=0
    }
).

%%关系列表
-record(ets_rela, 
    {
        id = 0,         %%记录id
        idA = 0,        %%角色A的id
        idB = 0,        %%角色B的id
        rela = 0,       %%与B的关系(0:没关系1:好友2:黑名单3:仇人)
        intimacy = 0,   %%亲密度
        group = 1       %%B所在分组
    }
).

%%好友资料
-record(ets_rela_info, 
    {
        id = 0,             %%角色id
        nickname = [],      %%角色名字
        sex = 0,            %%角色性别
        lv = 0,             %%角色等级
        career = 0          %%角色职业
    }).

%%角色的初始好友分组
-record(ets_rela_set, 
    {
        id = 0,	            %%角色A的id
        name1 = <<"分组1">>,    %%三个分组的名字 {name1, name2, name3}
        name2 = <<"分组2">>,
        name3 = <<"分组3">>
    }
).

%% 排行榜
%% rank_list : [Object]（分三大类——1.人物属性排行、2.装备排行、3.帮会排行）
%%    Object : 1. [排名，角色ID，角色名，性别，职业，阵营，帮会，排行值]
%%             2. [排名，物品ID，物品名，所有者，帮会，装备评分]
%%             3. [排名，帮派ID，帮派名，阵营，等级]
-record(ets_rank, {
        type_id,            %% 排行类型ID
        rank_list           %% 排行信息列表
    }).

%%技能
-record(ets_skill, {
        id=0,
        name = <<>>,
        desc = <<>>,
        career = 0,       % 职业
        type = 0,         % 主，被，辅
        obj = 0,          % 释放目标
        mod = 0,          % 单体还是全体
        area = 0,         % 攻击范围，格子数
        cd = 0,           % CD时间
        lastime = 0,      % 持续时间
        attime = 0,       % 攻击次数，如攻击2次
        attarea = 0,      % 攻击距离
        limit = [],       % 限制使用的技能有
        data = []
    }).

%%##########OTHER#################
%%记录用户一些常用信息
-record(player_status, {
        id = 0,             % 用户ID
        accid = 0,          % 平台ID
        accname = [],       % 平台账号
        nickname = none,    % 玩家名
        sex = 0,            % 性别 1男 2女
        career = 0,         % 职业 1，2，3（分别是昆仑（战士），逍遥（法师），唐门（刺客））
        realm = 0,          % 阵营 天下盟、无双盟、傲世盟
        prestige = 0,       % 声望
        spirit = 0,         % 灵力
        jobs = 1,           % 职位
        pid = none,         % process id
        gold = 0,           % 金币
        silver = 0,         % 银币
        coin = 0,           % 铜钱
        bcoin = 0,          % 绑定的铜钱
        scene = 0,          % 场景ID,
        x = 0,
        y = 0,
        lv = 1,             % 等级
        hp = 0,
        mp = 0,
        hp_lim = 0,
        mp_lim = 0,
        forza = 0,          % 力量
        agile = 0,          % 敏捷
        wit = 0,            % 智力
        att = 0,            % 攻击
        def = 0,            % 防御
        hit = 0,            % 命中率
        dodge = 0,          % 躲避
        crit = 0,           % 暴击
        ten = 0,            % 坚韧
        base_attribute=[],  % 初始二级属性列表[Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten]
        two_attribute=[],   % 一级转二级属性列表[Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten]
        equip_attribute=[], % 装备加成属性列表[Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten]
        pet_attribute=[],   % 宠物属性列表[力量,智力,敏捷]
        att_area = 0,       % 攻击距离
        att_speed = 0,      % 攻击速度
        speed = 0,          % 移动速度
        hp_num = 0,         % 回血
        mp_num = 0,         % 回蓝
        cell_num = 100,     % 背包格子数
        mount = 0,          % 坐骑ID
        mount_spirit = [0,0], % 坐骑灵力消耗，[格子数，消耗灵力值]
        mount_spirit_cur = 0, % 坐骑累积走的格子数
        equip = 1,          % 当前装备，1 装备一 2 装备二 3 装备三
        equip_attrit = 0,   % 装备磨损数，下线则清零
        equip_current = [0,0,0], % 当前装备类型ID - [武器, 衣服, 坐骑]
        retime = 3000,
        goods_pid,          % 物品模块进程Pid
        mount_pid,          % 坐骑模块进程Pid
        exp = 0,
        exp_lim = 0,
        socket = none,
        sid = none,
        bid = none,          % 战斗进程
        guild_id = 0,        % 帮派ID
        guild_name = [],     % 帮派名称
        guild_position = 0,  % 帮派职位
        pid_dungeon = none,  % 副本进程
        pid_team = 0,        % 组队进程
        leader = 0,          % 是否队长，1为队长
        quickbar = [],       % 快捷栏
        skill = [],          % 技能
        online_flag = 0,     % 在线标记
        pet_upgrade_que_num = 0, % 宠物升级队列个数
        battle_status = []   % 战斗状态
    }).

%% 物品状态表
-record(goods_status, {
        player_id = 0,              % 用户ID
        null_cells = [],            % 背包空格子位置
        equip_current = [0,0,0],    % 当前装备类型ID - [武器, 衣服, 坐骑]
        equip_suit = [],            % 套装属性
        ct_time = 0                 % 使用药品的冷却时间
    }).

%% 帮派
-record(ets_guild, {
    id = 0,                        % 记录ID
    name = <<>>,                   % 帮派名称
    tenet = <<>>,                  % 帮派宣言
    announce = <<>>,               % 帮派公告
    initiator_id = 0,              % 创始人ID
    initiator_name = <<>>,         % 创始人名称
    chief_id = 0,                  % 现任帮主ID
    chief_name = <<>>,             % 现任帮主昵称
    deputy_chief1_id = 0,          % 副帮主1ID
    deputy_chief1_name = <<>>,     % 副帮主1昵称
    deputy_chief2_id = 0,          % 副帮主2ID
    deputy_chief2_name = <<>>,     % 副帮主2昵称
    deputy_chief_num = 0,          % 副帮主数
    member_num = 0,                % 当前成员数
    member_capacity = 0,           % 成员上限
    realm = 0,                     % 阵营
    level = 0,                     % 级别
    reputation = 0,                % 声望
    funds = 0,                     % 帮派资金
    contribution = 0,              % 建设值
    contribution_daily = 0,        % 每日收取的建设值
    contribution_threshold = 0,    % 建设值上限
    contribution_get_nexttime = 0, % 下次收取建设值时间
    combat_num = 0,                % 帮战次数
    combat_victory_num = 0,        % 帮战胜利次数
    qq = 0,                        % QQ群
    create_time = 0,               % 记录创建时间
    disband_flag = 0,              % 解散申请标记
    disband_confirm_time = 0,      % 解散申请的确认开始时间
    disband_deadline_time = 0      % 掉级后的自动解散时间
    }).

%% 帮派成员
-record(ets_guild_member, {
    id = 0,                       % 记录ID
    guild_id = 0,                 % 帮派ID
    guild_name = <<>>,            % 帮派名称
    player_id = 0,                % 角色ID
    player_name = <<>>,           % 角色昵称
    donate_total = 0,             % 总贡献
    donate_lasttime = 0,          % 最后贡献时间
    donate_total_lastday = 0,     % 日贡献
    donate_total_lastweek = 0,    % 周贡献
    paid_get_lasttime = 0,        % 日福利最后获取时间
    create_time = 0,              % 记录创建时间
    title = 0,                    % 帮派称号
    remark = 0,                   % 个人备注
    sex   = 0,                    % 性别
    honor = 0,                    % 荣誉
    jobs  = 0,                    % 职位
    level = 0,                    % 等级
    position = 0,                 % 帮派职位
    last_login_time = 0,          % 最后登录时间
    online_flag = 0,              % 是否在线
    career = 0                    % 职业
    }).

%% 帮派申请
-record(ets_guild_apply, {
    id = 0,                       % 记录ID
    guild_id = 0,                 % 帮派ID
    player_id = 0,                % 角色ID
    player_name = <<>>,           % 角色昵称
    player_sex   = 0,             % 性别
    player_jobs  = 0,             % 职位
    player_level = 0,             % 等级
    create_time = 0,              % 申请时间
    player_career = 0             % 职业
    }).

%% 帮派邀请
-record(ets_guild_invite, {
    id = 0,                       % 记录ID
    guild_id = 0,                 % 帮派ID
    player_id = 0,                % 角色ID
    create_time = 0               % 邀请时间
    }).

%% 宠物道具配置
-record(ets_base_pet, {
    goods_id = 0,
    goods_name = <<>>,
    name = <<>>,
    probability = 0
    }).

%% 宠物
-record(ets_pet, {
    id = 0,
    player_id = 0,
    type_id = 0,
    type_name = <<>>,
    name = <<>>,
    rename_count = 0,
    level = 0,
    quality = 0,
    forza = 0,
    wit = 0,
    agile = 0,
    base_forza = 0,
    base_wit = 0,
    base_agile = 0,
    base_forza_new = 0,
    base_wit_new = 0,
    base_agile_new = 0,
    aptitude_forza = 0,
    aptitude_wit = 0,
    aptitude_agile = 0,
    aptitude_threshold = 0,
    attribute_shuffle_count = 0,
    strength = 0,
    strength_daily_nexttime = 0,
    fight_flag = 0,
    fight_icon_pos = 0,
    upgrade_flag = 0,
    upgrade_endtime = 0,
    create_time = 0,
    strength_threshold = 0,
    strength_daily = 0,
    strength_nexttime = 0,
    forza_use = 0,
    wit_use   = 0,
    agile_use = 0
    }).

%%队伍资料
-record(team, 
    {
        leaderid = 0,       %% 队长id
        leaderpid= none,    %% 队长pid
        teamname = [],      %% 队名
        member = [],        %% 队员列表
        dungeon_pid=none    %% 副本进程id
    }
).

%%队员数据
-record(mb, 
    {
        id = 0,         %%队员id
        pid = none,     %%队员pid
        nickname = []   %%队员名字
    }
).

%% 副本数据
-record(dungeon,
    {
        id = 1,              %% 副本id
        name = <<"">>,       %% 副本名称
        def = 0,             %% 进入副本的默认场景
        out = {0, 0, 0},     %% 传出副本时场景和坐标{场景id, x, y}
        scene = [],          %% 整个副本所有的场景 {场景id, 是否激活}  只有激活的场景才能进入
        requirement = []     %% 场景的激活条件    [影响场景, 是否完成, kill, npcId, 需要数量, 现在数量]
    }
).
