%%%---------------------------------------
%%% @Module  : data_pet
%%% @Author  : shebiao
%%% @Email   : shebiao@jieyou.com
%%% @Created : 2010-06-24
%%% @Description:  宠物配置
%%%---------------------------------------
-module(data_pet).
-compile(export_all).

-record(pet_config, {
        % 宠物蛋类型[类型，子类型]
        egg_goods_type                = [30, 10],
        % 食物物品类型[类型，子类型]
        food_goods_type               = [30, 11],
        % 洗练物品类型[类型，子类型]
        attribute_shuffle_goods_type  = [30, 14],
        % 训练书物品类型[类型，子类型]
        attribute_book_goods_type     = [30, 13],
        % 进化石物品类型[类型，子类型]
        quality_stone_goods_type      = [30, 12],
        % 宠物容量
        capacity             = 16,
        % 资质上限[{品阶, 上限}]
        aptitude_threshold   = [{0, 500}, {1, 1500}, {2, 2500}],
        % 孵化后的默认级别
        default_level        = 1,
        % 孵化后的默认资质
        default_aptitude     = 0,
        % 孵化后的默认体力
        default_strenght     = 100,
        % 每日收取的体力值
        strength_daily       = 20,
        % 体力值上限
        strength_threshold   = 100,
        % 基础资质和
        base_attribute_sum   = 60,
        % 获得优惠的洗练次数
        lucky_shuffle_count  = 10,
        % 优惠洗练时的基础属性最小值
        lucky_base_attribute = 45,
        % 属性洗练所需银两
        shuffle_money        = 10,
        % 最大出战宠物数
        maxinum_fighting     = 3,
        % 出战图标位置列表
        fight_icon_pos_list  = [1, 2, 3],
        % 默认升级队列个数
        default_upgrade_que_num = 2,
        % 升级队列最大个数
        maxinum_que_num      = 5,
        % 扩展队列所需银两d
        extent_que_money     = [{3, 100}, {4, 200}, {5, 300}],
        % 最高级别
        maxinum_level        = 50,
        % 升级加速金币[每个单位的收费，每个单位所占的秒数]
        shorten_money_unit   = [1, 300],
        % 最高品阶数
        maxinum_quality      = 2,
        % 进阶的级数限制[{品阶，成功概率}]
        enhance_quality_probability= [{0, 80}, {1, 90}],
        % 角色死亡减少的体力值
        role_dead_strength   = 10,
        % 体力值同步
        strength_sync        = [10, 1],
        % 升级时间允许的误差
        upgrade_inaccuracy   = 3
}).

