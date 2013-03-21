%%%--------------------------------------
%%% @Module  : lib_account
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description:用户账户处理
%%%--------------------------------------
-module(lib_account).
-export(
    [
	 	check_account/2,
        get_info_by_id/1,
		get_role_list/2,
        get_role_list/3,
        create_role/8,
        delete_role/2,
		getin_createpage/0
    ]
).
-include("common.hrl").
-include("record.hrl").

%% 检查账号是否存在
check_account(PlayerId, Accid) ->
    case db_agent:get_accountid_by_id(PlayerId) of
        null ->
            false;
        AccountId ->
			case AccountId =:= Accid of
                true ->
                    true;
                false ->
                    false
            end
    end.


%% 通过帐号名称取得帐号信息
get_info_by_id(PlayerId) ->
	db_agent:get_info_by_id(PlayerId).
	

%% 取得指定帐号的角色列表
get_role_list(Accid, Accname) ->
	db_agent:get_role_list(Accid, Accname).


%% 取得指定帐号的角色列表
get_role_list(Sn, Accid, Accname) ->
	db_agent:get_role_list(Sn, Accid, Accname).


%% ！注意 创建角色已转交Php处理，一般情况下不再触发，勿修改代码。
%% 创建角色
create_role(AccId, AccName, Sn, Name, _Realm, Career, Sex, _Type) ->
	Career_id =
	 	case Career of
			1 -> 1;			%玄武--战士
         	2 -> 2;			%白虎--刺客
         	3 -> 3;			%青龙--弓手
        	4 -> 4;     	%朱雀--牧师
        	_ -> 5     		%麒麟--武尊
    	end,
	CareerInfo = lib_player:get_attribute_parameter(Career_id),	

%% 	SceneId = CareerInfo#ets_base_career.init_scene,
%% 	X = CareerInfo#ets_base_career.init_x,
%% 	Y = CareerInfo#ets_base_career.init_y,
	R = util:rand(1,100),
	SceneId =
	if
%%		R =< 33 -> 100;
%%		R > 33 andalso R =< 66 -> 110;
%%		R > 66 andalso R =< 100 -> 111;
		R =< 50 ->110;
		true -> 100
	end,
%% 玄武 25 13
%% 青龙  32 17
%% 朱雀 29 28 
%% 白虎  19 26
%% 麒麟 19 17
	{X,Y} =
	case Career_id of
		1 -> {25,13};
		2 -> {19,26};
		3 -> {32,17};
		4 -> {29,28};
		5 -> {19,17}
	end,
	AttArea = CareerInfo#ets_base_career.init_att_area,
	Speed = CareerInfo#ets_base_career.init_speed,
	Spirit = CareerInfo#ets_base_career.init_spirit,
	Gold = CareerInfo#ets_base_career.init_gold,
	Cash = CareerInfo#ets_base_career.init_cash,
	Coin = CareerInfo#ets_base_career.init_coin,
	Forza = CareerInfo#ets_base_career.forza,
	Physique = CareerInfo#ets_base_career.physique,
	Agile = CareerInfo#ets_base_career.agile,
	Wit = CareerInfo#ets_base_career.wit,
	AttSpeed = CareerInfo#ets_base_career.att_speed,
	
    % 部落 [新手、女娲族、神农族、伏羲族]
    Realm1 =  100,   %% 初始创建默认为 100 
    % 性别
    Sex1 =  
		if
        	Sex == 1 ->	1;	%男
        	true ->  2 		%女
    end,
    Time = util:unixtime(),
    CellNum = 36,
	StoreNum = 36,
	Lv = 1,
    [Hp, Mp | _] = lib_player:attribute_1_to_2(Forza, Physique, Agile, Wit, Career_id, Lv),
	
	%% 部落荣誉
	RealmHonor = 100,
    case db_agent:create_role(AccId, AccName, Sn, Career_id, Realm1, Sex1, Name,
							  Time, 0, X, Y, SceneId, Forza, Physique, Agile, Wit,
							  Coin, Cash, Gold, Hp, Mp, Spirit, AttArea, AttSpeed,
							  Speed, CellNum, StoreNum, RealmHonor) of
		{mongo, Id} ->
			%% 初始挂机设置
			spawn(fun()-> db_agent:init_hook_config(Id) end),
			lib_task:first_task(Id),
			{true, Id};
        1 ->
            Id = lib_player:get_role_id_by_name(Name),
			%% 赋第一个任务给玩家
			lib_task:first_task(Id),
            {true, Id};
        _Other ->
            false
    end.

%% 删除角色
delete_role(PlayerId, Accid) ->
	%清除宠物信息
    ok = lib_pet:delete_role(PlayerId),
	%清除氏族信息
    ok = mod_guild:delete_role(PlayerId), 
    ok = lib_goods:delete_role(PlayerId),
	%清除任务信息	
	ok = lib_task:delete_role_task(PlayerId),
	%清除经脉信息
	ok = lib_meridian:delete_role_meridian(PlayerId),
	%清除在线奖励信息
	ok = lib_online_gift:delete_online_gift_info(PlayerId),
	%%清除目标奖励信息
	ok = lib_target_gift:delete_target_gift_info(PlayerId),
	ok = lib_box:delete_box_player(PlayerId),
    Var1 = case db_agent:delete_role(PlayerId, Accid) of
        1 -> true;
        _ -> false
    end,
	Var2 = lib_relationship:delete_role(PlayerId),
    Var1 andalso Var2.

getin_createpage() ->
	Nowtime = util:unixtime(),
	db_agent:getin_createpage(Nowtime).

			
