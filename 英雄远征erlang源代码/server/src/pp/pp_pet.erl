%%%--------------------------------------
%%% @Module  : pp_pet
%%% @Author  : shebiao
%%% @Email   : shebiao@jieyou.com
%%% @Created : 2010.07.03
%%% @Description: 宠物
%%%--------------------------------------
-module(pp_pet).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%=========================================================================
%% 接口函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 宠物孵化
%% -----------------------------------------------------------------
handle(41001, Status, [GoodsId, GoodsUseNum]) ->
    [Result, PetId, PetName] = mod_pet:incubate_pet(Status, [GoodsId, GoodsUseNum]),
    {ok, BinData} = pt_41:write(41001, [Result, PetId, PetName]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 宠物放生
%% -----------------------------------------------------------------
handle(41002, Status, [PetId]) ->
    Result = mod_pet:free_pet(Status, [PetId]),
    {ok, BinData} = pt_41:write(41002, [Result, PetId]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 宠物改名
%% -----------------------------------------------------------------
handle(41003, Status, [PetId, PetName]) ->
    [Result, MoneyUseFlag, MoneyLeft] = mod_pet:rename_pet(Status, [PetId, PetName]),
    if  % 改名成功且需要钱
        ((Result == 1) and (MoneyUseFlag == 1)) ->
            % 发送回应
            {ok, BinData} = pt_41:write(41003, [Result, PetId, lib_pet:make_sure_binary(PetName), MoneyUseFlag, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 更新金币
            Status1 = Status#player_status{gold = MoneyLeft},
            % 返回新状态
            {ok, Status1};
        true ->
            % 发送回应
            {ok, BinData} = pt_41:write(41003, [Result, PetId, lib_pet:make_sure_binary(PetName), MoneyUseFlag, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 宠物出战
%% -----------------------------------------------------------------
handle(41004, Status, [PetId, FightIconPos]) ->
    [Result, IconPos, ForzaUse, WitUse, AgileUse] = mod_pet:fighting_pet(Status, [PetId, FightIconPos]),
    if  Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_41:write(41004, [Result, PetId, IconPos]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 角色属性加点
            Status1 = lib_pet:calc_player_attribute(add, Status, ForzaUse, WitUse, AgileUse),
            % 返回新状态
            {ok, Status1};
        true ->
            {ok, BinData} = pt_41:write(41004, [Result, PetId, IconPos]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;
    

%% -----------------------------------------------------------------
%% 宠物休息
%% -----------------------------------------------------------------
handle(41005, Status, [PetId]) ->
    [Result, ForzaUse, WitUse, AgileUse] = mod_pet:rest_pet(Status, [PetId]),
    if  Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_41:write(41005, [Result, PetId]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 角色属性减点
            Status1 = lib_pet:calc_player_attribute(deduct, Status, ForzaUse, WitUse, AgileUse),
            % 返回新状态
            {ok, Status1};
        true ->
            {ok, BinData} = pt_41:write(41005, [Result, PetId]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 属性洗练
%% -----------------------------------------------------------------
handle(41006, Status, [PetId, PayType, GoodsId, GoodsUseNum]) ->
    [Result, BaseForza, BaseWit, BaseAgile, MoneyLeft] = mod_pet:shuffle_attribute(Status, [PetId, PayType, GoodsId, GoodsUseNum]),
    if  % 使用金币洗练成功
        ((Result == 1) and (PayType == 0)) ->
            % 发送回应
            {ok, BinData} = pt_41:write(41006, [Result, PetId, PayType, BaseForza, BaseWit, BaseAgile, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 更新金币
            Status1 = Status#player_status{gold = MoneyLeft},
            % 返回新状态
            {ok, Status1};
        % 其他情况
        true ->
            % 发送回应
            {ok, BinData} = pt_41:write(41006, [Result, PetId, PayType, BaseForza, BaseWit, BaseAgile, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 洗练属性使用
%% -----------------------------------------------------------------
handle(41007, Status, [PetId, ActionType]) ->
    [Result, Forza, Wit, Agile, DiffForzaUse, DiffWitUse, DiffAgileUse] = mod_pet:use_attribute(Status, [PetId, ActionType]),
    if  % 使用新基础属性成功且力智敏有变化
        ((ActionType == 1) and (Result == 1) and ((DiffForzaUse /= 0) or (DiffWitUse /= 0) or (DiffAgileUse /= 0))) ->
            % 发送回应
            {ok, BinData} = pt_41:write(41007, [Result, PetId, ActionType, Forza, Wit, Agile]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 角色属性加点
            Status1 = lib_pet:calc_player_attribute(add, Status, DiffForzaUse, DiffWitUse, DiffAgileUse),
            % 返回新状态
            {ok, Status1};
        true ->
            {ok, BinData} = pt_41:write(41007, [Result, PetId, ActionType, Forza, Wit, Agile]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 宠物开始升级
%% -----------------------------------------------------------------
handle(41008, Status, [PetId]) ->
[Result, LeftTime, MoneyLeft] = mod_pet:start_upgrade(Status, [PetId]),
    if  % 升级成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_41:write(41008, [Result, PetId, LeftTime, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 更新铜币
            Status1 = Status#player_status{coin = MoneyLeft},
            % 返回新状态
            {ok, Status1};
        true ->
            % 发送回应
            {ok, BinData} = pt_41:write(41008, [Result, PetId, LeftTime, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 宠物升级加速
%% -----------------------------------------------------------------
handle(41009, Status, [PetId, ShortenTime]) ->
[Result, Level, Forza, Wit, Agile, DiffForzaUse, DiffWitUse, DiffAgileUse, LeftTime, MoneyLeft] = mod_pet:shorten_upgrade(Status, [PetId, ShortenTime]),
    if  % 升级且力智敏有变化
        ((Result == 1) and (LeftTime==0) and ((DiffForzaUse /= 0) or (DiffWitUse /= 0) or (DiffAgileUse /= 0))) ->
            % 发送回应
            {ok, BinData} = pt_41:write(41009, [Result, PetId, ShortenTime, MoneyLeft, LeftTime, Level, Forza, Wit, Agile]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 角色属性减点
            Status1 = lib_pet:calc_player_attribute(add, Status, DiffForzaUse, DiffWitUse, DiffAgileUse),
            % 更新金币
            Status2 = Status1#player_status{gold = MoneyLeft},
            % 返回新状态
            {ok, Status2};
        % 虽然没有升级但扣取了铜币
        ((Result == 1) and (LeftTime > 0)) ->
            % 发送回应
            {ok, BinData} = pt_41:write(41009, [Result, PetId, ShortenTime, MoneyLeft, LeftTime, Level, Forza, Wit, Agile]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 更新金币
            Status2 = Status#player_status{gold = MoneyLeft},
            % 返回新状态
            {ok, Status2};
        true ->
            {ok, BinData} = pt_41:write(41009, [Result, PetId, ShortenTime, MoneyLeft, LeftTime, Level, Forza, Wit, Agile]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 宠物完成升级
%% -----------------------------------------------------------------
handle(41010, Status, [PetId]) ->
[Result, Level, Forza, Wit, Agile, DiffForzaUse, DiffWitUse, DiffAgileUse] = mod_pet:finish_upgrade(Status, [PetId]),
    if  % 升级成功且力智敏有变化
        ((Result == 1) and ((DiffForzaUse /= 0) or (DiffWitUse /= 0) or (DiffAgileUse /= 0))) ->
            % 发送回应
            {ok, BinData} = pt_41:write(41010, [Result, PetId, Level, Forza, Wit, Agile]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 角色属性减点
            Status1 = lib_pet:calc_player_attribute(add, Status, DiffForzaUse, DiffWitUse, DiffAgileUse),
            % 返回新状态
            {ok, Status1};
        true ->
            {ok, BinData} = pt_41:write(41010, [Result, PetId, Level, Forza, Wit, Agile]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 扩展升级队列
%% -----------------------------------------------------------------
handle(41011, Status, []) ->
    [Result, QueNum, MoneyLeft] = mod_pet:extent_upgrade_que(Status, []),
    if  % 扩展成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_41:write(41011, [Result, QueNum, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 更新金币和队列个数
            Status1 = Status#player_status{gold = MoneyLeft, pet_upgrade_que_num=QueNum},
            % 返回新状态
            {ok, Status1};
        true ->
            % 发送回应
            {ok, BinData} = pt_41:write(41011, [Result, QueNum, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 宠物喂养
%% -----------------------------------------------------------------
handle(41012, Status, [PetId, GoodsId, GoodsUseNum]) ->
    [Result, Strength, Forza, Wit, Agile, DiffForzaUse, DiffWitUse, DiffAgileUse] = mod_pet:feed_pet(Status, [PetId, GoodsId, GoodsUseNum]),
    if  % 升级成功且力智敏有变化
        ((Result == 1) and ((DiffForzaUse /= 0) or (DiffWitUse /= 0) or (DiffAgileUse /= 0))) ->
            % 发送回应
            {ok, BinData} = pt_41:write(41012, [Result, PetId, Strength, Forza, Wit, Agile]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 角色属性减点
            Status1 = lib_pet:calc_player_attribute(add, Status, DiffForzaUse, DiffWitUse, DiffAgileUse),
            % 返回新状态
            {ok, Status1};
        true ->
            {ok, BinData} = pt_41:write(41012, [Result, PetId, Strength, Forza, Wit, Agile]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 宠物驯养
%% -----------------------------------------------------------------
handle(41013, Status, [PetId, DomesticateType, GoodsId, GoodsUseNum]) ->
    [Result, AptitudeAttribute, Attribute, DiffForzaUse, DiffWitUse, DiffAgileUse] = mod_pet:domesticate_pet(Status, [PetId, DomesticateType, GoodsId, GoodsUseNum]),
    if  % 驯养成功且力智敏有变化
        ((Result == 1) and ((DiffForzaUse /= 0) or (DiffWitUse /= 0) or (DiffAgileUse /= 0))) ->
            % 发送回应
            {ok, BinData} = pt_41:write(41013, [Result, PetId, DomesticateType, AptitudeAttribute, Attribute]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 角色属性减点
            Status1 = lib_pet:calc_player_attribute(add, Status, DiffForzaUse, DiffWitUse, DiffAgileUse),
            % 返回新状态
            {ok, Status1};
        true ->
            {ok, BinData} = pt_41:write(41013, [Result, PetId, DomesticateType, AptitudeAttribute, Attribute]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 宠物进阶
%% -----------------------------------------------------------------
handle(41014, Status, [PetId, GoodsId, GoodsUseNum]) ->
[Result, EvolutionResult, Quality, AptitudeThreshold] = mod_pet:enhance_quality(Status, [PetId, GoodsId, GoodsUseNum]),
    {ok, BinData} = pt_41:write(41014, [Result, PetId, EvolutionResult, Quality, AptitudeThreshold]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 体力值同步
%% -----------------------------------------------------------------
handle(41015, Status, []) ->
[Result, RecordsNum, RecordsData, TotalForzaUse, TotalWitUse, TotalAgileUse] = mod_pet:strength_sync(Status, []),
    [PetForza, PetWit, PetAgile] = Status#player_status.pet_attribute,
    if  % 同步成功,有体力值变化并导致智敏改变
        ((Result == 1) and (RecordsNum > 0) and((PetForza /= TotalForzaUse) or (PetWit /= TotalWitUse) or (PetAgile /= TotalAgileUse))) ->
            % 发送回应
            {ok, BinData} = pt_41:write(41015, [Result, RecordsNum, RecordsData]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 角色属性变化
            Status1 = lib_pet:calc_player_attribute(replace, Status, TotalForzaUse, TotalWitUse, TotalAgileUse),
            % 返回新状态
            {ok, Status1};
        % 同步成功,有体力值变化但智敏无改变
        ((Result == 1) and (RecordsNum > 0)) ->
            {ok, BinData} = pt_41:write(41015, [Result, RecordsNum, RecordsData]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok;
        % 其他情况
        true ->
            ok
    end;

%% -----------------------------------------------------------------
%% 获取宠物信息
%% -----------------------------------------------------------------
handle(41016, Status, [PetId]) ->
    [Result, Data] = mod_pet:get_pet_info(Status, [PetId]),
    {ok, BinData} = pt_41:write(41016, [Result,Data]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 获取宠物列表
%% -----------------------------------------------------------------
handle(41017, Status, [PlayerId]) ->
    [Result, RecordNum, Data] = mod_pet:get_pet_list(Status, [PlayerId]),
    {ok, BinData} = pt_41:write(41017, [Result, RecordNum, Data]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 宠物出战替换
%% -----------------------------------------------------------------
handle(41018, Status, [PetId, ReplacedPetId]) ->
    [Result, IconPos, DiffForzaUse, DiffWitUse, DiffAgileUse] = mod_pet:fighting_replace(Status, [PetId, ReplacedPetId]),
    if  (Result == 1 and ((DiffForzaUse /= 0) or (DiffWitUse /= 0) or (DiffAgileUse /= 0))) ->
            % 发送回应
            {ok, BinData} = pt_41:write(41018, [Result, PetId, ReplacedPetId, IconPos]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 角色属性加点
            Status1 = lib_pet:calc_player_attribute(add, Status, DiffForzaUse, DiffWitUse, DiffAgileUse),
            % 返回新状态
            {ok, Status1};
        true ->
            {ok, BinData} = pt_41:write(41018, [Result, PetId, ReplacedPetId, IconPos]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 获取可用升级队列个数
%% -----------------------------------------------------------------
handle(41019, Status, []) ->
    {ok, BinData} = pt_41:write(41019, [1, Status#player_status.pet_upgrade_que_num]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 取消升级
%% -----------------------------------------------------------------
handle(41020, Status, [PetId]) ->
    Result = mod_pet:cancel_upgrade(Status, [PetId]),
    {ok, BinData} = pt_41:write(41020, [Result, PetId]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;


%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_pet no match", []),
    {error, "pp_pet no match"}.



