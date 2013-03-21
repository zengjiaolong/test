%%%------------------------------------
%%% @Module  : mod_player
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.29
%%% @Description: 角色处理
%%%------------------------------------
-module(mod_player).
-behaviour(gen_server).
-export([start/0, stop/1, set_dungeon/2, save_player_table/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").

%%开始
start() ->
    gen_server:start(?MODULE, [], []).

init([]) ->
    process_flag(priority, max),
    {ok, none}.

%%停止本游戏进程
stop(Pid) 
  when is_pid(Pid) ->
    gen_server:cast(Pid, stop).

%% 设置副本
set_dungeon(Pid, Val) ->
    case is_pid(Pid) andalso is_process_alive(Pid) of
        false -> false;
        true -> gen_server:call(Pid, {set_dungeon, Val})
    end.

%%游戏进程死掉修改状态
terminate(_Reason, Status) ->
    %%玩家下线，如有队伍，则离开队伍
    pp_team:handle(24005, Status, offline),
    spawn(fun() -> mod_login:logout(Status) end),
    ok.

%%停止游戏进程
handle_cast(stop, Status) ->
    {stop, normal, Status};

%%发信息
%handle_cast({'SEND',Bin}, Status) ->
%    prim_inet:send(Status#player_status.socket, Bin),
%    {noreply, Status};

%% -----------------------------------------------------------------
%% 帮派申请解散
%% -----------------------------------------------------------------
handle_cast({'guild_apply_disband',[PlayerId, PlayerName, GuildId, GuildName]}, Status) ->
    ?DEBUG("handle_cast:msg_type=[~p], PlayerId=[~p], PlayerName=[~s], GuildId=[~p], GuildName=[~s]", ['guild_apply_disband',PlayerId, PlayerName, GuildId, GuildName]),
    % 发送通知
    {ok, Bin} = pt_40:write(40000, [0, GuildId, GuildName]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;

%% -----------------------------------------------------------------
%% 帮派新成员加入
%% -----------------------------------------------------------------
handle_cast({'guild_new_member',[PlayerId, PlayerName, GuildId, GuildName, GuildPosition]}, Status) ->
    ?DEBUG("handle_cast, msg_type=[~p], PlayerId=[~p], PlayerName=[~s], GuildId=[~p], GuildName=[~s], GuildPosition=[~p]", ['guild_new_member',PlayerId, PlayerName, GuildId, GuildName, GuildPosition]),
    case PlayerId == Status#player_status.id  of
        % 自己加入
        true  ->
            % 保存状态
            Status1 = Status#player_status{guild_id      = GuildId,
                                           guild_name     = lib_guild:make_sure_binary(GuildName),
                                           guild_position = GuildPosition},
            save_online(Status1),
            % 发送通知
            {ok, Bin} = pt_40:write(40000, [1, PlayerId, PlayerName, GuildId, GuildName]),
            case catch gen_tcp:send(Status#player_status.socket, Bin) of
                {'EXIT', _R1} ->
                    {stop, normal, Status1};
                _R2 ->
                    {noreply, Status1}
            end;
        % 其他人加入
        false ->
            % 发送通知
            {ok, Bin} = pt_40:write(40000, [1, PlayerId, PlayerName, GuildId, GuildName]),
            case catch gen_tcp:send(Status#player_status.socket, Bin) of
                {'EXIT', _R1} ->
                    {stop, normal, Status};
                _R2 ->
                    {noreply, Status}
            end
    end;

%% -----------------------------------------------------------------
%% 帮派邀请加入
%% -----------------------------------------------------------------
handle_cast({'guild_invite_join',[PlayerId, PlayerName, GuildId, GuildName]}, Status) ->
    ?DEBUG("handle_cast, msg_type=[~p], PlayerId=[~p], PlayerName=[~s], GuildId=[~p], GuildName=[~s]", ['guild_invite_join', PlayerId, PlayerName, GuildId, GuildName]),
    % 发送通知
    {ok, Bin} = pt_40:write(40000, [2, GuildId, GuildName]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;

%% -----------------------------------------------------------------
%% 帮派成员被踢出
%% -----------------------------------------------------------------
handle_cast({'guild_kickout',[PlayerId, PlayerName, GuildId, GuildName]}, Status) ->
    ?DEBUG("handle_cast, msg_type=[~p], PlayerId=[~p], PlayerName=[~s], GuildId=[~p], GuildName=[~s]", ['guild_kickout', PlayerId, PlayerName, GuildId, GuildName]),
    case PlayerId == Status#player_status.id  of
        % 自己被踢出
        true  ->
            % 保存状态
            Status1 = Status#player_status{guild_id       = 0,
                                            guild_name     = <<>>,
                                            guild_position = 0},
            save_online(Status1),
            % 发送通知
            {ok, Bin} = pt_40:write(40000, [3, PlayerId, PlayerName, GuildId, GuildName]),
            case catch gen_tcp:send(Status#player_status.socket, Bin) of
                {'EXIT', _R1} ->
                    {stop, normal, Status1};
                _R2 ->
                    {noreply, Status1}
            end;
        % 其他人被踢出
        false ->
            % 发送通知
            {ok, Bin} = pt_40:write(40000, [3, PlayerId, PlayerName, GuildId, GuildName]),
            case catch gen_tcp:send(Status#player_status.socket, Bin) of
                {'EXIT', _R1} ->
                    {stop, normal, Status};
                _R2 ->
                    {noreply, Status}
            end
    end;

%% -----------------------------------------------------------------
%% 帮派成员退出
%% -----------------------------------------------------------------
handle_cast({'guild_quit',[PlayerId, PlayerName, GuildId, GuildName]}, Status) ->
    ?DEBUG("handle_cast, msg_type=[~p], PlayerId=[~p], PlayerName=[~s], GuildId=[~p], GuildName=[~s]", ['guild_quit', PlayerId, PlayerName, GuildId, GuildName]),
    % 发送通知
    {ok, Bin} = pt_40:write(40000, [4, PlayerId, PlayerName, GuildId, GuildName]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;

%% -----------------------------------------------------------------
%% 帮派职位改变
%% -----------------------------------------------------------------
handle_cast({'guild_set_position',[PlayerId, PlayerName, OldPosition, NewPosition]}, Status) ->
    ?DEBUG("handle_cast, msg_type=[~p], PlayerId=[~p], PlayerName=[~s], OldPosition=[~p], NewPosition=[~p]", ['guild_set_position', PlayerId, PlayerName, OldPosition, NewPosition]),
    MsgType = case OldPosition < NewPosition of
                  % 降职
                  true  -> 6;
                  % 升职
                  false -> 5
    end,
    case PlayerId == Status#player_status.id  of
        % 自己被设置
        true  ->
            % 保存状态
            Status1 = Status#player_status{guild_position = NewPosition},
            save_online(Status1),
            % 发送通知
            {ok, Bin} = pt_40:write(40000, [MsgType, PlayerId, PlayerName, OldPosition, NewPosition]),
            case catch gen_tcp:send(Status#player_status.socket, Bin) of
                {'EXIT', _R1} ->
                    {stop, normal, Status1};
                _R2 ->
                    {noreply, Status1}
            end;
        % 其他人被设置
        false ->
            % 发送通知
            {ok, Bin} = pt_40:write(40000, [MsgType, PlayerId, PlayerName, OldPosition, NewPosition]),
            case catch gen_tcp:send(Status#player_status.socket, Bin) of
                {'EXIT', _R1} ->
                    {stop, normal, Status};
                _R2 ->
                    {noreply, Status}
            end
    end;

%% -----------------------------------------------------------------
%% 帮派帮主禅让
%% -----------------------------------------------------------------
handle_cast({'guild_demise_chief',[OldChiefId, OldChiefName, NewChiefId, NewChiefName]}, Status) ->
    ?DEBUG("handle_cast, msg_type=[~p], OldChiefId=[~p], OldChiefName=[~s], NewChiefId=[~p], NewChiefName=[~s]", ['guild_demise_chief', OldChiefId, OldChiefName, NewChiefId, NewChiefName]),
    case NewChiefId == Status#player_status.id  of
        % 自己是新帮主
        true  ->
            % 保存状态
            Status1 = Status#player_status{guild_position = 1},
            save_online(Status1),
            % 发送通知
            {ok, Bin} = pt_40:write(40000, [7, OldChiefId, OldChiefName, NewChiefId, NewChiefName]),
            case catch gen_tcp:send(Status#player_status.socket, Bin) of
                {'EXIT', _R1} ->
                    {stop, normal, Status1};
                _R2 ->
                    {noreply, Status1}
            end;
        % 其他人是新帮主
        false ->
            % 发送通知
            {ok, Bin} = pt_40:write(40000, [7, OldChiefId, OldChiefName, NewChiefId, NewChiefName]),
            case catch gen_tcp:send(Status#player_status.socket, Bin) of
                {'EXIT', _R1} ->
                    {stop, normal, Status};
                _R2 ->
                    {noreply, Status}
            end
    end;

%% -----------------------------------------------------------------
%% 帮派成员辞官
%% -----------------------------------------------------------------
handle_cast({'guild_resign_position',[PlayerId, PlayerName, OldPosition, NewPosition]}, Status) ->
    ?DEBUG("handle_cast, msg_type=[~p], PlayerId=[~p], PlayerName=[~s], OldPosition=[~p], NewPosition=[~p]", ['guild_resign_position', PlayerId, PlayerName, OldPosition, NewPosition]),
    % 发送通知
    {ok, Bin} = pt_40:write(40000, [8, PlayerId, PlayerName, OldPosition, NewPosition]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;

%% -----------------------------------------------------------------
%% 帮派正式解散
%% -----------------------------------------------------------------
handle_cast({'guild_disband',[GuildId, GuildName]}, Status) ->
    ?DEBUG("handle_cast:msg_type=[~p], GuildId=[~p], GuildName=[~s]", ['guild_disband',GuildId, GuildName]),
    Status1 = Status#player_status{guild_id       = 0,
                                   guild_name     = <<>>,
                                   guild_position = 0},
    save_online(Status1),
    {ok, Bin} = pt_40:write(40000, [9, GuildId, GuildName]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status1};
        _R2 ->
            {noreply, Status1}
    end;

%% -----------------------------------------------------------------
%% 帮派取消解散
%% -----------------------------------------------------------------
handle_cast({'guild_cancel_disband',[GuildId, GuildName]}, Status) ->
    ?DEBUG("handle_cast:msg_type=[~p], GuildId=[~p], GuildName=[~s]", ['guild_cancel_disband',GuildId, GuildName]),
    {ok, Bin} = pt_40:write(40000, [10, GuildId, GuildName]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;

%% -----------------------------------------------------------------
%% 帮派升级
%% -----------------------------------------------------------------
handle_cast({'guild_upgrade',[GuildId, GuildName, OldLevel, NewLevel]}, Status) ->
    ?DEBUG("handle_cast:msg_type=[~p], GuildId=[~p], GuildName=[~s], OldLevel=[~p], NewLevel=[~p]", ['guild_upgrade',GuildId, GuildName, OldLevel, NewLevel]),
    {ok, Bin} = pt_40:write(40000, [11, GuildId, GuildName, OldLevel, NewLevel]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;

%% -----------------------------------------------------------------
%% 帮派降级
%% -----------------------------------------------------------------
handle_cast({'guild_degrade',[GuildId, GuildName, OldLevel, NewLevel]}, Status) ->
    ?DEBUG("handle_cast:msg_type=[~p], GuildId=[~p], GuildName=[~s], OldLevel=[~p], NewLevel=[~p]", ['guild_degrade',GuildId, GuildName, OldLevel, NewLevel]),
    {ok, Bin} = pt_40:write(40000, [12, GuildId, GuildName, OldLevel, NewLevel]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;

%% -----------------------------------------------------------------
%% 帮派钱币捐献
%% -----------------------------------------------------------------
handle_cast({'guild_donate_money',[PlayerId, PlayerName, Num]}, Status) ->
    ?DEBUG("handle_cast:msg_type=[~p], PlayerId=[~p], PlayerName=[~s], Num=[~p]", ['guild_donate_money',PlayerId, PlayerName, Num]),
    {ok, Bin} = pt_40:write(40000, [13, PlayerId, PlayerName, Num]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;


%% -----------------------------------------------------------------
%% 帮派建设卡捐献
%% -----------------------------------------------------------------
handle_cast({'guild_donate_contribution_card',[PlayerId, PlayerName, Num]}, Status) ->
    ?DEBUG("handle_cast:msg_type=[~p], PlayerId=[~p], PlayerName=[~s], Num=[~p]", ['guild_donate_contribution_card',PlayerId, PlayerName, Num]),
    {ok, Bin} = pt_40:write(40000, [14, PlayerId, PlayerName, Num]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;

%% -----------------------------------------------------------------
%% 帮派申请加入
%% -----------------------------------------------------------------
handle_cast({'guild_apply_join',[PlayerId, PlayerName]}, Status) ->
    ?DEBUG("handle_cast, msg_type=[~p], PlayerId=[~p], PlayerName=[~s]", ['guild_apply_join', PlayerId, PlayerName]),
    % 发送通知
    {ok, Bin} = pt_40:write(40000, [15, PlayerId, PlayerName]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;

%% -----------------------------------------------------------------
%% 帮派拒绝邀请
%% -----------------------------------------------------------------
handle_cast({'guild_reject_invite',[PlayerId, PlayerName]}, Status) ->
    ?DEBUG("handle_cast, msg_type=[~p], PlayerId=[~p], PlayerName=[~s]", ['guild_reject_invite', PlayerId, PlayerName]),
    % 发送通知
    {ok, Bin} = pt_40:write(40000, [16, PlayerId, PlayerName]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;

%% -----------------------------------------------------------------
%% 帮派掉级解散
%% -----------------------------------------------------------------
handle_cast({'guild_auto_disband',[GuildId, GuildName]}, Status) ->
    ?DEBUG("handle_cast:msg_type=[~p], GuildId=[~p], GuildName=[~s]", ['guild_auto_disband',GuildId, GuildName]),
    {ok, Bin} = pt_40:write(40000, [17, GuildId, GuildName]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;

%% -----------------------------------------------------------------
%% 帮派拒绝申请
%% -----------------------------------------------------------------
handle_cast({'guild_reject_apply',[GuildId, GuildName]}, Status) ->
    ?DEBUG("handle_cast:msg_type=[~p], GuildId=[~p], GuildName=[~s]", ['guild_reject_apply',GuildId, GuildName]),
    {ok, Bin} = pt_40:write(40000, [18, GuildId, GuildName]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;

%% -----------------------------------------------------------------
%% 帮派头衔授予
%% -----------------------------------------------------------------
handle_cast({'guild_give_title',[PlayerId, PlayerName, Title]}, Status) ->
    ?DEBUG("handle_cast, msg_type=[~p], PlayerId=[~p], PlayerName=[~s], Titile=[~s]", ['guild_give_title', PlayerId, PlayerName, Title]),
    % 发送通知
    {ok, Bin} = pt_40:write(40000, [19, PlayerId, PlayerName, Title]),
    case catch gen_tcp:send(Status#player_status.socket, Bin) of
        {'EXIT', _R1} ->
            {stop, normal, Status};
        _R2 ->
            {noreply, Status}
    end;

%% -----------------------------------------------------------------
%% 宠物收取每日体力
%% -----------------------------------------------------------------
handle_cast({'pet_strength_daily',[]}, Status) ->
    ?DEBUG("handle_cast: msg_type=[~p], PlayerId=[~p]", ['pet_strength_daily', Status#player_status.id]),
    % 扣减所有宠物的体力值
    PetList = lib_pet:get_all_pet(Status#player_status.id),
    lists:map(fun lib_pet:collect_strength_daily/1, PetList),
    % 对出战宠物重新计算属性和
    FightingPet = lib_pet:get_fighting_pet(Status#player_status.id),
    [TotalForzaUse, TotalWitUse, TotalAgileUse] = lib_pet:calc_pet_attribute_sum(FightingPet),
    % 宠物属性加成到角色
    Status1 = lib_pet:calc_player_attribute(replace, Status, TotalForzaUse, TotalWitUse, TotalAgileUse),
    {noreply, Status1};

%%设置组队进程PID
handle_cast({'SET_TEAM_PID', TeamId}, Status) ->
    NewStatus = Status#player_status{pid_team = TeamId},
    save_online(NewStatus),
    {noreply, NewStatus};

%%设置是否为队长
%% Leader 0 => 非队长
%%        1 => 队长
handle_cast({'SET_TEAM_LEADER', Leader}, Status) ->
    NewStatus = Status#player_status{leader = Leader},
    save_online(NewStatus),
    {noreply, NewStatus};
    
%%设置用户信息
handle_cast({'SET_PLAYER', NewStatus}, _Status) ->
    {noreply, NewStatus};

% 指定角色执行一个操作(函数形式)
handle_cast({cast, {M, F, A}}, Status) ->
    case erlang:apply(M, F, [Status|A]) of
        {ok, Status1} ->
            save_online(Status1),
            {noreply, Status1};
        _ ->
            {noreply, Status}
    end;

handle_cast(_Event, Status) ->
    {noreply, Status}.

%%处理socket协议
%%cmd：命令号
%%data：协议体
handle_call({'SOCKET_EVENT', Cmd, Bin}, _From, Status) ->
    case routing(Cmd, Status, Bin) of
        {ok, Status1} ->
            save_online(Status1),
            {reply, ok, Status1};
        {ok, spirit, Status1} -> %% 更新灵力
            save_player_table(Status1),
            save_online(Status1),
            {reply, ok, Status1};
        {ok, create_team, Status1} -> %%创建了队伍
            save_player_table(Status1),
            save_online(Status1),
            {reply, ok, Status1};
        _R ->
            {reply, ok, Status}
    end;

%% 设置副本进程PID
handle_call({set_dungeon, Val}, _from, Status) ->
    NewStatus = Status#player_status{pid_dungeon = Val},
    save_online(NewStatus),
    {reply, ok, NewStatus};

%%获取用户信息
handle_call('PLAYER', _from, Status) ->
    {reply, Status, Status};

%%更新装备磨损信息
handle_call({'ATTRITION'}, _from, Status) ->
    NewEquip_attrit = Status#player_status.equip_attrit + 1,
    %% 每战斗十次，更新一次状态
    case NewEquip_attrit >= 10 of
        true ->
            %% 更新装备磨损状态
            case (catch gen_server:call(Status#player_status.goods_pid, {'attrit', Status, NewEquip_attrit})) of
                {ok, NewStatus} ->
                    save_online(NewStatus);
                _ ->
                   NewStatus = Status#player_status{
                                           equip_attrit = 0
                               }
            end;
        false ->
            NewStatus = Status#player_status{
                                   equip_attrit = NewEquip_attrit
                       }
    end,
    {reply, NewStatus, NewStatus};

%%增加经验
handle_call({'EXP', Exp}, _from, Status) ->
    Status1 = lib_player:add_exp(Status, Exp),
    {reply, Status1, Status1};

handle_call(_Event, _From, Status) ->
    {reply, ok, Status}.

%%子进程有退出
%handle_info({'EXIT', _Pid, _Reason}, Status) ->
%    {noreply, Status};

%%更新战斗信息
handle_info({'BATTLE', [Hp, Mp, X, Y], Pid}, Status) ->
    %% 先判断是否已经死亡
    case Status#player_status.hp > 0 of
        true ->
            case X > 0 andalso Y >0 of
                true ->
                    NewStatus = Status#player_status{
                            hp = Hp,
                            mp = Mp,
                            x = X,
                            y = Y
                        };
                false ->
                    NewStatus = Status#player_status{
                            hp = Hp,
                            mp = Mp
                        }
            end,

            %% 死亡处理
            if
                NewStatus#player_status.hp == 0 ->
                    lib_player:player_die(NewStatus, Pid);
                true ->
                    ok
            end,

            save_online(NewStatus),
            {noreply, NewStatus};
    false ->
        {noreply, Status}
    end;

%% 减HP
handle_info({last_red_hp, Hp, Pid}, Status) ->
     %% 先判断是否已经死亡
    case Status#player_status.hp > 0  of
        true ->
            case Status#player_status.hp < Hp of
                true ->
                    NewStatus = Status#player_status{
                            hp = 0
                        };
                false ->
                    NewStatus = Status#player_status{
                                    hp = Hp
                                }
            end,

            %% 死亡处理
            if
                NewStatus#player_status.hp == 0 ->
                    lib_player:player_die(NewStatus, Pid);
                true ->
                    ok
            end,
            %%  广播给附近玩家
            {ok, BinData1} = pt_12:write(12009, [NewStatus#player_status.id, NewStatus#player_status.hp, NewStatus#player_status.hp_lim]),
            lib_send:send_to_area_scene(NewStatus#player_status.scene, NewStatus#player_status.x, NewStatus#player_status.y, BinData1),
            save_online(NewStatus),
            {noreply, NewStatus};
    false ->
        {noreply, Status}
    end;

%% 设置战斗状态
handle_info({'BATTLE_STATUS', BattleStatus}, Status) ->
    NewStatus = Status#player_status{battle_status = BattleStatus},
    save_online(NewStatus),
    {noreply, NewStatus};

%% 设置HP
handle_info({'HP', HP}, Status) ->
    NewStatus = Status#player_status{hp = HP},
    save_online(NewStatus),
    {noreply, NewStatus};

handle_info(_Info, Status) ->
    {noreply, Status}.

code_change(_oldvsn, Status, _extra) ->
    {ok, Status}.

%%
%% ------------------------私有函数------------------------
%%

%% 路由
%%cmd:命令号
%%Socket:socket id
%%data:消息体
routing(Cmd, Status, Bin) ->
    %%取前面二位区分功能类型
    [H1, H2, _, _, _] = integer_to_list(Cmd),
    case [H1, H2] of
        %%游戏基础功能处理
        "10" -> pp_base:handle(Cmd, Status, Bin);
        "11" -> pp_chat:handle(Cmd, Status, Bin);
        "12" -> pp_scene:handle(Cmd, Status, Bin);
        "13" -> pp_player:handle(Cmd, Status, Bin);
        "14" -> pp_relationship:handle(Cmd, Status, Bin);
        "15" -> pp_goods:handle(Cmd, Status, Bin);
        "16" -> pp_mount:handle(Cmd, Status, Bin);
        "19" -> pp_mail:handle(Cmd, Status, Bin);
        "20" -> pp_battle:handle(Cmd, Status, Bin);
        "21" -> pp_skill:handle(Cmd, Status, Bin);
        "22" -> pp_rank:handle(Cmd, Status, Bin);
        "24" -> pp_team:handle(Cmd, Status, Bin);
        "25" -> pp_meridian:handle(Cmd, Status, Bin);
        "30" -> pp_task:handle(Cmd, Status, Bin);
        "32" -> pp_npc:handle(Cmd, Status, Bin);
        "40" -> pp_guild:handle(Cmd, Status, Bin);
        "41" -> pp_pet:handle(Cmd, Status, Bin);
        "60" -> pp_gateway:handle(Cmd, Status, Bin);
        %%错误处理
        _ ->
            ?ERR("[~w]路由失败.", [Cmd]),
            {error, "Routing failure"}
    end.

%% 同步更新ETS中的角色数据
save_online(Status) ->
    ets:insert(?ETS_ONLINE, #ets_online{
                id = Status#player_status.id,
                nickname = Status#player_status.nickname,
                pid = Status#player_status.pid,
                scene = Status#player_status.scene,
                x = Status#player_status.x,
                y = Status#player_status.y,
                hp = Status#player_status.hp,
                hp_lim = Status#player_status.hp_lim,
                mp = Status#player_status.mp,
                mp_lim = Status#player_status.mp_lim,
                att = Status#player_status.att,
                def = Status#player_status.def,
                hit = Status#player_status.hit,
                dodge = Status#player_status.dodge,
                crit = Status#player_status.crit,
                ten = Status#player_status.ten,
                lv = Status#player_status.lv,
                sid = Status#player_status.sid,
                guild_id = Status#player_status.guild_id,
                guild_position = Status#player_status.guild_position,
                pid_dungeon = Status#player_status.pid_dungeon,
                speed = Status#player_status.speed,
		pid_team = Status#player_status.pid_team,
		equip_current = Status#player_status.equip_current,
                equip = Status#player_status.equip,
                sex = Status#player_status.sex,
                leader = Status#player_status.leader,
                battle_status = Status#player_status.battle_status
            }).

%%保存基本信息
%%这里主要统一更新一些相对次要的数据。譬如经验exp不会实时写入数据库，它会等下次和灵力值一起写入
%%当玩家退出的时候也会执行一次这边的信息
save_player_table(Status)->
    db_sql:execute(io_lib:format(<<"update `player` set `scene`=~p, `x`=~p, `y`=~p, `hp`=~p, `mp`=~p, `exp`=~p, `spirit` = ~p, quickbar='~s', online_flag=~p where `id` = ~p">>,
    [
        Status#player_status.scene,
        Status#player_status.x,
        Status#player_status.y,
        Status#player_status.hp,
        Status#player_status.mp,
        Status#player_status.exp,
        Status#player_status.spirit,
        case util:term_to_bitstring(Status#player_status.quickbar) of <<"undefined">> -> <<>>; A -> A end,
        Status#player_status.online_flag,
        Status#player_status.id
    ])).
