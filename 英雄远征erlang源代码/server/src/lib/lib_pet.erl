%%%--------------------------------------
%%% @Module  : lib_pet
%%% @Author  : shebiao
%%% @Email   : shebiao@jieyou.com
%%% @Created : 2010.07.03
%%% @Description : 宠物信息
%%%--------------------------------------
-module(lib_pet).
-include("common.hrl").
-include("record.hrl").
-compile(export_all).

%%=========================================================================
%% SQL定义
%%=========================================================================

%% -----------------------------------------------------------------
%% 角色表SQL
%% -----------------------------------------------------------------
-define(SQL_PLAYER_UPDATE_DEDUCT_GOLD,       "update player set gold = gold-~p where id = ~p").
-define(SQL_PLAYER_UPDATE_EXTENT_QUE,        "update player set gold = gold-~p, pet_upgrade_que_num=~p where id = ~p").
-define(SQL_PLAYER_UPDATE_DEDUCT_COIN,       "update player set coin = coin-~p where id=~p").

%% -----------------------------------------------------------------
%% 宠物表SQL
%% -----------------------------------------------------------------
-define(SQL_PET_INSERT,                      "insert into pet(player_id,type_id,type_name,name,level,quality,forza,wit,agile,base_forza,base_wit,base_agile,aptitude_threshold,strength, strength_daily, strength_threshold,create_time, strength_daily_nexttime) "
                                             "values(~p,~p,'~s','~s',~p,~p,~p,~p,~p,~p,~p,~p,~p,~p,~p,~p,~p, ~p)").
                                     
-define(SQL_PET_SELECT_ALL_PET,              "select id,player_id,type_id,type_name,name,rename_count,level,quality,forza,wit,agile,base_forza,base_wit,base_agile,base_forza_new,base_wit_new,base_agile_new,aptitude_forza,aptitude_wit,aptitude_agile,aptitude_threshold,attribute_shuffle_count,strength,strength_daily_nexttime,fight_flag,fight_icon_pos,upgrade_flag,upgrade_endtime,create_time,strength_threshold,strength_daily from pet where player_id=~p").
-define(SQL_PET_SELECT_INCUBATE_PET,         "select id,player_id,type_id,type_name,name,rename_count,level,quality,forza,wit,agile,base_forza,base_wit,base_agile,base_forza_new,base_wit_new,base_agile_new,aptitude_forza,aptitude_wit,aptitude_agile,aptitude_threshold,attribute_shuffle_count,strength,strength_daily_nexttime,fight_flag,fight_icon_pos,upgrade_flag,upgrade_endtime,create_time,strength_threshold,strength_daily from pet where player_id=~p and type_id=~p and create_time=~p order by id desc limit 1").

-define(SQL_PET_UPDATE_RENAME_INFO,          "update pet set name = '~s', rename_count = rename_count+1 where id = ~p").
-define(SQL_PET_UPDATE_FIGHT_FLAG,           "update pet set fight_flag = ~p, fight_icon_pos = ~p where id = ~p").
-define(SQL_PET_UPDATE_SHUTTLE_INFO,         "update pet set attribute_shuffle_count=attribute_shuffle_count+1, base_forza_new=~p, base_wit_new=~p, base_agile_new = ~p where id = ~p").
-define(SQL_PET_UPDATE_USE_ATTRIBUTE,        "update pet set forza=~p, wit=~p, agile=~p, base_forza=~p, base_wit=~p, base_agile=~p, base_forza_new=0, base_wit_new=0, base_agile_new =0 where id = ~p").
-define(SQL_PET_UPDATE_LEVEL,                "update pet set level=~p, upgrade_flag=~p, upgrade_endtime=~p, forza=~p, wit=~p, agile=~p where id=~p").
-define(SQL_PET_UPDATE_UPGRADE_INFO,         "update pet set upgrade_flag=~p, upgrade_endtime=~p where id=~p").
-define(SQL_PET_UPDATE_STRENGTH,             "update pet set strength=~p,forza=~p, wit=~p, agile=~p where id=~p").
-define(SQL_PET_UPDATE_FORZA,                "update pet set forza=~p, aptitude_forza=~p where id=~p").
-define(SQL_PET_UPDATE_WIT,                  "update pet set wit=~p, aptitude_wit=~p where id=~p").
-define(SQL_PET_UPDATE_AGILE,                "update pet set agile=~p, aptitude_agile=~p where id=~p").
-define(SQL_PET_UPDATE_QUALITY,              "update pet set quality=~p, aptitude_threshold=~p, level=~p where id=~p").
-define(SQL_PET_UPDATE_STRENGTH_DAILY,       "update pet set strength=~p, forza=~p, wit=~p, agile=~p, strength_daily_nexttime=~p where id=~p").
-define(SQL_PET_UPDATE_LOGIN,                "update pet set level=~p, upgrade_flag=~p, upgrade_endtime=~p, strength=~p, forza=~p, wit=~p, agile=~p, strength_daily_nexttime=~p where id=~p").

-define(SQL_PET_DELETE,                      "delete from pet where id = ~p").
-define(SQL_PET_DELETE_ROLE,                 "delete from pet where player_id = ~p").

%% -----------------------------------------------------------------
%% 宠物道具表SQL
%% -----------------------------------------------------------------
-define(SQL_BASE_PET_SELECT_ALL,             "select goods_id, goods_name, name, probability from base_pet").

%%=========================================================================
%% 初始化回调函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 系统启动后的加载
%% -----------------------------------------------------------------
load_base_pet() ->
    SQL  = io_lib:format(?SQL_BASE_PET_SELECT_ALL, []),
    ?DEBUG("load_base_pet: SQL=[~s]", [SQL]),
    BasePetList = db_sql:get_all(SQL),
    lists:map(fun load_base_pet_into_ets/1, BasePetList),
    ?DEBUG("load_base_pet: [~p] base_pet loaded", [length(BasePetList)]).

load_base_pet_into_ets([GoodsId,GoodsName,Name,Probability]) ->
    BasePet = #ets_base_pet{
        goods_id = GoodsId,
        goods_name = GoodsName,
        name = Name,
        probability = Probability},
    update_base_pet(BasePet).

%% -----------------------------------------------------------------
%% 登录后的初始化
%% -----------------------------------------------------------------
role_login(PlayerId) ->
    ?DEBUG("role_login: Loading pets...", []),
    % 加载所有宠物
    PetNum = load_all_pet(PlayerId),
    FightingPet = get_fighting_pet(PlayerId),
    ?DEBUG("role_login: All pet num=[~p], fighting pet num=[~p]", [PetNum, length(FightingPet)]),
    % 计算出战宠物的属性和
    calc_pet_attribute_sum(FightingPet).

calc_pet_attribute_sum(Pets) ->
    calc_pet_attribute_sum_helper(Pets, 0, 0, 0).
calc_pet_attribute_sum_helper([], TotalForza, TotalWit, TotalAgile) ->
    [TotalForza, TotalWit, TotalAgile];