get_pet_config(Type, Args) ->
    PetConfig = #pet_config{},
    case Type of
        egg_goods_type       -> PetConfig#pet_config.egg_goods_type;
        food_goods_type      -> PetConfig#pet_config.food_goods_type;
        attribute_shuffle_goods_type   -> PetConfig#pet_config.attribute_shuffle_goods_type;
        attribute_book_goods_type -> PetConfig#pet_config.attribute_book_goods_type;
        quality_stone_goods_type -> PetConfig#pet_config.quality_stone_goods_type;
        capacity            -> PetConfig#pet_config.capacity;
        aptitude_threshold  ->
            [Quality] = Args,
            {value, {_, AptitudeThreshold}}  = lists:keysearch(Quality, 1, PetConfig#pet_config.aptitude_threshold),
            AptitudeThreshold;
        default_level       -> PetConfig#pet_config.default_level;
        default_aptitude    -> PetConfig#pet_config.default_aptitude;
        default_strenght    -> PetConfig#pet_config.default_strenght;
        strength_daily      -> PetConfig#pet_config.strength_daily;
        strength_threshold  -> PetConfig#pet_config.strength_threshold;
        base_attribute_sum  -> PetConfig#pet_config.base_attribute_sum;
        lucky_shuffle_count -> PetConfig#pet_config.lucky_shuffle_count;
        lucky_base_attribute -> PetConfig#pet_config.lucky_base_attribute;
        shuffle_money       -> PetConfig#pet_config.shuffle_money;
        maxinum_fighting    -> PetConfig#pet_config.maxinum_fighting;
        fight_icon_pos_list -> PetConfig#pet_config.fight_icon_pos_list;
        default_upgrade_que_num -> PetConfig#pet_config.default_upgrade_que_num;
        maxinum_que_num     -> PetConfig#pet_config.maxinum_que_num;
        extent_que_money    ->
            [QueNum] = Args,
            {value, {_, Money}}  = lists:keysearch(QueNum, 1, PetConfig#pet_config.extent_que_money),
            Money;
        maxinum_level       -> PetConfig#pet_config.maxinum_level;
        shorten_money_unit  -> PetConfig#pet_config.shorten_money_unit;
        maxinum_quality     -> PetConfig#pet_config.maxinum_quality;
        enhance_quality_probability ->
            [Quality] = Args,
            {value, {_, SuccessProbability}}  = lists:keysearch(Quality, 1, PetConfig#pet_config.enhance_quality_probability),
            SuccessProbability;
        role_dead_strength  -> PetConfig#pet_config.role_dead_strength;
        strength_sync       -> PetConfig#pet_config.strength_sync;
        upgrade_inaccuracy  -> PetConfig#pet_config.upgrade_inaccuracy
    end.

get_upgrade_info(Quality, Level) ->
    case Quality of
        0 ->
            UpgradeInfo = [{1,400,7.5},
                           {2,402,30.0},
                           {3,407,67.5},
                           {4,416,120.0},
                           {5,431,187.5},
                           {6,454,270.0},
                           {7,486,367.5},
                           {8,528,480.0},
                           {9,582,607.5},
                           {10,650,750.0},
                           {11,733,907.5},
                           {12,832,1080.0},
                           {13,949,1267.5},
                           {14,1086,1470.0},
                           {15,1244,1687.5},
                           {16,1424,1920.0},
                           {17,1628,2167.5},
                           {18,1858,2430.0},
                           {19,2115,2707.5},
                           {20,2400,3000.0},
                           {21,2715,3307.5},
                           {22,3062,3630.0},
                           {23,3442,3967.5},
                           {24,3856,4320.0},
                           {25,4306,4687.5},
                           {26,4794,5070.0},
                           {27,5321,5467.5},
                           {28,5888,5880.0},
                           {29,6497,6307.5},
                           {30,7150,6750.0},
                           {31,15296,7207.5},
                           {32,16784,7680.0},
                           {33,18369,8167.5},
                           {34,20052,8670.0},
                           {35,21838,9187.5},
                           {36,23728,9720.0},
                           {37,25727,10267.5},
                           {38,27836,10830.0},
                           {39,30060,11407.5},
                           {40,32400,12000.0},
                           {41,34861,12607.5},
                           {42,37444,13230.0},
                           {43,40154,13867.5},
                           {44,42992,14520.0},
                           {45,45963,15187.5},
                           {46,49068,15870.0},
                           {47,52312,16567.5},
                           {48,55696,17280.0},
                           {49,59225,18007.5},
                           {50,62900,18750.0}],
            {value, {_, UpgradeMoney, UpgradeTime}} = lists:keysearch(Level, 1, UpgradeInfo),
            [UpgradeMoney, util:ceil(UpgradeTime)];
        1 ->
            UpgradeInfo = [{1,600,45},
                           {2,603,90},
                           {3,609,165},
                           {4,621,270},
                           {5,642,405},
                           {6,672,570},
                           {7,714,765},
                           {8,771,990},
                           {9,843,1245},
                           {10,933,1530},
                           {11,1044,1845},
                           {12,1176,2190},
                           {13,1332,2565},
                           {14,1515,2970},
                           {15,1725,3405},
                           {16,1965,3870},
                           {17,2238,4365},
                           {18,2544,4890},
                           {19,2886,5445},
                           {20,3267,6030},
                           {21,3687,6645},
                           {22,4149,7290},
                           {23,4656,7965},
                           {24,5208,8670},
                           {25,5808,9405},
                           {26,6459,10170},
                           {27,7161,10965},
                           {28,7917,11790},
                           {29,8730,12645},
                           {30,9600,13530},
                           {31,10530,14445},
                           {32,11523,15390},
                           {33,12579,16365},
                           {34,13701,17370},
                           {35,14892,18405},
                           {36,16152,19470},
                           {37,17484,20565},
                           {38,18891,21690},
                           {39,20373,22845},
                           {40,21933,24030},
                           {41,46547,25245},
                           {42,49992,26490},
                           {43,53605,27765},
                           {44,57389,29070},
                           {45,61350,30405},
                           {46,65491,31770},
                           {47,69815,33165},
                           {48,74328,34590},
                           {49,79033,36045},
                           {50,83933,37530}],
            {value, {_, UpgradeMoney, UpgradeTime}} = lists:keysearch(Level, 1, UpgradeInfo),
            [UpgradeMoney, util:ceil(UpgradeTime)];
        2 ->
            UpgradeInfo = [{1,801,61},
                           {2,808,68},
                           {3,827,87},
                           {4,864,124},
                           {5,925,185},
                           {6,1016,276},
                           {7,1143,403},
                           {8,1312,572},
                           {9,1529,789},
                           {10,1800,1060},
                           {11,2131,1391},
                           {12,2528,1788},
                           {13,2997,2257},
                           {14,3544,2804},
                           {15,4175,3435},
                           {16,4896,4156},
                           {17,5713,4973},
                           {18,6632,5892},
                           {19,7659,6919},
                           {20,8800,8060},
                           {21,10061,9321},
                           {22,11448,10708},
                           {23,12967,12227},
                           {24,14624,13884},
                           {25,16425,15685},
                           {26,18376,17636},
                           {27,20483,19743},
                           {28,22752,22012},
                           {29,25189,24449},
                           {30,27800,27060},
                           {31,30591,29851},
                           {32,33568,32828},
                           {33,36737,35997},
                           {34,40104,39364},
                           {35,43675,42935},
                           {36,47456,46716},
                           {37,51453,50713},
                           {38,55672,54932},
                           {39,60119,59379},
                           {40,64800,64060},
                           {41,69721,68981},
                           {42,74888,74148},
                           {43,80307,79567},
                           {44,85984,85244},
                           {45,91925,91185},
                           {46,98136,97396},
                           {47,104623,103883},
                           {48,111392,110652},
                           {49,118449,117709},
                           {50,125800,125060}],
            {value, {_, UpgradeMoney, UpgradeTime}} = lists:keysearch(Level, 1, UpgradeInfo),
            [UpgradeMoney, util:ceil(UpgradeTime)]
    end.

get_rename_money(RenameCount) ->
    2*RenameCount.

get_food_strength(PetQuality, FoodQuality) ->
    case FoodQuality of
        0 ->
            StrengthInfo = [{0, 5}],
            {value, {_, Strength}} = lists:keysearch(PetQuality, 1, StrengthInfo),
            Strength;
        1 ->
            StrengthInfo = [{0, 10}, {1, 5}],
            {value, {_, Strength}} = lists:keysearch(PetQuality, 1, StrengthInfo),
            Strength;
        2 ->
            StrengthInfo = [{0, 15}, {1, 10}, {2 ,5}],
            {value, {_, Strength}} = lists:keysearch(PetQuality, 1, StrengthInfo),
            Strength
    end.
