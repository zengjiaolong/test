%%%-----------------------------------
%%% @Module  : mod_login
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.29
%%% @Description: 用户登陆
%%%-----------------------------------
-module(mod_login).
-export([login/3, logout/1, fix_pid/1, stop_all/0]).
-include("common.hrl").
-include("record.hrl").

%%用户登陆
login(Player , check, Socket)  ->
    [Id | _] = Player,
    %% 检查死进程
    Pid1 = none, %%暂时默认
    Pid2 = fix_pid(Pid1),
    %% 检查用户登陆和状态
    Condition = check_player(Pid2,
                 [
                  fun is_player_online/1,
                  fun is_offline/1
                 ]),
    {Pid3, Result} = login(Pid2, Condition, Socket),
    Time = util:unixtime()+5,
    %%更新
    case db_sql:execute(io_lib:format(<<"update `player` set `last_login_time` = ~p, `online_flag`=1 where id=~p">>,[Time, Id])) of
        1 ->
                %%登陆启动
                login_success(Player, Pid3,  Socket, Time),
            Result;
        _ ->
            {error, fail}
    end;

%%登陆检查入口
%%Data:登陆验证数据
%%Arg:tcp的Socket进程,socket ID
login(start, [Id, Accname], Socket) ->
    case lib_account:get_info_by_id(Id) of
        [] ->
            {error, fail};
        Player ->
            [_, _, Aname | _] = Player,
            case binary_to_list(Aname) == Accname of
                true ->
                    login(Player, check, Socket);
                false ->
                    {error, fail}
            end    
    end;

%%重新登陆
login(Pid, player_online, Socket) ->
    %通知客户端账户在别处登陆
    {ok, BinData} = pt_10:write(10007, []),
    gen_server:cast(Pid, {'SEND',BinData}),
    logout(Pid),
    login(Pid, player_offline, Socket);

%% 开始一个游戏进程
login(_Pid, player_offline, _Socket) ->
    {ok, Pid} = mod_player:start(),
    {Pid, {ok, Pid}};

login(_Player, _S, _Arg) ->
    {error, fail}.

%%检查用户
%%Player：用户信息
%%Args：登陆参数
%%[Guard|Rest]:函数
check_player(Player, [Guard|Rest]) ->
    case Guard(Player) of
        {true, Condition} ->
            Condition;
        _ ->
            check_player(Player, Rest)
    end;

check_player(_Player, []) ->
    unknown_error.

%%当前已经在线
is_player_online(Pid) ->
    PlayerAlive = Pid /= none,
    { PlayerAlive, player_online}.

%%检查不在线
is_offline(Pid) ->
    PlayerDown = Pid == none,
    { PlayerDown, player_offline}.

%%检查进程是否存活
%%Pid：进程ID
fix_pid(Pid)
  when is_pid(Pid) ->
    case is_process_alive(Pid) of
    true ->
        Pid;
    _ ->
        none
    end;

fix_pid(Pid) ->
    Pid.

%% 把所有在线玩家踢出去
stop_all() ->
    L = ets:tab2list(?ETS_ONLINE),
    do_stop_all(L).

%% 让所有玩家自动退出
do_stop_all([]) ->
    ok;