calc_pet_attribute_sum_helper(Pets, TotalForza, TotalWit, TotalAgile) ->
    [Pet|PetLeft] = Pets,
    calc_pet_attribute_sum_helper(PetLeft, TotalForza+Pet#ets_pet.forza_use, TotalWit+Pet#ets_pet.wit_use, TotalAgile+Pet#ets_pet.agile_use).

load_all_pet(PlayerId) ->
    Data = [PlayerId],
    SQL  = io_lib:format(?SQL_PET_SELECT_ALL_PET, Data),
    ?DEBUG("load_all_pet: SQL=[~s]", [SQL]),
    PetList = db_sql:get_all(SQL),
    lists:map(fun load_pet_into_ets/1, PetList),
    length(PetList).

load_pet_into_ets([Id,PlayerId,TypeId,TypeName,Name,RenameCount,Level,Quality,_Forza,_Wit,_Agile,BaseForza,BaseWit,BaseAgile,BaseForzaNew,BaseWitNew,BaseAgileNew,AptitudeForza,AptitudeWit,AptitudeAgile,AptitudeThreshold,AttributeShuffleCount,Strength,StrengthDailyNextTime,FightFlag,FightIconPos,UpgradeFlag,UpgradeEndTime,CreateTime,StrengthThreshold,StrengthDaily]) ->
    % 1- 计算出战宠物的下次体力值同步时间
    NowTime            = util:unixtime(),
    [IntervalSync, _StrengthSync] = data_pet:get_pet_config(strength_sync, []),
    StrengthNextTime   = case FightFlag of
                             0 -> 0;
                             1 -> NowTime+IntervalSync;
                             _ -> ?ERR("load_pet_into_ets: Unknow fight flag, flag=[~p]", FightFlag), 0
                         end,
    % 2- 收取每日体力
    [StrengthNew, StrengthDailyNextTimeNew] = calc_strength_daily(NowTime, StrengthDailyNextTime, Strength, StrengthDaily),
    % 3- 升级完成检测
    [LevelNew,UpgradeFlagNew,UpgradeEndTimeNew] = case is_upgrade_finish(UpgradeFlag, UpgradeEndTime) of
          % 升级标志为真且已升完
          true  -> [Level+1, 0, 0];
          % 其他情况
          false -> [Level, UpgradeFlag,UpgradeEndTime]
    end,
    % 4- 重新计算属性值
    AptitudeAttributes = [AptitudeForza,AptitudeWit,AptitudeAgile],
    BaseAttributes     = [BaseForza,BaseWit,BaseAgile],
    [ForzaUse, WitUse, AgileUse] = calc_pet_attribute(AptitudeAttributes, BaseAttributes, LevelNew, StrengthNew),
    [ForzaNew, WitNew, AgileNew] = calc_pet_client_attribute([ForzaUse, WitUse, AgileUse]),
    % 5- 如果收取了每日体力或检测到升级则更新数据库
    if  ((StrengthNew /= Strength)  or (LevelNew > Level)) ->
            SQLData = [LevelNew,UpgradeFlagNew,UpgradeEndTimeNew,StrengthNew, ForzaNew, WitNew, AgileNew, StrengthDailyNextTimeNew, Id],
            SQL = io_lib:format(?SQL_PET_UPDATE_LOGIN, SQLData),
            ?DEBUG("load_pet_into_ets: SQL=[~s]", [SQL]),
            db_sql:execute(SQL);
        true ->
            void
    end,
    % 6- 插入缓存
    Pet = #ets_pet{
        id = Id,
        player_id = PlayerId,
        type_id = TypeId,
        type_name = TypeName,
        name = Name,
        rename_count = RenameCount,
        level = LevelNew,
        quality = Quality,
        forza = ForzaNew,
        wit   = WitNew,
        agile = AgileNew,
        base_forza = BaseForza,
        base_wit = BaseWit,
        base_agile = BaseAgile,
        base_forza_new = BaseForzaNew,
        base_wit_new = BaseWitNew,
        base_agile_new = BaseAgileNew,
        aptitude_forza = AptitudeForza,
        aptitude_wit = AptitudeWit,
        aptitude_agile = AptitudeAgile,
        aptitude_threshold = AptitudeThreshold,
        attribute_shuffle_count = AttributeShuffleCount,
        strength = StrengthNew,
        strength_daily_nexttime = StrengthDailyNextTimeNew,
        fight_flag = FightFlag,
        fight_icon_pos = FightIconPos,
        upgrade_flag = UpgradeFlagNew,
        upgrade_endtime = UpgradeEndTimeNew,
        create_time = CreateTime,
        strength_threshold = StrengthThreshold,
        strength_daily = StrengthDaily,
        strength_nexttime = StrengthNextTime,
        forza_use = ForzaUse,
        wit_use   = WitUse,
        agile_use = AgileUse},
    update_pet(Pet).

%% -----------------------------------------------------------------
%% 退出后的存盘
%% -----------------------------------------------------------------
role_logout(PlayerId) ->
    % 保存宠物数据
    PetList = get_all_pet(PlayerId),
    lists:map(fun save_pet/1, PetList),
    % 删除所有缓存宠物
    delete_all_pet(PlayerId).

