%%%------------------------------------
%%% @Module  : mod_pet
%%% @Author  : shebiao
%%% @Email   : shebiao@jieyou.com
%%% @Created : 2010.07.03
%%% @Description: 宠物处理
%%%------------------------------------
-module(mod_pet).
-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-compile(export_all).

%%=========================================================================
%% 一些定义
%%=========================================================================
-record(state, {interval = 0}).

%%=========================================================================
%% 接口函数
%%=========================================================================
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

stop() ->
    gen_server:call(?MODULE, stop).


%%=========================================================================
%% 回调函数
%%=========================================================================
init([]) ->
    process_flag(trap_exit, true),
    Timeout = 60000,
    State = #state{interval = Timeout},
    ?DEBUG("init: loading base_pet....", []),
    lib_pet:load_base_pet(),
    {ok, State}.

handle_call(_Request, _From, State) ->
    {reply, State, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%=========================================================================
%% 业务处理函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 宠物孵化
%% -----------------------------------------------------------------
incubate_pet(Status, [GoodsId, GoodsUseNum]) ->
    ?DEBUG("incubate_pet: GoodsId=[~p], GoodsUseNum=[~p]", [GoodsId, GoodsUseNum]),
    Goods = lib_pet:get_goods(GoodsId),
    if  % 该物品不存在
        Goods =:= []  -> [2, 0, <<>>];
        true ->
            [EggGoodsType, EggGoodsSubType] = data_pet:get_pet_config(egg_goods_type,[]),
            [GoodsPlayerId, GoodsTypeId, GoodsType, GoodsSubtype, GoodsNum, _GoodsCell, GoodsLevel]  =
                [Goods#goods.player_id, Goods#goods.goods_id, Goods#goods.type, Goods#goods.subtype, Goods#goods.num, Goods#goods.cell, Goods#goods.level],
            if   % 物品不归你所有
                 GoodsPlayerId /= Status#player_status.id -> [3, 0, <<>>];
                 % 该物品不是宠物蛋
                 ((GoodsType /= EggGoodsType) and (GoodsSubtype /= EggGoodsSubType)) -> [4, 0, <<>>];
                 % 物品数量不够
                 GoodsNum < GoodsUseNum -> [5, 0, <<>>];
                 true ->
                     GoodsTypeInfo = lib_pet:get_goods_type(GoodsTypeId),
                     if % 该物品类型信息不存在
                        GoodsTypeInfo =:= [] ->
                            ?ERR("incubate_pet: Goods type not in cache, type_id=[~p]", [GoodsTypeId]),
                            [0, 0, <<>>];
                        true ->
                            if  % 你级别不够
                                Status#player_status.lv < GoodsLevel -> [6, 0, <<>>];
                                true ->
                                    PetCount    = lib_pet:get_pet_count(Status#player_status.id),
                                    PetCapacity = data_pet:get_pet_config(capacity,[]),
                                    if   % 宠物数已满
                                         PetCount >= PetCapacity -> [7, 0, <<>>];
                                         true ->
                                             case gen_server:call(Status#player_status.goods_pid, {'delete_one', GoodsId, GoodsUseNum}) of
                                                 [1, _GoodsNumNew] -> 
                                                     case lib_pet:incubate_pet(Status#player_status.id, GoodsTypeInfo) of
                                                        [ok, PetId, PetName] ->
                                                            [1, PetId, PetName];
                                                        _   ->
                                                            [0, 0, <<>>]
                                                    end;
                                                 [GoodsModuleCode, 0] ->
                                                    ?DEBUG("incubate_pet: Call goods module faild, result code=[~p]", [GoodsModuleCode]),
                                                    [0, 0, <<>>]
                                             end
                                    end
                            end
                     end
            end
    end.


%% -----------------------------------------------------------------
%% 宠物放生
%% -----------------------------------------------------------------
free_pet(Status, [PetId]) ->
    ?DEBUG("free_pet: PetId=[~p]", [PetId]),
    Pet = lib_pet:get_pet(PetId),
    if  % 宠物不存在
        Pet =:= []  -> 2;
        true ->
            [PlayerId, UpgradeFlag, FightFlag] = [Pet#ets_pet.player_id, Pet#ets_pet.upgrade_flag, Pet#ets_pet.fight_flag],
            if  % 该宠物不归你所有
                PlayerId /= Status#player_status.id -> 3;
                % 宠物正在升级
                UpgradeFlag == 1 -> 4;
                % 宠物正在出战
                FightFlag == 1 -> 5;
                true ->
                    case lib_pet:free_pet(PetId) of
                        ok  -> 1;
                        _   -> 0
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 宠物改名
%% -----------------------------------------------------------------
rename_pet(Status, [PetId, PetName]) ->
    ?DEBUG("rename_pet: PetId=[~p], PetName=[~s]", [PetId, PetName]),
    Pet = lib_pet:get_pet(PetId),
    if  % 宠物不存在
        Pet =:= []  -> [2, 0, 0];
        true ->
            [PlayerId, Name, RenameCount] = [Pet#ets_pet.player_id, Pet#ets_pet.name, Pet#ets_pet.rename_count],
            NewName = lib_pet:make_sure_binary(PetName),
            if  % 该宠物不归你所有
                PlayerId /= Status#player_status.id -> [3, 0, 0];
                % 新旧名称相同
                Name =:= NewName -> [4, 0, 0];
                true ->
                    if  % 修改次数大于0要收钱
                        RenameCount > 0 ->
                            RenameMoney = data_pet:get_rename_money(RenameCount),
                            if  % 金币不够
                                Status#player_status.gold < RenameMoney -> [5, 0, 0];
                                true ->
                                    case lib_pet:rename_pet(PetId, NewName, Status#player_status.id, RenameMoney) of
                                         ok  ->
                                             % 更新缓存
                                             PetNew = Pet#ets_pet{
                                                 rename_count = RenameCount+1,
                                                 name         = NewName},
                                             lib_pet:update_pet(PetNew),
                                             % 正确返回
                                             [1, 1, Status#player_status.gold-RenameMoney];
                                         _   -> [0, 0, 0]
                                    end
                            end;
                        % 修改次数等于0不收钱
                        true ->
                            case lib_pet:rename_pet(PetId, PetName, Status#player_status.id, 0) of
                                ok  ->
                                    % 更新缓存
                                    PetNew = Pet#ets_pet{
                                        rename_count = RenameCount+1,
                                        name         = NewName},
                                    lib_pet:update_pet(PetNew),
                                    [1, 0, Status#player_status.gold];
                                _   ->
                                    [0, 0, 0]
                            end
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 宠物出战
%% -----------------------------------------------------------------
fighting_pet(Status, [PetId, FightIconPos]) ->
    ?DEBUG("fighting_pet: PetId=[~p], FightIconPos=[~p]", [PetId, FightIconPos]),
    Pet = lib_pet:get_pet(PetId),
    if  % 宠物不存在
        Pet =:= []  -> [2, 0, 0, 0, 0];
        true ->
            [PlayerId, ForzaUse, WitUse, AgileUse, FightFlag, Strength] = [Pet#ets_pet.player_id, Pet#ets_pet.forza_use, Pet#ets_pet.wit_use, Pet#ets_pet.agile_use, Pet#ets_pet.fight_flag, Pet#ets_pet.strength],
            if  % 该宠物不归你所有
                PlayerId /= Status#player_status.id -> [3, 0, 0, 0, 0];
                % 宠物已经出战
                FightFlag == 1 -> [4, 0, 0, 0, 0];
                % 体力值为0
                Strength == 0 -> [5, 0, 0, 0, 0];
                true ->
                    MaxFighting  = data_pet:get_pet_config(maxinum_fighting,[]),
                    FightingPet  = lib_pet:get_fighting_pet(PlayerId),
                    if  % 出战宠物数达到上限
                        length(FightingPet) >= MaxFighting -> [6, 0, 0, 0, 0];
                        true ->
                            case lib_pet:fighting_pet(PetId, FightingPet, FightIconPos) of
                                [ok, IconPos]  ->
                                    [IntervalSync, _StrengthSync] = data_pet:get_pet_config(strength_sync, []),
                                    NowTime = util:unixtime(),
                                    % 更新缓存
                                    PetNew = Pet#ets_pet{fight_flag        = 1,
                                                         fight_icon_pos    = IconPos,
                                                         strength_nexttime = NowTime+IntervalSync},
                                    lib_pet:update_pet(PetNew),
                                    [1, IconPos, ForzaUse, WitUse, AgileUse];
                                _  ->
                                    [0, 0, 0, 0, 0]
                            end
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 宠物休息
%% -----------------------------------------------------------------
rest_pet(Status, [PetId]) ->
    ?DEBUG("rest_pet: PetId=[~p]", [PetId]),
    Pet = lib_pet:get_pet(PetId),
    if  % 宠物不存在
        Pet =:= []  -> [2, 0, 0, 0];
        true ->
            [PlayerId, ForzaUse, WitUse, AgileUse, FightFlag] = [Pet#ets_pet.player_id, Pet#ets_pet.forza_use, Pet#ets_pet.wit_use, Pet#ets_pet.agile_use, Pet#ets_pet.fight_flag],
            if  % 该宠物不归你所有
                PlayerId /= Status#player_status.id -> [3, 0, 0, 0];
                % 宠物已经休息
                FightFlag == 0 -> [4, 0, 0, 0];
                true ->
                     case lib_pet:rest_pet(PetId) of
                         ok  ->
                             % 更新缓存
                             PetNew = Pet#ets_pet{fight_flag        = 0,
                                                  fight_icon_pos    = 0,
                                                  strength_nexttime = 0},
                             lib_pet:update_pet(PetNew),
                             [1, ForzaUse, WitUse, AgileUse];
                         _   ->
                             [0, 0, 0, 0]
                     end
            end
    end.

%% -----------------------------------------------------------------
%% 属性洗练
%% -----------------------------------------------------------------
shuffle_attribute(Status, [PetId, PayType, GoodsId, GoodsUseNum]) ->
    ?DEBUG("shuffle_attribute: PetId=[~p], PayType=[~p], GoodsId=[~p], GoodsUseNum=[~p]", [PetId, PayType,GoodsId, GoodsUseNum]),
    Pet = lib_pet:get_pet(PetId),
    if  % 宠物不存在
        Pet =:= []  -> [2, 0, 0, 0, 0];
        true ->
            [PlayerId, ShuffleCount, FightFlag] = [Pet#ets_pet.player_id, Pet#ets_pet.attribute_shuffle_count, Pet#ets_pet.fight_flag],
            if  % 该宠物不归你所有
                PlayerId /= Status#player_status.id -> [3, 0, 0, 0, 0];
                % 宠物正在战斗
                FightFlag == 1 -> [4, 0, 0, 0, 0];
                true ->
                    case PayType of
                        % 银两支付
                        0 ->
                            ShuffleMoney = data_pet:get_pet_config(shuffle_money,[]),
                            if  % 金币不够
                                Status#player_status.gold < ShuffleMoney -> [5, 0, 0, 0, 0];
                                true ->
                                    case lib_pet:shuffle_attribute(Status#player_status.id, PetId, PayType, ShuffleCount, GoodsId, Status#player_status.gold, ShuffleMoney) of
                                        [ok, BaseForzaNew, BaseWitNew, BaseAgileNew]  ->
                                            % 更新缓存
                                            PetNew = Pet#ets_pet{
                                                base_forza_new          = BaseForzaNew,
                                                base_wit_new            = BaseWitNew,
                                                base_agile_new          = BaseAgileNew,
                                                attribute_shuffle_count = ShuffleCount+1},
                                            lib_pet:update_pet(PetNew),
                                            [1, BaseForzaNew, BaseWitNew, BaseAgileNew, Status#player_status.gold-ShuffleMoney];
                                        _   ->
                                            [0, 0, 0, 0, 0]
                                    end
                            end;
                        % 物品支付
                        1 ->
                            Goods = lib_pet:get_goods(GoodsId),
                            if  % 物品不存在
                                Goods =:= [] -> [6, 0, 0, 0, 0];
                                true ->
                                    [GoodsPlayerId, _GoodsTypeId, GoodsType, GoodsSubtype, GoodsNum, _GoodsCell]  =
                                         [Goods#goods.player_id, Goods#goods.goods_id, Goods#goods.type, Goods#goods.subtype, Goods#goods.num, Goods#goods.cell],
                                    [ShuffleGoodsType, ShuffleGoodsSubType] = data_pet:get_pet_config(attribute_shuffle_goods_type,[]),
                                    if  % 物品不归你所有
                                        GoodsPlayerId /= Status#player_status.id -> [7, 0, 0, 0, 0];
                                        % 该物品不是洗练药水
                                        ((GoodsType /= ShuffleGoodsType) and (GoodsSubtype /= ShuffleGoodsSubType)) -> [8, 0, 0, 0, 0];
                                        % 物品数量不够
                                        GoodsNum < GoodsUseNum -> [9, 0, 0, 0, 0];
                                        true ->
                                            case gen_server:call(Status#player_status.goods_pid, {'delete_one', GoodsId, GoodsUseNum}) of
                                                [1, _GoodsNumNew] ->
                                                    case lib_pet:shuffle_attribute(Status#player_status.id, PetId, PayType, ShuffleCount, GoodsId, GoodsNum, GoodsUseNum) of
                                                        [ok, BaseForzaNew, BaseWitNew, BaseAgileNew]  ->
                                                            % 更新缓存
                                                            PetNew = Pet#ets_pet{base_forza_new          = BaseForzaNew,
                                                                                 base_wit_new            = BaseWitNew,
                                                                                 base_agile_new          = BaseAgileNew,
                                                                                 attribute_shuffle_count = ShuffleCount+1},
                                                            lib_pet:update_pet(PetNew),
                                                            [1, BaseForzaNew, BaseWitNew, BaseAgileNew, Status#player_status.gold];
                                                        _   ->
                                                             [0, 0, 0, 0, 0]
                                                    end;
                                                [GoodsModuleCode, 0] ->
                                                    ?DEBUG("shuffle_attribute: Call goods module faild, result code=[~p]", [GoodsModuleCode]),
                                                    [0, 0, 0, 0, 0]
                                            end
                                    end
                            end;
                        % 支付类型未知
                        _ ->
                            ?ERR("shuffle_attribute: Unknow pay type, type=[~p]", [PayType]),
                            [0, 0, 0, 0, 0]
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 洗练属性使用
%% -----------------------------------------------------------------
use_attribute(Status, [PetId, ActionType]) ->
    ?DEBUG("use_attribute: PetId=[~p], ActionType=[~p]", [PetId, ActionType]),
    Pet = lib_pet:get_pet(PetId),
    if  % 宠物不存在
        Pet =:= []  -> [2, 0, 0, 0, 0, 0, 0];
        true ->
            [PlayerId, Level, Strength, Forza, Wit, Agile, ForzaUse, WitUse, AgileUse, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile, BaseForzaNew, BaseWitNew, BaseAgileNew, FightFlag] = [Pet#ets_pet.player_id, Pet#ets_pet.level, Pet#ets_pet.strength, Pet#ets_pet.forza, Pet#ets_pet.wit, Pet#ets_pet.agile, Pet#ets_pet.forza_use, Pet#ets_pet.wit_use, Pet#ets_pet.agile_use, Pet#ets_pet.aptitude_forza, Pet#ets_pet.aptitude_wit, Pet#ets_pet.aptitude_agile, Pet#ets_pet.base_forza, Pet#ets_pet.base_wit, Pet#ets_pet.base_agile, Pet#ets_pet.base_forza_new, Pet#ets_pet.base_wit_new, Pet#ets_pet.base_agile_new, Pet#ets_pet.fight_flag],
            if  % 该宠物不归你所有
                PlayerId /= Status#player_status.id -> [3, 0, 0, 0, 0, 0, 0];
                % 宠物正在战斗
                FightFlag == 1 -> [4, 0, 0, 0, 0, 0, 0];
                % 宠物没有洗练过
                ((BaseForzaNew==0) and (BaseWitNew==0) and (BaseAgileNew==0)) -> [5, 0, 0, 0, 0, 0, 0];
                true ->
                    case ActionType of
                        % 保留原有基础属性
                        0 ->
                            case lib_pet:use_attribute(PetId, BaseForza, BaseWit, BaseAgile, AptitudeForza, AptitudeWit, AptitudeAgile, Level, Strength) of
                                [ok, _NewForza, _NewWit, _NewAgile, _NewForzaUse, _NewWitUse, _NewAgileUse]  ->
                                     % 更新缓存
                                     PetNew = Pet#ets_pet{base_forza_new = 0,
                                                          base_wit_new   = 0,
                                                          base_agile_new = 0},
                                     lib_pet:update_pet(PetNew),
                                     [1, Forza, Wit, Agile, 0, 0, 0];
                                _  ->
                                    [0, 0, 0, 0, 0, 0, 0]
                            end;
                        % 使用新基础属性
                        1 ->
                            case lib_pet:use_attribute(PetId, BaseForzaNew, BaseWitNew, BaseAgileNew, AptitudeForza, AptitudeWit, AptitudeAgile, Level, Strength) of
                                 [ok, NewForza, NewWit, NewAgile, NewForzaUse, NewWitUse, NewAgileUse]  ->
                                     % 更新缓存
                                     PetNew = Pet#ets_pet{forza          = NewForza,
                                                          wit            = NewWit,
                                                          agile          = NewAgile,
                                                          forza_use      = NewForzaUse,
                                                          wit_use        = NewWitUse,
                                                          agile_use      = NewAgileUse,
                                                          base_forza     = BaseForzaNew,
                                                          base_wit       = BaseWitNew,
                                                          base_agile     = BaseAgileNew,
                                                          base_forza_new = 0,
                                                          base_wit_new   = 0,
                                                          base_agile_new = 0},
                                     lib_pet:update_pet(PetNew),
                                     [1, NewForza, NewWit, NewAgile, NewForzaUse-ForzaUse, NewWitUse-WitUse, NewAgileUse-AgileUse];
                                _  ->
                                    [0, 0, 0, 0, 0, 0, 0]
                            end;
                        _ ->
                            ?ERR("use_attribute: Unknow action type, type=[~p]", [ActionType]),
                            [0, 0, 0, 0, 0, 0, 0]
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 宠物开始升级
%% -----------------------------------------------------------------
start_upgrade(Status, [PetId]) ->
    ?DEBUG("start_upgrade, PetId=[~p]", [PetId]),
    Pet = lib_pet:get_pet(PetId),
    if  % 宠物不存在
        Pet =:= []  -> [2, 0, 0];
        true ->
            [PlayerId, Level, Quality, UpgradeFlag] = [Pet#ets_pet.player_id, Pet#ets_pet.level, Pet#ets_pet.quality, Pet#ets_pet.upgrade_flag],
            MaxLevel = data_pet:get_pet_config(maxinum_level, []),
            if  % 该宠物不归你所有
                PlayerId /= Status#player_status.id -> [3, 0, 0];
                % 宠物已经在升级
                UpgradeFlag == 1 -> [4, 0, 0];
                % 宠物等级已经和玩家等级相等
                Level == Status#player_status.lv -> [5, 0, 0];
                % 宠物已升到最高级
                Level >= MaxLevel -> [6, 0, 0];
                true ->
                    QueNum       = Status#player_status.pet_upgrade_que_num,
                    UpgradingPet = lib_pet:get_upgrading_pet(PlayerId),
                    if  % 宠物升级队列已满
                        length(UpgradingPet) >= QueNum -> [7, 0, 0];
                        true ->
                            [UpgradeMoney, UpgradeTime] = data_pet:get_upgrade_info(Quality, Level),
                            if  % 铜币不够
                                Status#player_status.coin < UpgradeMoney -> [8, 0, 0];
                                true ->
                                    NowTime = util:unixtime(),
                                    UpgradeEndTime = NowTime+UpgradeTime,
                                    case lib_pet:pet_start_upgrade(Status#player_status.id, PetId, UpgradeEndTime, UpgradeMoney) of
                                        ok  ->
                                            % 更新缓存
                                            PetNew = Pet#ets_pet{upgrade_flag    = 1,
                                                                 upgrade_endtime = UpgradeEndTime},
                                            lib_pet:update_pet(PetNew),
                                            [1, UpgradeTime, Status#player_status.coin-UpgradeMoney];
                                        _   -> [0, 0, 0]
                                    end
                            end
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 宠物升级加速
%% -----------------------------------------------------------------
shorten_upgrade(Status, [PetId, ShortenTime]) ->
    ?DEBUG("shorten_upgrade, PetId=[~p], ShortenTime=[~p]", [PetId, ShortenTime]),
    Pet = lib_pet:get_pet(PetId),
    if  % 宠物不存在
        Pet =:= []  -> [2, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        true ->
            [PlayerId, Level, Strength, Forza, Wit, Agile, ForzaUse, WitUse, AgileUse, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile, UpgradeFlag, UpgradeEndTime] =
                [Pet#ets_pet.player_id, Pet#ets_pet.level, Pet#ets_pet.strength, Pet#ets_pet.forza, Pet#ets_pet.wit, Pet#ets_pet.agile, Pet#ets_pet.forza_use, Pet#ets_pet.wit_use, Pet#ets_pet.agile_use, Pet#ets_pet.aptitude_forza, Pet#ets_pet.aptitude_wit, Pet#ets_pet.aptitude_agile, Pet#ets_pet.base_forza, Pet#ets_pet.base_wit, Pet#ets_pet.base_agile, Pet#ets_pet.upgrade_flag, Pet#ets_pet.upgrade_endtime],
            if  % 该宠物不归你所有
                PlayerId /= Status#player_status.id -> [3, 0, 0, 0, 0, 0, 0, 0, 0, 0];
                % 宠物不在升级
                UpgradeFlag == 0 -> [4, 0, 0, 0, 0, 0, 0, 0, 0, 0];
                true ->
                     ShortenMoney = lib_pet:calc_shorten_money(ShortenTime),
                     if  % 金币不够
                         Status#player_status.gold < ShortenMoney -> [5, 0, 0, 0, 0, 0, 0, 0, 0, 0];
                         true ->
                             UpgradeEndTimeNew = UpgradeEndTime-ShortenTime,
                             MoneyLeft = Status#player_status.gold-ShortenMoney,
                             case lib_pet:check_upgrade_state(Status#player_status.id, PetId, Level, Strength, UpgradeFlag, UpgradeEndTimeNew, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile, ShortenMoney) of
                                  % 宠物不在升级
                                  [0, _UpgradeLeftTime] ->
                                      [4, 0, 0, 0, 0, 0, 0, 0, 0, 0];
                                   % 宠物还在升级
                                  [1, UpgradeLeftTime] -> 
                                      case lib_pet:shorten_upgrade(Status#player_status.id, PetId, UpgradeEndTimeNew, ShortenMoney) of
                                          ok ->
                                              % 更新缓存
                                              PetNew = Pet#ets_pet{upgrade_flag    = 1,
                                                                   upgrade_endtime = UpgradeEndTimeNew},
                                              lib_pet:update_pet(PetNew),
                                              [1, Level, Forza, Wit, Agile, 0, 0, 0, UpgradeLeftTime, MoneyLeft];
                                          _  ->
                                              [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
                                      end;
                                  % 宠物升完级
                                  [2, UpgradeLeftTime, NewLevel, NewForza, NewWit, NewAgile, NewForzaUse, NewWitUse, NewAgileUse] ->
                                      % 更新缓存
                                      PetNew = Pet#ets_pet{upgrade_flag    = 0,
                                                           upgrade_endtime = 0,
                                                           level           = NewLevel,
                                                           forza           = NewForza,
                                                           wit             = NewWit,
                                                           agile           = NewAgile,
                                                           forza_use       = NewForzaUse,
                                                           wit_use         = NewWitUse,
                                                           agile_use       = NewAgileUse
                                                           },
                                      lib_pet:update_pet(PetNew),
                                      [1, NewLevel, NewForza, NewWit, NewAgile, NewForzaUse-ForzaUse, NewWitUse-WitUse, NewAgileUse-AgileUse, UpgradeLeftTime, MoneyLeft];
                                  % 其他情况
                                     _ -> [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
                             end
                     end
            end
    end.

%% -----------------------------------------------------------------
%% 宠物完成升级
%% -----------------------------------------------------------------
finish_upgrade(Status, [PetId]) ->
    ?DEBUG("finish_upgrade, PetId=[~p]", [PetId]),
    Pet = lib_pet:get_pet(PetId),
    if  % 宠物不存在
        Pet =:= []  -> [2, 0, 0, 0, 0, 0, 0, 0];
        true ->
            [PlayerId, Level, Strength, _Forza, _Wit, _Agile, ForzaUse, WitUse, AgileUse, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile, UpgradeFlag, UpgradeEndTime] =
                [Pet#ets_pet.player_id, Pet#ets_pet.level, Pet#ets_pet.strength, Pet#ets_pet.forza, Pet#ets_pet.wit, Pet#ets_pet.agile, Pet#ets_pet.forza_use, Pet#ets_pet.wit_use, Pet#ets_pet.agile_use, Pet#ets_pet.aptitude_forza, Pet#ets_pet.aptitude_wit, Pet#ets_pet.aptitude_agile, Pet#ets_pet.base_forza, Pet#ets_pet.base_wit, Pet#ets_pet.base_agile, Pet#ets_pet.upgrade_flag, Pet#ets_pet.upgrade_endtime],
            if  % 该宠物不归你所有
                PlayerId /= Status#player_status.id -> [3, 0, 0, 0, 0, 0, 0, 0];
                true ->
                    case lib_pet:check_upgrade_state(Status#player_status.id, PetId, Level, Strength, UpgradeFlag, UpgradeEndTime, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile, 0) of
                        % 宠物不在升级
                        [0, _UpgradeLeftTime] -> [4, 0, 0, 0, 0, 0, 0, 0];
                        % 宠物还在升级
                        [1, _UpgradeLeftTime] -> [5, 0, 0, 0, 0, 0, 0, 0];
                        % 宠物升完级
                        [2, _UpgradeLeftTime, NewLevel, NewForza, NewWit, NewAgile, NewForzaUse, NewWitUse, NewAgileUse] ->
                            ?DEBUG("finish_upgrade: NewLevel=[~p], NewForza=[~p], NewWit=[~p], NewAgile=[~p], NewForzaUse=[~p], NewWitUse=[~p], NewAgileUse=[~p], ForzaUse=[~p], WitUse=[~p], AgileUse=[~p]", [NewLevel, NewForza, NewWit, NewAgile, NewForzaUse, NewWitUse, NewAgileUse, ForzaUse, WitUse, AgileUse]),
                            % 更新缓存
                            PetNew = Pet#ets_pet{upgrade_flag    = 0,
                                                 upgrade_endtime = 0,
                                                 level           = NewLevel,
                                                 forza           = NewForza,
                                                 wit             = NewWit,
                                                 agile           = NewAgile,
                                                 forza_use       = NewForzaUse,
                                                 wit_use         = NewWitUse,
                                                 agile_use       = NewAgileUse
                                                },
                            lib_pet:update_pet(PetNew),
                            [1, NewLevel, NewForza, NewWit, NewAgile, NewForzaUse-ForzaUse, NewWitUse-WitUse, NewAgileUse-AgileUse];
                        _ -> [0, 0, 0, 0, 0, 0, 0, 0]
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 扩展升级队列
%% -----------------------------------------------------------------
extent_upgrade_que(Status, []) ->
    MaxQueNum = data_pet:get_pet_config(maxinum_que_num, []),
    QueNum    = Status#player_status.pet_upgrade_que_num,
    ?DEBUG("extent_upgrade_que: MaxQueNum=[~p], QueNum=[~p]", [MaxQueNum, QueNum]),
    if  % 已达到最大队列上限
        QueNum >= MaxQueNum -> [2, 0, 0];
        true ->
            NewQueNum = QueNum+1,
            ExtentQueMoney = data_pet:get_pet_config(extent_que_money, [NewQueNum]),
            if  % 金币不够
                Status#player_status.gold < ExtentQueMoney -> [3, 0, 0];
                true ->
                    case lib_pet:extent_upgrade_que(Status#player_status.id, NewQueNum, ExtentQueMoney) of
                        ok -> [1, NewQueNum, Status#player_status.gold-ExtentQueMoney];
                        _  -> [0, 0, 0]
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 宠物喂养
%% -----------------------------------------------------------------
feed_pet(Status, [PetId, GoodsId, GoodsUseNum]) ->
    ?DEBUG("feed_pet, PetId=[~p], GoodsId=[~p], GoodsUseNum=[~p]", [PetId, GoodsId, GoodsUseNum]),
    if  % 你已经死亡
        Status#player_status.hp =< 0 -> [2, 0, 0, 0, 0, 0, 0, 0];
        true ->
            Pet = lib_pet:get_pet(PetId),
            if  % 宠物不存在
                Pet =:= []  -> [3, 0, 0, 0, 0, 0, 0, 0];
                true ->
                    [PlayerId, Level, PetStrength, PetStrengThreshold, PetQuality, Forza, Wit, Agile, ForzaUse, WitUse, AgileUse, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile] =
                        [Pet#ets_pet.player_id, Pet#ets_pet.level, Pet#ets_pet.strength, Pet#ets_pet.strength_threshold, Pet#ets_pet.quality, Pet#ets_pet.forza, Pet#ets_pet.wit, Pet#ets_pet.agile, Pet#ets_pet.forza_use, Pet#ets_pet.wit_use, Pet#ets_pet.agile_use, Pet#ets_pet.aptitude_forza, Pet#ets_pet.aptitude_wit, Pet#ets_pet.aptitude_agile, Pet#ets_pet.base_forza, Pet#ets_pet.base_wit, Pet#ets_pet.base_agile],
                    if  % 宠物不归你所有
                        PlayerId /= Status#player_status.id -> [4, 0, 0, 0, 0, 0, 0, 0];
                        % 宠物体力值已满
                        PetStrength == PetStrengThreshold -> [5, 0, 0, 0, 0, 0, 0, 0];
                        true ->
                            Goods = lib_pet:get_goods(GoodsId),
                            if  % 物品不存在
                                Goods =:= []  -> [6, 0, 0, 0, 0, 0, 0, 0];
                                true ->
                                    [FoodGoodsType, FoodGoodsSubType] = data_pet:get_pet_config(food_goods_type,[]),
                                    [GoodsPlayerId, GoodsTypeId, GoodsType, GoodsSubtype, GoodsNum, _GoodsCell, GoodsColor]  =
                                         [Goods#goods.player_id, Goods#goods.goods_id, Goods#goods.type, Goods#goods.subtype, Goods#goods.num, Goods#goods.cell, Goods#goods.color],
                                    if  % 物品不归你所有
                                        GoodsPlayerId /= Status#player_status.id -> [7, 0, 0, 0, 0, 0, 0, 0];
                                        % 该物品不是食物
                                        ((GoodsType /= FoodGoodsType) and (GoodsSubtype /= FoodGoodsSubType)) -> [8, 0, 0, 0, 0, 0, 0, 0];
                                        % 食物品阶不够
                                        GoodsColor < PetQuality -> [10, 0, 0, 0, 0, 0, 0, 0];
                                        true ->
                                            if  % 单个物品数量不够
                                                GoodsNum < GoodsUseNum ->
                                                    % 试图扣取多个格子物品
                                                    case gen_server:call(Status#player_status.goods_pid, {'delete_more', GoodsTypeId, GoodsUseNum}) of
                                                        1 ->
                                                            case lib_pet:feed_pet(PetId, PetQuality, GoodsColor, GoodsUseNum, PetStrength, PetStrengThreshold, Level, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile) of
                                                                % 体力值变化且影响了力智敏
                                                                [ok, NewStrength, NewForza, NewWit, NewAgile, NewForzaUse, NewWitUse, NewAgileUse] ->
                                                                    % 更新缓存
                                                                    PetNew = Pet#ets_pet{strength        = NewStrength,
                                                                                         forza           = NewForza,
                                                                                         wit             = NewWit,
                                                                                         agile           = NewAgile,
                                                                                         forza_use       = NewForzaUse,
                                                                                         wit_use         = NewWitUse,
                                                                                         agile_use       = NewAgileUse
                                                                                        },
                                                                    lib_pet:update_pet(PetNew),
                                                                    [1, NewStrength, NewForza, NewWit, NewAgile, NewForzaUse-ForzaUse, NewWitUse-WitUse, NewAgileUse-AgileUse];
                                                                % 体力值变化但不影响力智敏
                                                                [ok, NewStrength]  ->
                                                                    % 更新缓存
                                                                    PetNew = Pet#ets_pet{strength        = NewStrength
                                                                                        },
                                                                    lib_pet:update_pet(PetNew),
                                                                    [1, NewStrength, Forza, Wit, Agile, 0, 0, 0];
                                                                % 出错
                                                                _   -> [0, 0, 0, 0, 0, 0, 0, 0]
                                                            end;
                                                        % 扣取物品失败
                                                        0 ->
                                                            ?DEBUG("feed_pet: Call goods module faild", []),
                                                            [0, 0, 0, 0, 0, 0, 0, 0];
                                                        % 物品数量不够
                                                        _ ->
                                                            [9, 0, 0, 0, 0, 0, 0, 0]
                                                    end;
                                                % 单个物品数量足够
                                                true ->
                                                    % 扣取物品
                                                    case gen_server:call(Status#player_status.goods_pid, {'delete_one', GoodsId, GoodsUseNum}) of
                                                        % 扣取物品成功
                                                        [1, _GoodsNumNew] ->
                                                            case lib_pet:feed_pet(PetId, PetQuality, GoodsColor, GoodsUseNum, PetStrength, PetStrengThreshold, Level, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile) of
                                                                % 体力值变化且影响力智敏
                                                                [ok, NewStrength, NewForza, NewWit, NewAgile, NewForzaUse, NewWitUse, NewAgileUse] ->
                                                                    % 更新缓存
                                                                    PetNew = Pet#ets_pet{strength        = NewStrength,
                                                                                         forza           = NewForza,
                                                                                         wit             = NewWit,
                                                                                         agile           = NewAgile,
                                                                                         forza_use       = NewForzaUse,
                                                                                         wit_use         = NewWitUse,
                                                                                         agile_use       = NewAgileUse
                                                                                        },
                                                                    lib_pet:update_pet(PetNew),
                                                                    [1, NewStrength, NewForza, NewWit, NewAgile, NewForzaUse-ForzaUse, NewWitUse-WitUse, NewAgileUse-AgileUse];
                                                                % 体力值有变化但不影响力智敏
                                                                [ok, NewStrength]  ->
                                                                    % 更新缓存
                                                                    PetNew = Pet#ets_pet{strength        = NewStrength},
                                                                    lib_pet:update_pet(PetNew),
                                                                    [1, NewStrength, Forza, Wit, Agile, 0, 0, 0];
                                                                % 出错
                                                                _   -> [0, 0, 0, 0, 0, 0, 0, 0]
                                                            end;
                                                        % 扣取物品失败
                                                        [GoodsModuleCode, 0] ->
                                                            ?DEBUG("feed_pet: Call goods module faild, result code=[~p]", [GoodsModuleCode]),
                                                            [0, 0, 0, 0, 0, 0, 0, 0]
                                                    end
                                            end
                                    end
                            end
                     end
            end
    end.

%% -----------------------------------------------------------------
%% 宠物驯养
%% -----------------------------------------------------------------
domesticate_pet(Status, [PetId, DomesticateType, GoodsId, GoodsUseNum]) ->
    ?DEBUG("domesticate_pet, PetId=[~p], DomesticateType=[~p], GoodsId=[~p], GoodsUseNum=[~p]", [PetId, DomesticateType, GoodsId, GoodsUseNum]),
    Pet = lib_pet:get_pet(PetId),
    if  % 宠物不存在
        Pet =:= []  -> [2, 0, 0, 0, 0, 0];
        true ->
            [PlayerId, Level, Strength, Quality, _Forza, _Wit, _Agile, ForzaUse, WitUse, AgileUse, AptitudeForza, AptitudeWit, AptitudeAgile, BaseForza, BaseWit, BaseAgile] =
                [Pet#ets_pet.player_id, Pet#ets_pet.level, Pet#ets_pet.strength, Pet#ets_pet.quality, Pet#ets_pet.forza, Pet#ets_pet.wit, Pet#ets_pet.agile, Pet#ets_pet.forza_use, Pet#ets_pet.wit_use, Pet#ets_pet.agile_use, Pet#ets_pet.aptitude_forza, Pet#ets_pet.aptitude_wit, Pet#ets_pet.aptitude_agile, Pet#ets_pet.base_forza, Pet#ets_pet.base_wit, Pet#ets_pet.base_agile],
            if  % 该宠物不归你所有
                PlayerId /= Status#player_status.id -> [3, 0, 0, 0, 0, 0];
                true ->
                    Goods = lib_pet:get_goods(GoodsId),
                        if  % 物品不存在
                            Goods =:= []  -> [4, 0, 0, 0, 0, 0];
                            true ->
                                [GoodsPlayerId, GoodsTypeId, GoodsType, GoodsSubtype, GoodsNum, _GoodsCell, GoodsForza, GoodsWit, GoodsAgile]  =
                                     [Goods#goods.player_id, Goods#goods.goods_id, Goods#goods.type, Goods#goods.subtype, Goods#goods.num, Goods#goods.cell, Goods#goods.forza, Goods#goods.wit, Goods#goods.agile],
                                [BookGoodsType,  BookGoodsSubType] = data_pet:get_pet_config(attribute_book_goods_type,[]),
                                if  % 物品不归你所有
                                    GoodsPlayerId /= Status#player_status.id -> [5, 0, 0, 0, 0, 0];
                                    % 该物品不是训练书
                                    ((GoodsType /= BookGoodsType) and (GoodsSubtype /= BookGoodsSubType)) -> [7, 0, 0, 0, 0, 0];
                                    true ->
                                        AptitudeThreshold  = data_pet:get_pet_config(aptitude_threshold,[Quality]),
                                        if  % 单个物品数量不够
                                            GoodsNum < GoodsUseNum ->
                                                    % 试图扣取多个格子物品
                                                    case gen_server:call(Status#player_status.goods_pid, {'delete_more', GoodsTypeId, GoodsUseNum}) of
                                                        1 ->
                                                            case DomesticateType of
                                                                % 驯养力量
                                                                0 ->
                                                                    if  % 资质已经满
                                                                        AptitudeForza >= AptitudeThreshold -> [8, 0, 0, 0, 0, 0];
                                                                        true ->
                                                                            case lib_pet:domesticate_pet(PetId, DomesticateType, Level, Strength, AptitudeForza+GoodsUseNum*GoodsForza, AptitudeThreshold, BaseForza) of
                                                                                [ok, AptitudeForzaNew, ForzaNew, ForzaUseNew]  -> 
                                                                                    % 更新缓存
                                                                                    PetNew = Pet#ets_pet{aptitude_forza  = AptitudeForzaNew,
                                                                                                         forza           = ForzaNew,
                                                                                                         forza_use       = ForzaUseNew
                                                                                                },
                                                                                    lib_pet:update_pet(PetNew),
                                                                                    [1, AptitudeForzaNew, ForzaNew, ForzaUseNew-ForzaUse, 0, 0];
                                                                                _   -> [0, 0, 0, 0, 0, 0]
                                                                        end
                                                                    end;
                                                                % 驯养智力
                                                                1 ->
                                                                    if  % 资质已经满
                                                                        AptitudeWit >= AptitudeThreshold -> [8, 0, 0, 0, 0, 0];
                                                                        true ->
                                                                            case lib_pet:domesticate_pet(PetId, DomesticateType, Level, Strength, AptitudeWit+GoodsUseNum*GoodsWit, AptitudeThreshold,  BaseWit) of
                                                                                [ok, AptitudeWitNew, WitNew, WitUseNew]  -> 
                                                                                    % 更新缓存
                                                                                    PetNew = Pet#ets_pet{aptitude_wit  = AptitudeWitNew,
                                                                                                         wit           = WitNew,
                                                                                                         wit_use       = WitUseNew
                                                                                                        },
                                                                                    lib_pet:update_pet(PetNew),
                                                                                    [1, AptitudeWitNew, WitNew, 0, WitUseNew-WitUse, 0];
                                                                                _   -> [0, 0, 0, 0, 0, 0]
                                                                            end
                                                                    end;
                                                                % 驯养敏捷
                                                                2 ->
                                                                    if  % 资质已经满
                                                                        AptitudeAgile >= AptitudeThreshold -> [8, 0, 0, 0, 0, 0];
                                                                        true ->
                                                                            case lib_pet:domesticate_pet(PetId, DomesticateType, Level, Strength, AptitudeAgile+GoodsUseNum*GoodsAgile, AptitudeThreshold, BaseAgile) of
                                                                                [ok, AptitudeAgileNew, AgileNew, AgileUseNew]  -> 
                                                                                    % 更新缓存
                                                                                    PetNew = Pet#ets_pet{aptitude_agile  = AptitudeAgileNew,
                                                                                                         agile           = AgileNew,
                                                                                                         agile_use       = AgileUseNew
                                                                                                        },
                                                                                    lib_pet:update_pet(PetNew),
                                                                                    [1, AptitudeAgileNew, AgileNew, 0, 0, AgileUseNew-AgileUse];
                                                                                _   -> [0, 0, 0, 0, 0, 0]
                                                                            end
                                                                    end;
                                                                _ ->
                                                                    ?ERR("domesticate_pet: Unknow domesticate type, type=[~p]", [DomesticateType]),
                                                                    [0, 0, 0, 0, 0, 0]
                                                             end;
                                                        % 扣取物品失败
                                                        0 ->
                                                            ?DEBUG("domesticate_pet: Call goods module faild", []),
                                                            [0, 0, 0, 0, 0, 0];
                                                        % 物品数量不够
                                                        _ ->
                                                            [6, 0, 0, 0, 0, 0]
                                                    end;
                                            % 单个物品数量足够
                                            true ->
                                                % 扣取物品
                                                case gen_server:call(Status#player_status.goods_pid, {'delete_one', GoodsId, GoodsUseNum}) of
                                                    % 扣取物品成功
                                                    [1, _GoodsNumNew] ->
                                                        case DomesticateType of
                                                            % 驯养力量
                                                            0 ->
                                                                if  % 资质已经满
                                                                AptitudeForza >= AptitudeThreshold -> [8, 0, 0, 0, 0, 0];
                                                                    true ->
                                                                        case lib_pet:domesticate_pet(PetId, DomesticateType, Level, Strength, AptitudeForza+GoodsUseNum*GoodsForza, AptitudeThreshold, BaseForza) of
                                                                            [ok, AptitudeForzaNew, ForzaNew, ForzaUseNew]  ->
                                                                                % 更新缓存
                                                                                PetNew = Pet#ets_pet{aptitude_forza  = AptitudeForzaNew,
                                                                                                     forza           = ForzaNew,
                                                                                                     forza_use       = ForzaUseNew},
                                                                                lib_pet:update_pet(PetNew),
                                                                                [1, AptitudeForzaNew, ForzaNew, ForzaUseNew-ForzaUse, 0, 0];
                                                                            _   -> [0, 0, 0, 0, 0, 0]
                                                                        end
                                                                end;
                                                            % 驯养智力
                                                            1 ->
                                                                if  % 资质已经满
                                                                    AptitudeWit >= AptitudeThreshold -> [8, 0, 0, 0, 0, 0];
                                                                    true ->
                                                                        case lib_pet:domesticate_pet(PetId, DomesticateType, Level, Strength, AptitudeWit+GoodsUseNum*GoodsWit, AptitudeThreshold,  BaseWit) of
                                                                            [ok, AptitudeWitNew, WitNew, WitUseNew]  ->
                                                                                % 更新缓存
                                                                                PetNew = Pet#ets_pet{aptitude_wit  = AptitudeWitNew,
                                                                                                     wit           = WitNew,
                                                                                                     wit_use       = WitUseNew},
                                                                                lib_pet:update_pet(PetNew),
                                                                                [1, AptitudeWitNew, WitNew, 0, WitUseNew-WitUse, 0];
                                                                            _   -> [0, 0, 0, 0, 0, 0]
                                                                        end
                                                                end;
                                                            % 驯养敏捷
                                                            2 ->
                                                                if  % 资质已经满
                                                                    AptitudeAgile >= AptitudeThreshold -> [8, 0, 0, 0, 0, 0];
                                                                    true ->
                                                                        case lib_pet:domesticate_pet(PetId, DomesticateType, Level, Strength, AptitudeAgile+GoodsUseNum*GoodsAgile, AptitudeThreshold, BaseAgile) of
                                                                            [ok, AptitudeAgileNew, AgileNew, AgileUseNew]  ->
                                                                                % 更新缓存
                                                                                PetNew = Pet#ets_pet{aptitude_agile  = AptitudeAgileNew,
                                                                                                     agile           = AgileNew,
                                                                                                     agile_use       = AgileUseNew},
                                                                                lib_pet:update_pet(PetNew),
                                                                                [1, AptitudeAgileNew, AgileNew, 0, 0, AgileUseNew-AgileUse];
                                                                            _   -> [0, 0, 0, 0, 0, 0]
                                                                        end
                                                                end;
                                                            _ ->
                                                                ?ERR("domesticate_pet: Unknow domesticate type, type=[~p]", [DomesticateType]),
                                                                [0, 0, 0, 0, 0, 0]
                                                        end;
                                                    % 扣取物品失败
                                                    [GoodsModuleCode, 0] ->
                                                        ?DEBUG("domesticate_pet: Call goods module faild, result code=[~p]", [GoodsModuleCode]),
                                                        [0, 0, 0, 0, 0, 0]
                                                end
                                        end
                                end
                        end
            end
    end.

%% -----------------------------------------------------------------
%% 宠物进阶
%% -----------------------------------------------------------------
enhance_quality(Status, [PetId, GoodsId, GoodsUseNum]) ->
    ?DEBUG("enhance_quality: PetId=[~p], GoodsId=[~p], GoodsUseNum=[~p]", [PetId, GoodsId, GoodsUseNum]),
    Pet = lib_pet:get_pet(PetId),
    if  % 宠物不存在
        Pet =:= []  -> [2, 0, 0, 0];
        true ->
            [PlayerId, Level, Quality, UpgradeFlag, FightFlag] =
                [Pet#ets_pet.player_id, Pet#ets_pet.level,  Pet#ets_pet.quality, Pet#ets_pet.upgrade_flag, Pet#ets_pet.fight_flag],
            MaxQuality = data_pet:get_pet_config(maxinum_quality,[]),
            if  % 宠物不归你所有
                PlayerId /= Status#player_status.id -> [3, 0, 0, 0];
                % 宠物已经是最高品
                Quality  >= MaxQuality -> [4, 0, 0, 0];
                % 宠物正在升级
                UpgradeFlag == 1 -> [5, 0, 0, 0];
                % 宠物正在出战
                FightFlag == 1 -> [6, 0, 0, 0];
                true ->
                    %SuccessProbability = data_pet:get_pet_config(enhance_quality_probability,[Quality]),
                    BasePet            = lib_pet:get_base_pet(GoodsId),
                    SuccessProbability = case BasePet of
                                             [] -> ?ERR("enhance_quality: Not find the base_pet, goods_id=[~p]", [GoodsId]),
                                                   100;
                                             _ ->  BasePet#ets_base_pet.probability
                                         end,
                    Goods = lib_pet:get_goods(GoodsId),
                        if  % 物品不存在
                            Goods =:= []  -> [8, 0, 0, 0];
                            true ->
                                [GoodsPlayerId, _GoodsTypeId, GoodsType, GoodsSubtype, GoodsNum, _GoodsCell, GoodsColor, GoodsLevel]  =
                                    [Goods#goods.player_id, Goods#goods.goods_id, Goods#goods.type, Goods#goods.subtype, Goods#goods.num, Goods#goods.cell, Goods#goods.color, Goods#goods.level],
                                [StoneGoodsType, StoneGoodsSubType] = data_pet:get_pet_config(quality_stone_goods_type, []),
                                if  % 物品不归你所有
                                    GoodsPlayerId /= Status#player_status.id -> [9, 0, 0, 0];
                                    % 物品数量不够
                                    GoodsNum < GoodsUseNum -> [10, 0, 0, 0];
                                    % 级别不够
                                    Level < GoodsLevel ->  [7, 0, 0, 0];
                                    % 物品不是进化石
                                    ((GoodsType /=StoneGoodsType) and (GoodsSubtype /=StoneGoodsSubType)) -> [11, 0, 0, 0];
                                    true ->
                                        if  % 品阶不对
                                            Quality > GoodsColor -> [12, 0, 0, 0];
                                            true ->
                                                 case gen_server:call(Status#player_status.goods_pid, {'delete_one', GoodsId, GoodsUseNum}) of
                                                    [1, _GoodsNumNew] ->
                                                        case lib_pet:enhance_quality(PetId, Quality, SuccessProbability) of
                                                            [ok, EvolutionResult, QualityNew, AptitudeThresholdNew]  ->
                                                                % 更新缓存
                                                                PetNew = Pet#ets_pet{level              = 1,
                                                                                     quality            = QualityNew,
                                                                                     aptitude_threshold = AptitudeThresholdNew},
                                                                lib_pet:update_pet(PetNew),
                                                                [1, EvolutionResult, QualityNew, AptitudeThresholdNew];
                                                            _   ->
                                                                [0, 0, 0, 0]
                                                        end;
                                                    [GoodsModuleCode, 0] ->
                                                        ?DEBUG("enhance_quality: Call goods module faild, result code=[~p]", [GoodsModuleCode]),
                                                        [0, 0, 0, 0]
                                                 end
                                        end
                                end
                        end
            end
    end.
    
                            
%% -----------------------------------------------------------------
%% 获取宠物信息
%% -----------------------------------------------------------------
get_pet_info(_Status, [PetId]) ->
    ?DEBUG("get_pet_info, PetId=[~p]", [PetId]),
    lib_pet:get_pet_info(PetId).

%% -----------------------------------------------------------------
%% 获取宠物列表
%% -----------------------------------------------------------------
get_pet_list(_Status, [PlayerId]) ->
    ?DEBUG("get_pet_list, PlayerId=[~p]", [PlayerId]),
    lib_pet:get_pet_list(PlayerId).


%% -----------------------------------------------------------------
%% 宠物出战替换
%% -----------------------------------------------------------------
fighting_replace(Status, [PetId, ReplacedPetId]) ->
    ?DEBUG("fighting_pet: PetId=[~p], ReplacedPet=[~p]", [PetId, ReplacedPetId]),
    Pet = lib_pet:get_pet(PetId),
    if  % 宠物不存在
        Pet =:= []  -> [2, 0, 0, 0, 0];
        true ->
            [PlayerId, ForzaUse, WitUse, AgileUse, FightFlag, Strength] = [Pet#ets_pet.player_id, Pet#ets_pet.forza_use, Pet#ets_pet.wit_use, Pet#ets_pet.agile_use, Pet#ets_pet.fight_flag, Pet#ets_pet.strength],
            if  % 该宠物不归你所有
                PlayerId /= Status#player_status.id -> [3, 0, 0, 0, 0];
                % 宠物已经出战
                FightFlag == 1 -> [4, 0, 0, 0, 0];
                % 体力值为0
                Strength == 0 -> [5, 0, 0, 0, 0];
                true ->
                    Pet1 = lib_pet:get_pet(ReplacedPetId),
                    if  % 被替换宠物不存在
                        Pet1 =:= []  -> [6, 0, 0, 0, 0];
                        true ->
                            [PlayerId1, ForzaUse1, WitUse1, AgileUse1, FightFlag1, IconPos1] = [Pet1#ets_pet.player_id, Pet1#ets_pet.forza_use, Pet1#ets_pet.wit_use, Pet1#ets_pet.agile_use, Pet1#ets_pet.fight_flag, Pet1#ets_pet.fight_icon_pos],
                            if  % 被替换宠物不归你所有
                                PlayerId1 /= Status#player_status.id -> [7, 0, 0, 0, 0];
                                % 被替换宠物未出战
                                FightFlag1 == 0 -> [8, 0, 0, 0, 0];
                                true ->
                                    case lib_pet:fighting_replace(PetId, ReplacedPetId, IconPos1) of
                                        ok  ->
                                            [IntervalSync, _StrengthSync] = data_pet:get_pet_config(strength_sync, []),
                                            NowTime = util:unixtime(),
                                            % 更新缓存
                                            PetNew = Pet#ets_pet{fight_flag        = 1,
                                                                 fight_icon_pos    = IconPos1,
                                                                 strength_nexttime = NowTime+IntervalSync},
                                            lib_pet:update_pet(PetNew),
                                            PetNew1 = Pet1#ets_pet{fight_flag        = 0,
                                                                   fight_icon_pos    = 0,
                                                                   strength_nexttime = 0},
                                            lib_pet:update_pet(PetNew1),
                                            [1, IconPos1, ForzaUse-ForzaUse1, WitUse-WitUse1, AgileUse-AgileUse1];
                                        _   ->
                                            [0, 0, 0, 0, 0]
                                    end
                            end
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 取消升级
%% -----------------------------------------------------------------
cancel_upgrade(Status, [PetId]) ->
    ?DEBUG("cancel_upgrade: PetId=[~p]", [PetId]),
    Pet = lib_pet:get_pet(PetId),
    if  % 宠物不存在
        Pet =:= []  -> 2;
        true ->
            [PlayerId, UpgradeFlag] = [Pet#ets_pet.player_id, Pet#ets_pet.upgrade_flag],
            if  % 该宠物不归你所有
                PlayerId /= Status#player_status.id -> 3;
                % 宠物不在升级
                UpgradeFlag == 0 -> 4;
                true ->
                    case lib_pet:cancel_upgrade(PetId) of
                        ok  ->
                            % 更新缓存
                            PetNew = Pet#ets_pet{upgrade_flag    = 0,
                                                 upgrade_endtime = 0},
                            lib_pet:update_pet(PetNew),
                            1;
                        _   -> 0
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 体力值同步
%% -----------------------------------------------------------------
strength_sync(Status, []) ->
    %?DEBUG("strength_sync: PlayerId=[~p]", [Status#player_status.id]),
    FightingPet  = lib_pet:get_fighting_pet(Status#player_status.id),
    NowTime = util:unixtime(),
    [RecordsNum, RecordsData, TotalForzaUse, TotalWitUse, TotalAgileUse] = lib_pet:strength_sync(FightingPet, NowTime, 0, <<>>, 0, 0, 0),
    %?DEBUG("strength_sync: RecordsNum=[~p]", [RecordsNum]),
    [1, RecordsNum, RecordsData, TotalForzaUse, TotalWitUse, TotalAgileUse].