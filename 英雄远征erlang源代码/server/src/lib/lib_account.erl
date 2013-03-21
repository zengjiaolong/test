%%%--------------------------------------
%%% @Module  : lib_account
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.10
%%% @Description:用户账户处理
%%%--------------------------------------
-module(lib_account).
-export(
    [
        get_info_by_id/1,
        get_role_list/1,
        create_role/6,
        delete_role/2
    ]
).
-include("common.hrl").
-include("record.hrl").

%% 通过帐号名称取得帐号信息
get_info_by_id(Pid) ->
    db_sql:get_row(io_lib:format(<<"select id, accid, accname, nickname, scene, x, y, sex, career, lv, hp, hp_lim, mp, mp_lim, att, def, hit, dodge, crit, ten, coin, bcoin, cell_num, mount, exp, guild_id, guild_name, guild_position, gold, silver, forza, agile, wit, realm, spirit, att_area, speed, att_speed, equip, quickbar, online_flag, pet_upgrade_que_num from `player` where id=~p limit 1">>, [Pid])).

%% 取得指定帐号的角色列表
get_role_list(Name) ->
    Sql = lists:concat(["select id, status, nickname, sex, lv, career from player where accname='",Name,"'"]),
    db_sql:get_all(Sql).

%% 创建角色
create_role(AccId, AccName, Name, Realm, Career, Sex) ->
    % 职业
    [Career1, SceneId, X, Y, AttArea, AttSpeed, _Wq, _Yf, _GuildJsk, _PetEgg] =   if
        Career == 1 -> %昆仑（战士）
            [1, 100, 17, 27, 1, 1000, 101100, 102101, 411001, 300101];
        Career == 2 -> %逍遥（法师）
            [2, 100, 17, 27, 4, 1000, 101300, 102103, 411001, 300101];
        true ->         %唐门（刺客）
            [3, 100, 17, 27, 1, 1000, 101200, 102102, 411001, 300101]
    end,


    % 阵营
    Realm1 =   if
        Realm == 1 ->   %天下盟
            1;
        Realm == 2 ->   %无双盟
            2;
        true ->          %傲世盟
            3
    end,
    % 性别
    Sex1 =   if
        Sex == 1 ->%男
            1;
        true ->    %女
            2
    end,
                
    Time = util:unixtime(),

    %% 默认参数
    CellNum = 49,
    Speed = 150,
    Forza = 5,
    Agile = 5,
    Wit = 3,
    Coin = 1000000,
    Silver = 100000,
    Gold = 100000,
    Spirit = 1000,
    [Hp, Mp | _] = lib_player:one_to_two(Forza, Agile, Wit, Career1),

    Sql = db_sql:make_insert_sql(player, ["accid", "accname", "career", "realm", "sex", "nickname", "reg_time", "last_login_time", "x", "y", "scene", "forza", "agile", "wit", "coin", "silver", "gold", "hp", "mp", "spirit","att_area", "att_speed", "speed", "cell_num"],
        [AccId, AccName, Career1, Realm1, Sex1, Name, Time, Time, X, Y, SceneId, Forza, Agile, Wit, Coin, Silver, Gold, Hp, Mp, Spirit, AttArea, AttSpeed, Speed, CellNum]),
    case db_sql:execute(Sql) of
        1 ->
            Id = lib_player:get_role_id_by_name(Name),
            %% 送一件武器
            %GoodsTypeInfo1 = goods_util:get_ets_info(?ETS_GOODS_TYPE, _Wq),
            %NewInfo1 = goods_util:get_new_goods(GoodsTypeInfo1),
            %GoodsInfo1 = NewInfo1#goods{ player_id=Id, location=1, cell=1, num=1 },
            %(catch lib_goods:add_goods(GoodsInfo1)),
            %% 送一件衣服
            %GoodsTypeInfo2 = goods_util:get_ets_info(?ETS_GOODS_TYPE, _Yf),
            %NewInfo2 = goods_util:get_new_goods(GoodsTypeInfo2),
            %GoodsInfo2 = NewInfo2#goods{ player_id=Id, location=1, cell=3, num=1 },
            %(catch lib_goods:add_goods(GoodsInfo2)),
            %% 送50张帮派建设卡
            GoodsTypeInfo3 = goods_util:get_ets_info(?ETS_GOODS_TYPE, _GuildJsk),
            NewInfo3 = goods_util:get_new_goods(GoodsTypeInfo3),
            GoodsInfo3 = NewInfo3#goods{ player_id=Id, location=4, cell=1, num=50 },
            (catch lib_goods:add_goods(GoodsInfo3)),
            %% 送5个宠物
            GoodsTypeInfo4 = goods_util:get_ets_info(?ETS_GOODS_TYPE, _PetEgg),
            NewInfo4 = goods_util:get_new_goods(GoodsTypeInfo4),
            GoodsInfo4 = NewInfo4#goods{ player_id=Id, location=4, cell=2, num=5 },
            (catch lib_goods:add_goods(GoodsInfo4)),
            true;
        _Other ->
            false
    end.

%% 删除角色
delete_role(Pid, Accname) ->
    ok = lib_pet:delete_role(Pid),
    ok = lib_guild:delete_role(Pid),
    ok = lib_goods:delete_role(Pid),
    Sql = lists:concat(["delete from player where id=",integer_to_list(Pid)," and accname='",Accname,"'"]),
    Var1 = case db_sql:execute(Sql) of
        1 -> true;
        _ -> false
    end,
    Var1 andalso lib_relationship:delete_role(Pid).