save_pet(Pet) ->
    Data = [Pet#ets_pet.strength, Pet#ets_pet.forza, Pet#ets_pet.wit, Pet#ets_pet.agile, Pet#ets_pet.id],
    SQL = io_lib:format(?SQL_PET_UPDATE_STRENGTH, Data),
%    ?DEBUG("save_pet: SQL=[~s]", [SQL]),
    db_sql:execute(SQL).

%%=========================================================================
%% 业务操作函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 孵化宠物
%% -----------------------------------------------------------------
incubate_pet(PlayerId, GoodsType) ->
    ?DEBUG("incubate_pet: PlayerId=[~p], GoodsTypeId=[~p]", [PlayerId, GoodsType#ets_goods_type.goods_id]),
    % 解析物品类型
    TypeId     = GoodsType#ets_goods_type.goods_id,
    %PetName    = GoodsType#ets_goods_type.goods_name,
    BasePet    = get_base_pet(TypeId),
    PetName = case BasePet of
                [] -> ?ERR("incubate_pet: Not find the base_pet, goods_id=[~p]", [TypeId]),
                      make_sure_binary("我的宠物");
                _ ->  BasePet#ets_base_pet.name
               end,
    PetQuality = GoodsType#ets_goods_type.color,
    % 获取配置
    AptitudeThreshold = data_pet:get_pet_config(aptitude_threshold, [PetQuality]),
    DefaultAptitude   = data_pet:get_pet_config(default_aptitude, []),
    DefaultLevel      = data_pet:get_pet_config(default_level, []),
    DefaultStrength   = data_pet:get_pet_config(default_strenght, []),
    StrengthThreshold = data_pet:get_pet_config(strength_threshold, []),
    StrengthDaily     = data_pet:get_pet_config(strength_daily, []),
    % 随机获得基础属性
    [BaseForza,BaseWit,BaseAgile] = generate_base_attribute(),    
    % 计算属性值
    AptitudeAttributes           = [DefaultAptitude,DefaultAptitude,DefaultAptitude],
    BaseAttributes               = [BaseForza,BaseWit,BaseAgile],
    [ForzaUse, WitUse, AgileUse] = calc_pet_attribute(AptitudeAttributes, BaseAttributes, DefaultLevel, DefaultStrength),
    [Forza, Wit, Agile]          = calc_pet_client_attribute([ForzaUse, WitUse, AgileUse]),
    % 插入宠物
    CreateTime            = util:unixtime(),
    StrengthDailyNextTime = CreateTime+(?ONE_DAY_SECONDS), 
    Data = [PlayerId, TypeId, PetName, PetName, DefaultLevel] ++
        [PetQuality, Forza, Wit, Agile, BaseForza, BaseWit, BaseAgile] ++
        [AptitudeThreshold, DefaultStrength, StrengthDaily, StrengthThreshold, CreateTime, StrengthDailyNextTime],
    SQL = io_lib:format(?SQL_PET_INSERT, Data),
    ?DEBUG("incubate_pet: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 获取新孵化的宠物
    Data1 = [PlayerId, TypeId, CreateTime],
    SQL1  = io_lib:format(?SQL_PET_SELECT_INCUBATE_PET, Data1),
    ?DEBUG("incubate_pet: SQL=[~s]", [SQL1]),
    IncubateInfo = db_sql:get_row(SQL1),
    case IncubateInfo of
        % 孵化失败
        [] ->
            ?ERR("incubate_pet: Failed to incubated pet, PlayerId=[~p], TypeId=[~p], CreateTime=[~p]", [PlayerId, TypeId, CreateTime]),
            0;
        % 孵化成功
        _ ->
            % 更新缓存
            load_pet_into_ets(IncubateInfo),
            % 返回值
            [PetId| _] = IncubateInfo,
            Pet = get_pet(PlayerId, PetId),
            ?DEBUG("incubate_pet: Cache was upate, PetId=[~p]", [Pet#ets_pet.id]),
            [ok, PetId, PetName]
    end.
    

%% -----------------------------------------------------------------
%% 宠物放生
%% -----------------------------------------------------------------
free_pet(PetId) ->
    % 删除宠物
    ?DEBUG("free_pet: PetId=[~p]", [PetId]),
    SQL = io_lib:format(?SQL_PET_DELETE, [PetId]),
    ?DEBUG("free_pet: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 更新缓存
    delete_pet(PetId),
    ok.

%% -----------------------------------------------------------------
%% 宠物改名
%% -----------------------------------------------------------------
rename_pet(PetId, PetName, PlayerId, RenameMoney) ->    
    ?DEBUG("rename_pet: PetId=[~p], PetName=[~p], PlayerId=[~p], ModifyMoney=[~p]", [PetId, PetName, PlayerId, RenameMoney]),
    % 更新宠物名
    Data = [PetName, PetId],
    SQL = io_lib:format(?SQL_PET_UPDATE_RENAME_INFO, Data),
    ?DEBUG("rename_pet: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    if RenameMoney > 0 ->
            Data1 = [RenameMoney, PlayerId],
            SQL1 = io_lib:format(?SQL_PLAYER_UPDATE_DEDUCT_GOLD, Data1),
            ?DEBUG("rename_pet: SQL=[~s]", [SQL1]),
            db_sql:execute(SQL1);
        true ->
            void
    end,
    ok.

%% -----------------------------------------------------------------
%% 宠物出战
%% -----------------------------------------------------------------
fighting_pet(PetId, FightingPet, FightIconPos) ->
    ?DEBUG("fighting_pet: PetId=[~p], FightingPet=[~p], FightIconPos=[~p]", [PetId, FightingPet, FightIconPos]),
    % 计算出战图标位置
    IconPos = case FightIconPos of
                  0 -> calc_fight_icon_pos(FightingPet);
                  1 -> 1;
                  2 -> 2;
                  3 -> 3;
                  _ -> ?ERR("fighting_pet: Unknow fight icon pos = [~p]", [FightIconPos]), 0
              end,
    % 更新宠物
    if  ((IconPos >= 1) and (IconPos =< 3)) ->
            Data = [1, IconPos, PetId],
            SQL = io_lib:format(?SQL_PET_UPDATE_FIGHT_FLAG, Data),
            ?DEBUG("fighting_pet: SQL=[~s]", [SQL]),
            db_sql:execute(SQL),
            [ok, IconPos];
        true ->
            error
    end.

calc_fight_icon_pos(FightingPet) ->
    IconPosList         = data_pet:get_pet_config(fight_icon_pos_list,[]),
    FilteredIconPosList = filter_fight_icon_pos(FightingPet, IconPosList),
    case length(FilteredIconPosList) of
        0 -> 0;
        _ -> lists:nth(1, FilteredIconPosList)
    end.

filter_fight_icon_pos([], IconPosList) ->
    IconPosList;
filter_fight_icon_pos(FightingPet, IconList) ->
    [Pet|PetLeft] = FightingPet,
    filter_fight_icon_pos(PetLeft, lists:delete(Pet#ets_pet.fight_icon_pos, IconList)).

%% -----------------------------------------------------------------
%% 宠物休息
%% -----------------------------------------------------------------
rest_pet(PetId) ->
    ?DEBUG("rest_pet: PetId=[~p]", [PetId]),
    Data = [0, 0, PetId],
    SQL = io_lib:format(?SQL_PET_UPDATE_FIGHT_FLAG, Data),
    ?DEBUG("rest_pet: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    ok.

%% -----------------------------------------------------------------
%% 属性洗练
%% -----------------------------------------------------------------
shuffle_attribute(PlayerId, PetId, PayType, ShuffleCount, GoodsId, MoneyGoodsNum, MoneyGoodsUseNum) ->
    ?DEBUG("shuffle_attribute: PlayerId=[~p],PetId=[~p],PayType=[~p],ShuffleCount=[~p],GoodsId=[~p],MoneyGoodsNum=[~p],MoneyGoodsUseNum=[~p]", [PlayerId, PetId, PayType, ShuffleCount, GoodsId, MoneyGoodsNum, MoneyGoodsUseNum]),
    % 生成新基础属性
    [BaseForza, BaseWit, BaseAgile] = generate_base_attribute(ShuffleCount),
    % 更新新基础属性和洗练次数
    Data = [BaseForza, BaseWit, BaseAgile, PetId],
    SQL = io_lib:format(?SQL_PET_UPDATE_SHUTTLE_INFO, Data),
    ?DEBUG("shuffle_attribute: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    case PayType of
        0 ->
            % 扣取金币
            Data1 = [MoneyGoodsUseNum, PlayerId],
            SQL1 = io_lib:format(?SQL_PLAYER_UPDATE_DEDUCT_GOLD, Data1),
            ?DEBUG("shuffle_attribute: SQL=[~s]", [SQL1]),
            db_sql:execute(SQL1);
        _ ->
            void
    end,
    [ok, BaseForza, BaseWit, BaseAgile].

%% -----------------------------------------------------------------
%% 洗练属性使用
%% -----------------------------------------------------------------
use_attribute(PetId, BaseForza, BaseWit, BaseAgile, AptitudeForza, AptitudeWit, AptitudeAgile, Level, Stength) ->
    ?DEBUG("use_attribute: PetId=[~p], BaseForza=[~p], BaseWit=[~p], BaseAgile=[~p], AptitudeForza=[~p], AptitudeWit=[~p], AptitudeAgile=[~p], Level=[~p], Stength=[~p]", [PetId, BaseForza, BaseWit, BaseAgile, AptitudeForza, AptitudeWit, AptitudeAgile, Level, Stength]),
    % 计算属性值
    AptitudeAttributes           = [AptitudeForza, AptitudeWit, AptitudeAgile],
    BaseAttributes               = [BaseForza,BaseWit,BaseAgile],
    [ForzaUse, WitUse, AgileUse] = calc_pet_attribute(AptitudeAttributes, BaseAttributes, Level, Stength),
    [Forza, Wit, Agile]          = calc_pet_client_attribute([ForzaUse, WitUse, AgileUse]),
    ?DEBUG("use_attribut: ForzaUse=[~p], WitUse=[~p], AgileUse=[~p], Forza=[~p], Wit=[~p], Agile=[~p]", [ForzaUse, WitUse, AgileUse, Forza, Wit, Agile]),
    % 更新属性
    Data = [Forza, Wit, Agile, BaseForza, BaseWit, BaseAgile, PetId],
    SQL = io_lib:format(?SQL_PET_UPDATE_USE_ATTRIBUTE, Data),
    ?DEBUG("use_attribute: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    [ok, Forza, Wit, Agile, ForzaUse, WitUse, AgileUse].


%% -----------------------------------------------------------------
%% 宠物开始升级
%% -----------------------------------------------------------------
pet_start_upgrade(PlayerId, PetId, UpgradeEndTime, UpgradeMoney) ->
    ?DEBUG("pet_start_upgrade: PlayerId=[~p], PetId=[~p], UpgradeEndTime=[~p], UpgradeMoney=[~p]", [PlayerId, PetId, UpgradeEndTime, UpgradeMoney]),
    % 更新升级信息
    Data = [1, UpgradeEndTime, PetId],
    SQL = io_lib:format(?SQL_PET_UPDATE_UPGRADE_INFO, Data),
    ?DEBUG("pet_start_upgrade: SQL=[~s]", [SQL]),
    % 扣除铜币
    db_sql:execute(SQL),
    Data1 = [UpgradeMoney, PlayerId],
    SQL1 = io_lib:format(?SQL_PLAYER_UPDATE_DEDUCT_COIN, Data1),
    ?DEBUG("shorten_upgrade: SQL=[~s]", [SQL1]),
    db_sql:execute(SQL1),
    ok.

%% -----------------------------------------------------------------
%% 宠物升级加速
%% -----------------------------------------------------------------
shorten_upgrade(PlayerId, PetId, UpgradeEndTime, ShortenMoney) ->
    ?DEBUG("shorten_upgrade: PlayerId=[~p], PetId=[~p], UpgradeEndTime=[~p], ShortenMoney=[~p]", [PlayerId, PetId, UpgradeEndTime, ShortenMoney]),
    % 更新升级信息
    Data = [1, UpgradeEndTime, PetId],
    SQL = io_lib:format(?SQL_PET_UPDATE_UPGRADE_INFO, Data),
    ?DEBUG("shorten_upgrade: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 扣除金币
    Data1 = [ShortenMoney, PlayerId],
    SQL1 = io_lib:format(?SQL_PLAYER_UPDATE_DEDUCT_GOLD, Data1),
    ?DEBUG("shorten_upgrade: SQL=[~s]", [SQL1]),
    db_sql:execute(SQL1),
    ok.

%% -----------------------------------------------------------------
%% 检查宠物升级状态
%% @return 不在升级：[0,升级剩余时间],
%%          还在升级：[1,升级剩余时间],
%%          升完级：  [2,升级剩余时间, 新级别，新力量，新智慧，新敏捷,新力量(加成用)，新智慧(加成用)，新敏捷(加成用)]
%% -----------------------------------------------------------------
check_upgrade_state(PlayerId, PetId, Level,  Strength, UpgradeFlag, UpgradeEndTime, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile, UpgradeMoney) ->
    ?DEBUG("check_upgrade_state: PlayerId=[~p], PetId=[~p], Level=[~p],  Strength=[~p], UpgradeFlag=[~p], UpgradeEndTime=[~p], AptitudeForza=[~p], AptitudeWit=[~p], AptitudeAgile=[~p], BaseForza=[~p], BaseWit=[~p], BaseAgile=[~p],UpgradeMoney=[~p]", [PlayerId, PetId, Level,  Strength, UpgradeFlag, UpgradeEndTime, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile, UpgradeMoney]),
    case UpgradeFlag of
        % 不在升级
        0 ->
            [0, 0];
        % 在升级
        1->
            NowTime           = util:unixtime(),
            UpgradeInaccuracy = data_pet:get_pet_config(upgrade_inaccuracy, []),
            UpgradeLeftTime   = abs(UpgradeEndTime-NowTime),
            if  % 已经升完级
                ((NowTime >= UpgradeEndTime) or (UpgradeLeftTime < UpgradeInaccuracy)) ->
                    case pet_finish_upgrade(PlayerId, PetId, Level, Strength, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile, UpgradeMoney) of
                        [ok, NewLevel, NewForza, NewWit, NewAgile, NewForzaUse, NewWitUse, NewAgileUse] -> [2, 0, NewLevel,NewForza, NewWit, NewAgile, NewForzaUse, NewWitUse, NewAgileUse];
                        _ -> error
                    end;
                % 还未升完级
                true ->
                    [1, UpgradeLeftTime]
            end
    end.

%% -----------------------------------------------------------------
%% 宠物完成升级
%% -----------------------------------------------------------------
pet_finish_upgrade(PlayerId, PetId, Level, Strength, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile, UpgradeMoney) ->
    ?DEBUG("pet_finish_upgrade: PlayerId=[~p], PetId=[~p], Level=[~p], Strength=[~p], AptitudeForza=[~p], AptitudeWit=[~p], AptitudeAgile=[~p], BaseForza=[~p], BaseWit=[~p], BaseAgile=[~p], UpgradeMoney=[~p]", [PlayerId, PetId, Level, Strength, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile, UpgradeMoney]),
    NewLevel       = Level + 1,
    % 计算属性值
    AptitudeAttributes           = [AptitudeForza,AptitudeWit,AptitudeAgile],
    BaseAttributes               = [BaseForza,BaseWit,BaseAgile],
    [ForzaUse, WitUse, AgileUse] = calc_pet_attribute(AptitudeAttributes, BaseAttributes, NewLevel, Strength),
    [Forza, Wit, Agile]          = calc_pet_client_attribute([ForzaUse, WitUse, AgileUse]),
    ?DEBUG("pet_finish_upgrade: Level=[~p], NewLevel=[~p], ForzaUse=[~p], WitUse=[~p], AgileUse=[~p], Forza=[~p], Wit=[~p], Agile=[~p]", [Level, NewLevel, ForzaUse, WitUse, AgileUse, Forza, Wit, Agile]),
    % 更新宠物信息
    UpgradeFlag    = 0,
    UpgradeEndTime = 0,
    Data = [NewLevel, UpgradeFlag, UpgradeEndTime, Forza, Wit, Agile, PetId],
    SQL = io_lib:format(?SQL_PET_UPDATE_LEVEL, Data),
    ?DEBUG("pet_finish_upgrade: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    if  % 扣取金币
       UpgradeMoney > 0 ->
            Data1 = [UpgradeMoney, PlayerId],
            SQL1 = io_lib:format(?SQL_PLAYER_UPDATE_DEDUCT_GOLD, Data1),
            ?DEBUG("pet_finish_upgrade: SQL=[~s]", [SQL1]),
            db_sql:execute(SQL1);
   true ->
            void
    end,
    [ok, NewLevel, Forza, Wit, Agile, ForzaUse, WitUse, AgileUse].

%% -----------------------------------------------------------------
%% 扩展升级队列
%% -----------------------------------------------------------------
extent_upgrade_que(PlayerId, NewQueNum, ExtentQueMoney) ->
    Data = [ExtentQueMoney, NewQueNum, PlayerId],
    SQL  = io_lib:format(?SQL_PLAYER_UPDATE_EXTENT_QUE, Data),
    ?DEBUG("extent_upgrade_que: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    ok.

%% -----------------------------------------------------------------
%% 喂养宠物
%% -----------------------------------------------------------------
feed_pet(PetId, PetQuality, FoodQuality, GoodsUseNum, Strength, StrengThreshold, Level, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile) ->
    ?DEBUG("feed_pet: PetId=[~p], PetQuality=[~p], FoodQuality=[~p], GoodsUseNum=[~p], Strength=[~p], PetStrengThreshold=[~p]", [PetId, PetQuality, FoodQuality, GoodsUseNum, Strength, StrengThreshold]),
    % 计算增加的体力
    FoodStrength  = data_pet:get_food_strength(PetQuality, FoodQuality),
    StrengthTotal = Strength+GoodsUseNum*FoodStrength,
    StrengthNew   = case StrengthTotal >= StrengThreshold of
                        true  -> StrengThreshold;
                        false -> StrengthTotal
                    end,
    % 体力值变化影响了力智敏则重新计算属性值
    case is_strength_add_change_attribute(Strength, StrengthNew) of
        true ->
            AptitudeAttributes           = [AptitudeForza,AptitudeWit,AptitudeAgile],
            BaseAttributes               = [BaseForza,BaseWit,BaseAgile],
            [ForzaUse, WitUse, AgileUse] = calc_pet_attribute(AptitudeAttributes, BaseAttributes, Level, StrengthNew),
            [Forza, Wit, Agile]          = calc_pet_client_attribute([ForzaUse, WitUse, AgileUse]),
            % 更新体力值和属性
            Data = [StrengthNew, Forza, Wit, Agile, PetId],
            SQL = io_lib:format(?SQL_PET_UPDATE_STRENGTH, Data),
            ?DEBUG("feed_pet: SQL=[~s]", [SQL]),
            db_sql:execute(SQL),
            [ok, StrengthNew, Forza, Wit, Agile, ForzaUse, WitUse, AgileUse];
        false ->
            [ok, StrengthNew]
    end.
    

%% -----------------------------------------------------------------
%% 驯养宠物
%% -----------------------------------------------------------------
domesticate_pet(PetId, DomesticateType, Level, Strength, Aptitude, AptitudeThreshold, BaseAttribute) ->
    ?DEBUG("domesticate_pet: PetId=[~p], DomesticateType=[~p], Level=[~p], Strength=[~p], Aptitude=[~p], AptitudeThreshold=[~p], BaseAttribute=[~p]", [PetId, DomesticateType, Level, Strength, Aptitude, AptitudeThreshold, BaseAttribute]),
    AptitudeValid = case Aptitude > AptitudeThreshold of
                        true  -> AptitudeThreshold;
                        false -> Aptitude
                    end,
    [AttributeUse] = calc_pet_attribute([AptitudeValid], [BaseAttribute], Level, Strength),
    [Attribute]    = calc_pet_client_attribute([AttributeUse]),
    case DomesticateType of
        0 ->
            Data = [Attribute, AptitudeValid, PetId],
            SQL  = io_lib:format(?SQL_PET_UPDATE_FORZA, Data),
            ?DEBUG("domesticate_pet: SQL=[~s]", [SQL]),
            db_sql:execute(SQL);
        1 ->
            Data = [Attribute, AptitudeValid, PetId],
            SQL  = io_lib:format(?SQL_PET_UPDATE_WIT, Data),
            ?DEBUG("domesticate_pet: SQL=[~s]", [SQL]),
            db_sql:execute(SQL);
        2 ->
            Data = [Attribute, AptitudeValid, PetId],
            SQL  = io_lib:format(?SQL_PET_UPDATE_AGILE, Data),
            ?DEBUG("domesticate_pet: SQL=[~s]", [SQL]),
            db_sql:execute(SQL)
    end,
    [ok, AptitudeValid, Attribute, AttributeUse].

%% -----------------------------------------------------------------
%% 宠物进阶
%% -----------------------------------------------------------------
enhance_quality(PetId, Quality, SuccessProbability) ->
    ?DEBUG("enhance_quality: PetId=[~p], Quality=[~p], SuccessProbability=[~p]", [PetId, Quality, SuccessProbability]),
    case get_enhance_quality_result(SuccessProbability)  of
        % 进阶成功
        true ->
            AptitudeThreshold = data_pet:get_pet_config(aptitude_threshold, [Quality+1]),
            Data1 = [Quality+1, AptitudeThreshold, 1, PetId],
            SQL1  = io_lib:format(?SQL_PET_UPDATE_QUALITY, Data1),
            ?DEBUG("enhance_quality: SQL=[~s]", [SQL1]),
            db_sql:execute(SQL1),
            [ok, 1, Quality+1, AptitudeThreshold];
        % 进阶失败
        false ->
            AptitudeThreshold = data_pet:get_pet_config(aptitude_threshold, [Quality]),
            [ok, 0, Quality, AptitudeThreshold]
    end.


%% -----------------------------------------------------------------
%% 体力值同步
%% -----------------------------------------------------------------
strength_sync([], _NowTime, RecordsNum, RecordsData, TotalForza, TotalWit, TotalAgile) ->
    [RecordsNum, RecordsData, TotalForza, TotalWit, TotalAgile];
strength_sync(Pets, NowTime, RecordsNum, RecordsData, TotalForza, TotalWit, TotalAgile) ->
    [Pet|PetLeft] = Pets,
    if  % 同步时间到达
    NowTime >= Pet#ets_pet.strength_nexttime ->
            % 计算新的体力值
            [IntervalSync, StrengthSync] = data_pet:get_pet_config(strength_sync, []),
            StrengthNew = case Pet#ets_pet.strength > StrengthSync of
                              true  -> Pet#ets_pet.strength-StrengthSync;
                              false -> 0
                          end,
            ?DEBUG("strength_sync: Time arrive, PlayeId=[~p], PetId=[~p], Strength=[~p], StrengthNew=[~p]", [Pet#ets_pet.player_id, Pet#ets_pet.id,Pet#ets_pet.strength, StrengthNew]),
            % 判断体力值变化是否影响力智敏
            PetId = Pet#ets_pet.id,
            case is_strength_deduct_change_attribute(Pet#ets_pet.strength, StrengthNew) of
                true ->
                    % 重新计算力智敏
                    AptitudeAttributes           = [Pet#ets_pet.aptitude_forza, Pet#ets_pet.aptitude_wit,Pet#ets_pet.aptitude_agile],
                    BaseAttributes               = [Pet#ets_pet.base_forza, Pet#ets_pet.base_wit,  Pet#ets_pet.base_agile],
                    [ForzaUse, WitUse, AgileUse] = calc_pet_attribute(AptitudeAttributes, BaseAttributes, Pet#ets_pet.level, StrengthNew),
                    [Forza,Wit,Agile]            = calc_pet_client_attribute([ForzaUse, WitUse, AgileUse]),
                    % 更新缓存
                    PetNew = Pet#ets_pet{
                        strength_nexttime = NowTime+IntervalSync,
                        forza             = Forza,
                        wit               = Wit,
                        agile             = Agile,
                        forza_use         = ForzaUse,
                        wit_use           = WitUse,
                        agile_use         = AgileUse,
                        strength          = StrengthNew},
                    update_pet(PetNew),
                    % 更新数据库
                    SQLData = [StrengthNew, Forza, Wit, Agile, Pet#ets_pet.id],
                    SQL = io_lib:format(?SQL_PET_UPDATE_STRENGTH, SQLData),
                    ?DEBUG("strength_sync: SQL=[~s]", [SQL]),
                    db_sql:execute(SQL),
                    % 继续循环
                    Data = <<PetId:32,StrengthNew:16,1:16, Forza:16, Wit:16, Agile:16>>,
                    strength_sync(PetLeft, NowTime, RecordsNum+1, list_to_binary([RecordsData, Data]), TotalForza+ForzaUse, TotalWit+WitUse, TotalAgile+AgileUse);
                false ->
                    % 更新缓存 
                    PetNew = Pet#ets_pet{
                        strength_nexttime = NowTime+IntervalSync,
                        strength          = StrengthNew},
                    update_pet(PetNew),
                    Forza    = Pet#ets_pet.forza,
                    Wit      = Pet#ets_pet.wit,
                    Agile    = Pet#ets_pet.agile,
                    ForzaUse = Pet#ets_pet.forza_use,
                    WitUse   = Pet#ets_pet.wit_use,
                    AgileUse = Pet#ets_pet.agile_use,
                    % 继续循环
                    Data = <<PetId:32,StrengthNew:16,0:16, Forza:16, Wit:16, Agile:16>>,
                    strength_sync(PetLeft, NowTime, RecordsNum+1, list_to_binary([RecordsData, Data]), TotalForza+ForzaUse, TotalWit+WitUse, TotalAgile+AgileUse)
            end;
       % 同步时间未到
   true ->
            ?DEBUG("strength_sync: Not this time, PlayeId=[~p], PetId=[~p], Strength=[~p]", [Pet#ets_pet.player_id, Pet#ets_pet.id,Pet#ets_pet.strength]),
            strength_sync(PetLeft, NowTime, RecordsNum, RecordsData, TotalForza+Pet#ets_pet.forza_use, TotalWit+Pet#ets_pet.wit_use, TotalAgile+Pet#ets_pet.agile_use)
    end.

%% -----------------------------------------------------------------
%% 获取宠物信息
%% -----------------------------------------------------------------
get_pet_info(PetId) ->
    ?DEBUG("get_pet_info: PetId=[~p]", [PetId]),
    Pet = get_pet(PetId),
    if  % 宠物不存在
            Pet =:= [] ->
                [1, <<>>];
            true ->
                PetBin = parse_pet_info(Pet),
                [1, PetBin]
    end.

parse_pet_info(Pet) ->
    [Id,Name,RenameCount,Level,Strength,Quality,Forza,Wit,Agile,BaseForza,BaseWit,BaseAgile,BaseForzaNew,BaseWitNew,BaseAgileNew,AptitudeForza,AptitudeWit,AptitudeAgile,AptitudeThreshold,Strength,FightFlag,UpgradeFlag,UpgradeEndtime,FightIconPos, StrengthThreshold, TypeId] =
        [Pet#ets_pet.id, Pet#ets_pet.name, Pet#ets_pet.rename_count, Pet#ets_pet.level, Pet#ets_pet.strength, Pet#ets_pet.quality, Pet#ets_pet.forza, Pet#ets_pet.wit, Pet#ets_pet.agile, Pet#ets_pet.base_forza, Pet#ets_pet.base_wit, Pet#ets_pet.base_agile, Pet#ets_pet.base_forza_new, Pet#ets_pet.base_wit_new, Pet#ets_pet.base_agile_new, Pet#ets_pet.aptitude_forza, Pet#ets_pet.aptitude_wit, Pet#ets_pet.aptitude_agile, Pet#ets_pet.aptitude_threshold, Pet#ets_pet.strength, Pet#ets_pet.fight_flag, Pet#ets_pet.upgrade_flag, Pet#ets_pet.upgrade_endtime, Pet#ets_pet.fight_icon_pos, Pet#ets_pet.strength_threshold, Pet#ets_pet.type_id],
    NameLen = byte_size(Name),
    NowTime = util:unixtime(),
    UpgradeLeftTime = case UpgradeFlag of
                          0 -> 0;
                          1 -> UpgradeEndtime - NowTime;
                          _ -> ?ERR("parse_pet_info: Unknow upgrade flag = [~p]", [UpgradeFlag])
                      end,
    <<Id:32,NameLen:16,Name/binary,RenameCount:16,Level:16,Quality:16,Forza:16,Wit:16,Agile:16,BaseForza:16,BaseWit:16,BaseAgile:16,BaseForzaNew:16,BaseWitNew:16,BaseAgileNew:16,AptitudeForza:16,AptitudeWit:16,AptitudeAgile:16,AptitudeThreshold:16,Strength:16,FightFlag:16,UpgradeFlag:16,UpgradeLeftTime:32,FightIconPos:16,StrengthThreshold:16, TypeId:32>>.
        
%% -----------------------------------------------------------------
%% 获取宠物列表
%% -----------------------------------------------------------------
get_pet_list(PlayerId) ->
    PetList = get_all_pet(PlayerId),
    RecordNum = length(PetList),
    if  % 没有宠物
        RecordNum == 0 ->
            [1, RecordNum, <<>>];
        true ->
            Records = lists:map(fun parse_pet_info/1, PetList),
            [1, RecordNum, list_to_binary(Records)]
    end.

%% -----------------------------------------------------------------
%% 宠物出战替换
%% -----------------------------------------------------------------
fighting_replace(PetId, ReplacedPetId, IconPos) ->
    ?DEBUG("fighting_replace: PetId=[~p], ReplacedPetId=[~p], IconPos=[~p]", [PetId, ReplacedPetId, IconPos]),
    Data = [1, IconPos, PetId],
    SQL = io_lib:format(?SQL_PET_UPDATE_FIGHT_FLAG, Data),
    ?DEBUG("fighting_replace: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    Data1 = [0, 0, ReplacedPetId],
    SQL1 = io_lib:format(?SQL_PET_UPDATE_FIGHT_FLAG, Data1),
    ?DEBUG("fighting_replace: SQL=[~s]", [SQL1]),
    db_sql:execute(SQL1),
    ok.

%% -----------------------------------------------------------------
%% 取消升级
%% -----------------------------------------------------------------
cancel_upgrade(PetId) ->
    ?DEBUG("cancel_upgrade: PetId=[~p]", [PetId]),
    Data = [0, 0, PetId],
    SQL = io_lib:format(?SQL_PET_UPDATE_UPGRADE_INFO, Data),
    ?DEBUG("cancel_upgrade: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    ok.

%% -----------------------------------------------------------------
%% 角色死亡扣减
%% -----------------------------------------------------------------
handle_role_dead(Status) ->
    FightingPet  = lib_pet:get_fighting_pet(Status#player_status.id),
    lists:map(fun handle_pet_dead/1, FightingPet),
    if  length(FightingPet) > 0 ->
            {ok, Bin} = pt_41:write(41000, [0]),
            lib_send:send_one(Status#player_status.socket, Bin);
        true ->
            void
    end.

handle_pet_dead(Pet) ->
    % 计算扣取的体力值
    DeadStrength = data_pet:get_pet_config(role_dead_strength, []),
    StrengthNew  = case Pet#ets_pet.strength > DeadStrength of
                       true  -> (Pet#ets_pet.strength - DeadStrength);
                       false -> 0
                   end,
    % 更新缓存
    case is_strength_deduct_change_attribute(Pet#ets_pet.strength, StrengthNew) of
        true ->
            % 重新计算力智敏
            AptitudeAttributes           = [Pet#ets_pet.aptitude_forza, Pet#ets_pet.aptitude_wit,Pet#ets_pet.aptitude_agile],
            BaseAttributes               = [Pet#ets_pet.base_forza, Pet#ets_pet.base_wit,  Pet#ets_pet.base_agile],
            [ForzaUse, WitUse, AgileUse] = calc_pet_attribute(AptitudeAttributes, BaseAttributes, Pet#ets_pet.level, StrengthNew),
            [Forza,Wit,Agile]            = calc_pet_client_attribute([ForzaUse, WitUse, AgileUse]),
            % 更新缓存
            PetNew = Pet#ets_pet{
                forza             = Forza,
                wit               = Wit,
                agile             = Agile,
                forza_use         = ForzaUse,
                wit_use           = WitUse,
                agile_use         = AgileUse,
                strength          = StrengthNew},
            update_pet(PetNew),
            % 更新数据库
            Data = [StrengthNew, Forza, Wit, Agile, Pet#ets_pet.id],
            SQL = io_lib:format(?SQL_PET_UPDATE_STRENGTH, Data),
            ?DEBUG("handle_pet_dead: SQL=[~s]", [SQL]),
            db_sql:execute(SQL);
        false ->
            % 更新缓存 
            PetNew = Pet#ets_pet{strength = StrengthNew},
            update_pet(PetNew),
            % 更新数据库
            Forza    = Pet#ets_pet.forza,
            Wit      = Pet#ets_pet.wit,
            Agile    = Pet#ets_pet.agile,
            Data = [StrengthNew, Forza, Wit, Agile, Pet#ets_pet.id],
            SQL = io_lib:format(?SQL_PET_UPDATE_STRENGTH, Data),
            ?DEBUG("handle_pet_dead: SQL=[~s]", [SQL]),
            db_sql:execute(SQL)
    end.



%%=========================================================================
%% 定时服务
%%=========================================================================

%% -----------------------------------------------------------------
%% 处理每日体力
%% -----------------------------------------------------------------
handle_daily_strength() ->
    send_to_all('pet_strength_daily', []),
    ok.

collect_strength_daily(Pet) ->
    % 判断是否应该收取
    NowTime = util:unixtime(),
    [StrengthNew, StrengthDailyNextTimeNew] = calc_strength_daily(NowTime, Pet#ets_pet.strength_daily_nexttime, Pet#ets_pet.strength, Pet#ets_pet.strength_daily),
    % 如果需要收取则进行
    if  StrengthNew /= Pet#ets_pet.strength ->
            % 更新缓存
            case is_strength_deduct_change_attribute(Pet#ets_pet.strength, StrengthNew) of
                true ->
                    % 重新计算力智敏
                    AptitudeAttributes           = [Pet#ets_pet.aptitude_forza, Pet#ets_pet.aptitude_wit,Pet#ets_pet.aptitude_agile],
                    BaseAttributes               = [Pet#ets_pet.base_forza, Pet#ets_pet.base_wit,  Pet#ets_pet.base_agile],
                    [ForzaUse, WitUse, AgileUse] = calc_pet_attribute(AptitudeAttributes, BaseAttributes, Pet#ets_pet.level, StrengthNew),
                    [Forza,Wit,Agile]            = calc_pet_client_attribute([ForzaUse, WitUse, AgileUse]),
                    % 更新缓存
                    PetNew = Pet#ets_pet{
                        forza                   = Forza,
                        wit                     = Wit,
                        agile                   = Agile,
                        forza_use               = ForzaUse,
                        wit_use                 = WitUse,
                        agile_use               = AgileUse,
                        strength                = StrengthNew,
                        strength_daily_nexttime = StrengthDailyNextTimeNew},
                    update_pet(PetNew),
                    % 更新数据库
                    Data = [StrengthNew, Forza, Wit, Agile, StrengthDailyNextTimeNew, Pet#ets_pet.id],
                    SQL = io_lib:format(?SQL_PET_UPDATE_STRENGTH_DAILY, Data),
                    ?DEBUG("collect_strength_daily: SQL=[~s]", [SQL]),
                    db_sql:execute(SQL);
                false ->
                    % 更新缓存
                    PetNew = Pet#ets_pet{
                        strength                =  StrengthNew,
                        strength_daily_nexttime =  StrengthDailyNextTimeNew},
                    update_pet(PetNew),
                    % 更新数据库
                    Forza    = Pet#ets_pet.forza,
                    Wit      = Pet#ets_pet.wit,
                    Agile    = Pet#ets_pet.agile,
                    Data = [StrengthNew, Forza, Wit, Agile, StrengthDailyNextTimeNew, Pet#ets_pet.id],
                    SQL = io_lib:format(?SQL_PET_UPDATE_STRENGTH_DAILY, Data),
                    ?DEBUG("collect_strength_daily: SQL=[~s]", [SQL]),
                    db_sql:execute(SQL)
            end;
        true ->
            void
    end.


%% -----------------------------------------------------------------
%% 删除角色
%% -----------------------------------------------------------------
delete_role(PlayerId) ->
    ?DEBUG("delete_role: PlayerId=[~p]", [PlayerId]),
    % 删除宠物表记录
    Data = [PlayerId],
    SQL  = io_lib:format(?SQL_PET_DELETE_ROLE, Data),
    ?DEBUG("delete_role: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 删除缓存
    delete_all_pet(PlayerId),
    ok.


%%=========================================================================
%% 工具函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 确保字符串类型为二进制
%% -----------------------------------------------------------------
make_sure_binary(String) ->
    case is_binary(String) of
        true  -> String;
        false when is_list(String) -> list_to_binary(String);
        false ->
            ?ERR("make_sure_binary: Error string=[~w]", [String]),
            String
    end.

%% -----------------------------------------------------------------
%% 广播消息给进程
%% -----------------------------------------------------------------
send_to_all(MsgType, Bin) ->
    Pids = ets:match(?ETS_ONLINE, #ets_online{pid='$1', _='_'}),
    F = fun([P]) ->
        gen_server:cast(P, {MsgType, Bin})
    end,
    [F(Pid) || Pid <- Pids].

%% -----------------------------------------------------------------
%% 根据1970年以来的秒数获得日期
%% -----------------------------------------------------------------
seconds_to_localtime(Seconds) ->
    DateTime = calendar:gregorian_seconds_to_datetime(Seconds+?DIFF_SECONDS_0000_1900),
    calendar:universal_time_to_local_time(DateTime).

%% -----------------------------------------------------------------
%% 判断是否同一天
%% -----------------------------------------------------------------
is_same_date(Seconds1, Seconds2) ->
    {{Year1, Month1, Day1}, _Time1} = seconds_to_localtime(Seconds1),
    {{Year2, Month2, Day2}, _Time2} = seconds_to_localtime(Seconds2),
    if ((Year1 /= Year2) or (Month1 /= Month2) or (Day1 /= Day2)) -> false;
        true -> true
    end.

%% -----------------------------------------------------------------
%% 判断是否同一星期
%% -----------------------------------------------------------------
is_same_week(Seconds1, Seconds2) ->
    {{Year1, Month1, Day1}, Time1} = seconds_to_localtime(Seconds1),
    % 星期几
    Week1  = calendar:day_of_the_week(Year1, Month1, Day1),
    % 从午夜到现在的秒数
    Diff1  = calendar:time_to_seconds(Time1),
    Monday = Seconds1 - Diff1 - (Week1-1)*?ONE_DAY_SECONDS,
    Sunday = Seconds1 + (?ONE_DAY_SECONDS-Diff1) + (7-Week1)*?ONE_DAY_SECONDS,
    if ((Seconds2 >= Monday) and (Seconds2 < Sunday)) -> true;
        true -> false
    end.

%% -----------------------------------------------------------------
%% 获取当天0点和第二天0点
%% -----------------------------------------------------------------
get_midnight_seconds(Seconds) ->
    {{_Year, _Month, _Day}, Time} = seconds_to_localtime(Seconds),
    % 从午夜到现在的秒数
    Diff   = calendar:time_to_seconds(Time),
    % 获取当天0点
    Today  = Seconds - Diff,
    % 获取第二天0点
    NextDay = Seconds + (?ONE_DAY_SECONDS-Diff),
    {Today, NextDay}.

%% -----------------------------------------------------------------
%% 计算相差的天数
%% -----------------------------------------------------------------
get_diff_days(Seconds1, Seconds2) ->
    {{Year1, Month1, Day1}, _} = seconds_to_localtime(Seconds1),
    {{Year2, Month2, Day2}, _} = seconds_to_localtime(Seconds2),
    Days1 = calendar:date_to_gregorian_days(Year1, Month1, Day1),
    Days2 = calendar:date_to_gregorian_days(Year2, Month2, Day2),
    DiffDays=abs(Days2-Days1),
    DiffDays+1.

%% -----------------------------------------------------------------
%% 随机生成基础属性
%% -----------------------------------------------------------------
generate_base_attribute() ->
    % 获取配置
    BaseAttributeSum = data_pet:get_pet_config(base_attribute_sum, []),
    % 随机生成基础力智敏
    BaseForza  = util:rand(1, BaseAttributeSum - 2),
    BaseWit    = util:rand(1, BaseAttributeSum - BaseForza - 1),
    BaseAgile  = BaseAttributeSum - BaseForza - BaseWit,
    [BaseForza, BaseWit, BaseAgile].

generate_base_attribute(ShuffleCount) ->
    % 获取配置
    LuckyShuffleCount   = data_pet:get_pet_config(lucky_shuffle_count, []),
    if  ShuffleCount >= LuckyShuffleCount ->
            generate_base_attribute_lucky();
        true ->
            generate_base_attribute()
    end.

generate_base_attribute_lucky() ->
    % 获取配置
    BaseAttributeSum   = data_pet:get_pet_config(base_attribute_sum, []),
    LuckyBaseAttribute = data_pet:get_pet_config(lucky_base_attribute, []),
    % 随机生成基础力智敏
    LeftAttribute = BaseAttributeSum-LuckyBaseAttribute,
    BaseForza     = util:rand(1, LeftAttribute-2),
    BaseWit       = util:rand(1, LeftAttribute-BaseForza-1),
    BaseAgile     = LeftAttribute-BaseForza-BaseWit,
    Index         = util:rand(1, 3),    
    if  Index == 1 ->
            [BaseForza+LuckyBaseAttribute,BaseWit,BaseAgile];
        Index == 2 ->
            [BaseForza,BaseWit+LuckyBaseAttribute,BaseAgile];
        Index == 3 ->
            [BaseForza,BaseWit,BaseAgile+LuckyBaseAttribute]
    end.

%% -----------------------------------------------------------------
%% 计算宠物属性
%% -----------------------------------------------------------------
calc_pet_attribute(AptitudeAttributes, BaseAttributes, Level, Strength) ->
    calc_pet_attribute_helper(AptitudeAttributes, BaseAttributes, Level, Strength, []).
calc_pet_attribute_helper([], [], _Level, _Strength, Attributes) ->
    Attributes;
calc_pet_attribute_helper(AptitudeAttributes, BaseAttributes, Level, Strength, Attributes) ->
    [AptitudeAttribute|AptitudeAttributeLeft] = AptitudeAttributes,
    [BaseAttribute|BaseAttributeLeft] = BaseAttributes,
    % 0.1+(当前资质/100+基础值）*(当前等级-1)*0.0049
    Attribute = 0.1 + (AptitudeAttribute/100+BaseAttribute)*(Level-1)*0.0049,
    if  Strength =< 0 ->
            calc_pet_attribute_helper(AptitudeAttributeLeft, BaseAttributeLeft, Level, Strength, Attributes++[0]);
        Strength =< 50 ->
            calc_pet_attribute_helper(AptitudeAttributeLeft, BaseAttributeLeft, Level, Strength, Attributes++[Attribute*0.5]);
        Strength =< 90 ->
            calc_pet_attribute_helper(AptitudeAttributeLeft, BaseAttributeLeft, Level, Strength, Attributes++[Attribute]);
        true ->
            calc_pet_attribute_helper(AptitudeAttributeLeft, BaseAttributeLeft, Level, Strength, Attributes++[Attribute*1.2])
    end.

calc_pet_client_attribute(Attributes)->
    calc_pet_client_attribute_helper(Attributes, []).
calc_pet_client_attribute_helper([], ClientAttributes) ->
    ClientAttributes;
calc_pet_client_attribute_helper(Attributes, ClientAttributes) ->
    [Attribute|AttributeLeft] = Attributes,
    NewAttribute = round(Attribute*10),
    calc_pet_client_attribute_helper(AttributeLeft, ClientAttributes++[NewAttribute]).

%% -----------------------------------------------------------------
%% 计算宠物属性加点到角色的影响
%% -----------------------------------------------------------------
calc_player_attribute(Type, Status, Forza, Wit, Agile) ->
    ?DEBUG("calc_player_attribute:Type=[~p], Forza=[~p], Wit=[~p], Agile=[~p]", [Type, Forza, Wit, Agile]),
    % 计算新的宠物力智敏
    [NewPetForza, NewPetWit, NewPetAgile] = case Type of
                                                add ->
            [PetForza, PetWit, PetAgile] = Status#player_status.pet_attribute,
            [PetForza+Forza, PetWit+Wit, PetAgile+Agile];
                                                deduct ->
            [PetForza, PetWit, PetAgile] = Status#player_status.pet_attribute,
            [PetForza-Forza, PetWit-Wit, PetAgile-Agile];
                                                replace -> [Forza, Wit, Agile]
                                            end,
    % 重新计算人物属性
    Status1 = Status#player_status{pet_attribute = [NewPetForza,NewPetWit,NewPetAgile]},
    Status2 = lib_player:count_player_attribute(Status1),
    % 内息上限有变化则通知客户端
    if  Status1#player_status.hp_lim =/= Status2#player_status.hp_lim ->
            {ok, SceneData} = pt_12:write(12009, [Status#player_status.id, Status2#player_status.hp, Status2#player_status.hp_lim]),
            lib_send:send_to_area_scene(Status2#player_status.scene, Status2#player_status.x, Status2#player_status.y, SceneData);
        true ->
            void
    end,
    % 通知客户端角色属性改变
    lib_player:send_attribute_change_notify(Status2, 1),
    Status2.

calc_new_hp_mp(HpMp, HpMpLimit, HpMpLimitNew) ->
    case  HpMpLimit =/= HpMpLimitNew of
        true ->
            case HpMp > HpMpLimitNew of
                 true  -> HpMpLimitNew;
                 false -> HpMp
            end;
        false ->
            HpMp
    end.

%% -----------------------------------------------------------------
%% 计算升级加速所需金币
%% -----------------------------------------------------------------
calc_shorten_money(ShortenTime) ->
    [MoneyUnit, Unit] = data_pet:get_pet_config(shorten_money_unit,[]),
    TotalUnit = util:ceil(ShortenTime/Unit),
    MoneyUnit * TotalUnit.

%% -----------------------------------------------------------------
%% 计算收取的每日体力值
%% -----------------------------------------------------------------
calc_strength_daily(NowTime, StrengthDailyNextTime, Strength, StrengthDaily) ->
    {_Today, NextDay} = get_midnight_seconds(NowTime),
    if  % 小于第二天凌晨的应该收取
        StrengthDailyNextTime =< NextDay ->
            DiffDays = get_diff_days(StrengthDailyNextTime, NowTime),
            StrengthTotal = StrengthDaily*DiffDays,
            StrengthNew = case Strength > StrengthTotal of
                              true  -> Strength - StrengthTotal;
                              false -> 0
                          end,
            StrengthDailyNextTimeNew = NowTime+(?ONE_DAY_SECONDS),
            [StrengthNew, StrengthDailyNextTimeNew];
        % 不应该收取
        true ->
            [Strength, StrengthDailyNextTime]
    end.

%% -----------------------------------------------------------------
%% 判断升级是否完成
%% -----------------------------------------------------------------
is_upgrade_finish(UpgradeFlag, UpgradeEndTime) ->
    case UpgradeFlag of
        % 不在升级
        0 ->
            false;
        % 在升级
        1->
            NowTime           = util:unixtime(),
            UpgradeInaccuracy = data_pet:get_pet_config(upgrade_inaccuracy, []),
            UpgradeLeftTime   = abs(UpgradeEndTime-NowTime),
            if  % 已经升完级
                ((NowTime >= UpgradeEndTime) or (UpgradeLeftTime < UpgradeInaccuracy)) -> true;
                % 还未升完级
                true -> false
            end
    end.

%% -----------------------------------------------------------------
%% 判断体力值扣减是否改变角色属性
%% -----------------------------------------------------------------
is_strength_deduct_change_attribute(Strength, StrengthNew) ->
    if  ((StrengthNew == 0)  and (Strength > 0)) -> true;
        ((StrengthNew =< 50) and (Strength > 50)) -> true;
        ((StrengthNew =< 90) and (Strength > 90)) -> true;
        true -> false
    end.

%% -----------------------------------------------------------------
%% 判断体力值增加是否改变角色属性
%% -----------------------------------------------------------------
is_strength_add_change_attribute(Strength, StrengthNew) ->
    if  ((Strength =< 90) and (StrengthNew > 90)) -> true;
        ((Strength =< 50) and (StrengthNew > 50)) -> true;
        ((Strength == 0)  and (StrengthNew > 0)) -> true;
        true -> false
    end.

%% -----------------------------------------------------------------
%% 根据成功几率获得进阶结果
%% -----------------------------------------------------------------
get_enhance_quality_result(SuccessProbability) ->
    RandNumer = util:rand(1, 100),
    if  (RandNumer > SuccessProbability) -> false;
        true -> true
    end.

%%=========================================================================
%% 缓存操作函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 通用函数
%% -----------------------------------------------------------------
lookup_one(Table, Key) ->
    Record = ets:lookup(Table, Key),
    if  Record =:= [] ->
            [];
        true ->
            [R] = Record,
            R
    end.

lookup_all(Table, Key) ->
    ets:lookup(Table, Key).

match_one(Table, Pattern) ->
    Record = ets:match_object(Table, Pattern),
    if  Record =:= [] ->
            [];
        true ->
            [R] = Record,
            R
    end.

match_all(Table, Pattern) ->
    ets:match_object(Table, Pattern).

%% -----------------------------------------------------------------
%% 宠物操作
%% -----------------------------------------------------------------
get_fighting_pet(PlayerId) ->
    match_all(?ETS_PET, #ets_pet{player_id=PlayerId, fight_flag=1, _='_'}).

get_pet(PlayerId, PetId) ->
    match_one(?ETS_PET, #ets_pet{id=PetId, player_id=PlayerId, _='_'}).

get_pet(PetId) ->
    lookup_one(?ETS_PET, PetId).

get_all_pet(PlayerId) ->
    match_all(?ETS_PET, #ets_pet{player_id=PlayerId, _='_'}).

get_pet_count(PlayerId) ->
    length(get_all_pet(PlayerId)).

get_upgrading_pet(PlayerId) ->
    match_all(?ETS_PET, #ets_pet{player_id=PlayerId, upgrade_flag=1, _='_'}).

update_pet(Pet) ->
    ets:insert(?ETS_PET, Pet).

delete_pet(PetId) ->
    ets:delete(?ETS_PET, PetId).

delete_all_pet(PlayerId) ->
    ets:match_delete(?ETS_PET, #ets_pet{player_id=PlayerId, _='_'}).

%% -----------------------------------------------------------------
%% 宠物道具
%% -----------------------------------------------------------------
get_base_pet(GoodsId) ->
    lookup_one(?ETS_BASE_PET, GoodsId).

update_base_pet(BasePet) ->
    ets:insert(?ETS_BASE_PET, BasePet).

%% -----------------------------------------------------------------
%% 背包物品
%% -----------------------------------------------------------------
get_goods(GoodsId) ->
    match_one(?ETS_GOODS_ONLINE, #goods{id=GoodsId, location=4, _='_'}).

%% -----------------------------------------------------------------
%% 物品类型
%% -----------------------------------------------------------------
get_goods_type(GoodsId) ->
    lookup_one(?ETS_GOODS_TYPE,GoodsId).