do_stop_all([H | T]) ->
    logout(H#ets_online.pid),
    do_stop_all(T).


%%退出登陆
logout(Pid) when is_pid(Pid) ->
    mod_player:stop(Pid),
    ok;
logout(Status) ->

    %%离开场景
    lib_scene:leave_scene(Status),

    %% 下线时通知副本进程
    mod_dungeon:clear_rl(Status#player_status.pid_dungeon, Status#player_status.id),
    mod_dungeon:clear(role, Status#player_status.pid_dungeon),

    %% 如果在玩家副本，这里将获取副本的外场景id和坐标
    [Scene, X, Y] = case mod_dungeon:get_outside_scene(Status#player_status.scene) of
        false -> [Status#player_status.scene, Status#player_status.x, Status#player_status.y];   %% 不在副本
        Result -> Result
    end,

    %% 更新装备磨损状态
    case Status#player_status.equip_attrit > 0 of
        true -> (catch lib_goods:attrit_equip(Status, Status#player_status.equip_attrit));
        false -> void
    end,
    
    %% 删除在线玩家的ets物品表
    goods_util:goods_offline(Status#player_status.id),
    %%好友下线通知
    pp_relationship:handle(14030, [], [Status#player_status.id, 0, Status#player_status.nickname]),
    %%仇人下线通知
    pp_relationship:handle(14031, [], [Status#player_status.id, 0, Status#player_status.nickname]),
    %%清除该玩家在ets_rela,ets_rela_set的数据
    lib_relationship:delete_ets(Status#player_status.id),

    %%清理宠物模块
    lib_pet:role_logout(Status#player_status.id),

    %%清理帮派模块
    lib_guild:role_logout(Status#player_status.id),

    %% 保存记录
    Status1 = Status#player_status{scene=Scene, x = X, y=Y, online_flag=0},
    mod_player:save_player_table(Status1),

    %%删除ETS记录
    ets:delete(?ETS_ONLINE, Status1#player_status.id),

    %关闭socket连接
    gen_tcp:close(Status1#player_status.socket),

    ok.

%% 登陆成功，加载或更新数据
login_success(Player, Pid, Socket, LastLoginTime) ->
    [Id, Accid, Accname, Nickname, Scene, X, Y, Sex, Career, Lv, Hp, Hp_lim, Mp, Mp_lim, Att, Def, Hit, Dodge, Crit, Ten, Coin, Bcoin,
     Cell_num, Mount, Exp, Guild_id, Guild_name, Guild_position, Gold, Silver, Forza, Agile, Wit, Realm, Spirit, Att_area, Speed, AttSpeed, Equip, Quickbar, OnlineFlag, PetUpgradeQueNum] = Player,

    %% 打开广播信息进程
    Sid = lists:map(fun(_)-> spawn_link(fun()->send_msg(Socket) end) end,lists:duplicate(?SEND_MSG, 1)),
    %% 打开战斗进程
    {ok, Bid} = mod_battle:start_link(),

    %% 更新当前进程
    %% 创建物品模块PID
    {ok, GoodsPid} = mod_goods:start(Id,Cell_num,Equip),
    %% 创建坐骑模块PID
    {ok, MountPid} = mod_mount:start(Id),
    %% 取坐骑灵力消耗
    GoodsStatus = gen_server:call(GoodsPid, {'STATUS'}),
    [_, _, MountTypeId] = GoodsStatus#goods_status.equip_current,
    MountSpirit = lib_mount:get_spirit(MountTypeId),

    %% 宠物初始化
    [PetForza, PetWit, PetAgile] = lib_pet:role_login(Id),
    %% 帮派初始化
    lib_guild:role_login(Id, LastLoginTime),
    
    %% 一级属性转化为2级属性  临时的，到时候再结合装备一起算
    [Hp1, Mp1, Att1, Def1, Hit1, Dodge1, Crit1, Ten1] = lib_player:one_to_two(Forza+PetForza, Agile+PetAgile, Wit+PetWit, Career),
    %% 装备属性加成
    [Hp2, Mp2, Att2, Def2, Hit2, Dodge2, Crit2, Ten2] = goods_util:get_equip_attribute(Id, Equip, GoodsStatus#goods_status.equip_suit),

    %% 获取技能
    Skill = lib_skill:get_all_skill(Id),

    %% 设置mod_player 状态
    PlayerStatus = #player_status {
                id = Id,
                accid = Accid,
                accname = binary_to_list(Accname),
                nickname = binary_to_list(Nickname),
                scene = Scene,
                x = X,
                y = Y,
                sex = Sex,
                career = Career,
                realm = Realm,
                spirit = Spirit,
                lv = Lv,
                hp = Hp,
                hp_lim = Hp_lim + Hp1 + Hp2,
                mp = Mp,
                mp_lim = Mp_lim + Mp1 + Mp2,
                forza = round(Forza),
                agile = round(Agile),
                wit = round(Wit),
                att = Att + Att1 + Att2,
                def = Def + Def1 + Def2,
                hit = Hit + Hit1 + Hit2,
                dodge = Dodge + Dodge1 + Dodge2,
                crit = Crit + Crit1 + Crit2,
                ten = Ten + Ten1 + Ten2,
                base_attribute  = [Hp_lim, Mp_lim, Att, Def, Hit, Dodge, Crit, Ten],
                two_attribute   = [Hp1, Mp1, Att1, Def1, Hit1, Dodge1, Crit1, Ten1],
                equip_attribute = [Hp2, Mp2, Att2, Def2, Hit2, Dodge2, Crit2, Ten2],
                pet_attribute   = [PetForza, PetWit, PetAgile],
                pid = Pid,
                att_speed = AttSpeed,
                speed = Speed,
                gold = Gold,
                silver = Silver,
                coin = Coin,
                bcoin = Bcoin,
                cell_num = Cell_num,
                att_area = Att_area,
                mount = Mount,
                mount_spirit = MountSpirit,
                exp = Exp,
                goods_pid = GoodsPid,
                mount_pid = MountPid,
                socket = Socket,
                sid = Sid,
                bid = Bid,
                guild_id   = Guild_id,
                guild_name = binary_to_list(Guild_name),
                guild_position = Guild_position,
		equip = Equip,
                equip_current = GoodsStatus#goods_status.equip_current,
                quickbar = case util:bitstring_to_term(Quickbar) of undefined -> []; Qb -> Qb end,
                skill = Skill,
                online_flag = OnlineFlag,
                pet_upgrade_que_num = PetUpgradeQueNum
    },
    gen_server:cast(Pid, {'SET_PLAYER', PlayerStatus}),

    %%更新ETS_ONLINE在线表
    ets:insert(?ETS_ONLINE, #ets_online{
            id = PlayerStatus#player_status.id,
            nickname = PlayerStatus#player_status.nickname,
            pid = PlayerStatus#player_status.pid,
            sid = PlayerStatus#player_status.sid,
            scene = PlayerStatus#player_status.scene,
            x = PlayerStatus#player_status.x,
            y = PlayerStatus#player_status.y,
            hp = PlayerStatus#player_status.hp,
            hp_lim = PlayerStatus#player_status.hp_lim,
            mp = PlayerStatus#player_status.mp,
            mp_lim = PlayerStatus#player_status.mp_lim,
            att = PlayerStatus#player_status.att,
            def = PlayerStatus#player_status.def,
            hit = PlayerStatus#player_status.hit,
            dodge = PlayerStatus#player_status.dodge,
            crit = PlayerStatus#player_status.crit,
            ten = PlayerStatus#player_status.ten,
            lv = PlayerStatus#player_status.lv,
            career = PlayerStatus#player_status.career,
            guild_id = PlayerStatus#player_status.guild_id,
            guild_position = PlayerStatus#player_status.guild_position,
            speed = PlayerStatus#player_status.speed,
            equip_current = GoodsStatus#goods_status.equip_current,
            sex = PlayerStatus#player_status.sex,
            leader = 0
        }),

    %% 初始化任务
    lib_task:flush_role_task(PlayerStatus),
    %% todo: 默认触发第一个任务，目前先放到这里，以后会放到创建角色
    lib_task:trigger(10100, PlayerStatus),
    %%初始化ets_rela_set
    lib_relationship:set_ets_rela_set(Id),
    %%上线通知好友
    pp_relationship:handle(14030, [], [Id, 1, binary_to_list(Nickname)]),
    %%上线通知仇人
    pp_relationship:handle(14031, [], [Id, 1, binary_to_list(Nickname)]).
    %%发送自动回复设置
    %pp_relationship:handle(14011, [], Id).
    
    %?DEBUG("online:~p ==> process:~p~n",[ets:info(?ETS_ONLINE, size), erlang:system_info(process_count)]).

%%发消息
send_msg(Socket) ->
    receive
        {send, Bin} ->
            gen_tcp:send(Socket, Bin),
            send_msg(Socket);
            
        {move, Q, X1, Y1, X2, Y2, BinData, BinData1, BinData2} ->
            lib_scene:move_broadcast(Q, X1, Y1, X2, Y2, BinData, BinData1, BinData2, Socket),
            send_msg(Socket)
    end.
