%%%------------------------------------
%%% @Module  : mod_mon_active
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.12
%%% @Description: 怪物活动状态
%%%------------------------------------
-module(mod_mon_active).
-behaviour(gen_fsm).
-export([
        start/1, 
        sleep/2, 
        trace/2,
        revive/2,
        back/2
    ]).
-export([init/1, handle_event/3, handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).
-include("common.hrl").
-include("record.hrl").

-define(RETIME, 5000). %回血时间
-define(MOVE_TIME, 3000). %自动移动时间


%%开启一个怪物活动进程
%%每个怪物一个进程
start(M)->
    gen_fsm:start_link(?MODULE, M, []).


init([Id , MonId, Scene, X, Y, Type])->
    case data_mon:get(MonId) of
        [] ->
            {stop, normal, 0};
        M ->
            %% 打开战斗进程
            {ok, Bid} = mod_battle:start_link(),
            M1 = M#ets_mon{
                id = Id,
                scene = Scene,
                x = X,
                y = Y,
                d_x = X,
                d_y = Y,
                type = Type,
                aid = self(),
                bid = Bid
            },
            ets:insert(?ETS_MON, M1),
            {ok, sleep, [[], M1], 5000}
    end.

handle_event(_Event, StateName, Status) ->
    {next_state, StateName, Status}.

handle_sync_event(_Event, _From, StateName, Status) ->
    Reply = ok,
    {reply, Reply, StateName, Status}.

%%记录战斗结果
handle_info({'BATTLE', [Hp, Mp, X, Y], Att2}, StateName, [Att, Minfo]) ->
    case X > 0 andalso Y >0 of
        true ->
            Status1 = Minfo#ets_mon{
                        hp = Hp,
                        mp = Mp,
                        x = X,
                        y = Y
                    };
        false ->
            Status1 = Minfo#ets_mon{
                        hp = Hp,
                        mp = Mp
                    }
    end,
    ets:insert(?ETS_MON, Status1),
    % 加经验，暂时放这里
    if Status1#ets_mon.hp =< 0 ->
            PlayerStatus = gen_server:call(Att2, {'EXP', Status1#ets_mon.exp}),
            lib_task:event(kill, Status1#ets_mon.mid, PlayerStatus#player_status.id), %% 角色杀掉怪物
            mod_dungeon:kill_npc(PlayerStatus, [Status1#ets_mon.mid]),               %% 副本杀怪
            gen_server:call(PlayerStatus#player_status.goods_pid, {'mon_drop', PlayerStatus, Status1}); %% 掉落
        true ->
            ok
    end,
    if
        Status1#ets_mon.hp > 0 andalso StateName == trace andalso Att /= [] ->
            {next_state, trace, [Att, Status1]};
        true ->
            gen_fsm:send_event_after(1000, repeat),
            {next_state, trace, [Att2, Status1]}
    end;

%% 清除进程
handle_info(clear, _StateName, [Att, Minfo]) ->
    ets:delete(?ETS_MON, Minfo#ets_mon.id),
    {stop, normal, [Att, Minfo]};

%% 减HP
handle_info({last_red_hp, Hp, _Pid}, StateName, [Att, Minfo]) ->
     %% 先判断是否已经死亡
    case Minfo#ets_mon.hp > 0  of
        true ->
            case Minfo#ets_mon.hp < Hp of
                true ->
                    Minfo1 = Minfo#ets_mon{
                            hp = 0
                        },
                    ets:insert(?ETS_MON, Minfo1),
                    {next_state, revive, [[], Minfo1], Minfo1#ets_mon.retime};
                false ->
                    Minfo1 = Minfo#ets_mon{
                                    hp = Hp
                                },
                    ets:insert(?ETS_MON, Minfo1),
                    %%  广播给附近玩家
                    {ok, BinData} = pt_12:write(12081, [Minfo1#ets_mon.id, Minfo1#ets_mon.hp]),
                    lib_send:send_to_scene(Minfo1#ets_mon.scene, BinData),
                    {next_state, StateName, [Att, Minfo1]}
            end;
    false ->
        {next_state, StateName, [Att, Minfo]}
    end;

handle_info(_Info, StateName, Status) ->
    {next_state, StateName, Status}.

terminate(_Reason, _StateName, _Status) ->
%    gen_server:cast(Minfo#ets_mon.pid, {'RESET', Minfo#ets_mon.id}),
    ok.

code_change(_OldVsn, StateName, Status, _Extra) ->
    {ok, StateName, Status}.

%% =========处理怪物所有状态=========

%%静止状态并回血
sleep(timeout, [[], Minfo]) ->
    %%判断是否死亡
    case Minfo#ets_mon.hp > 0 of
        true ->
            case Minfo#ets_mon.type of
                1 -> %% 主动怪
                    case get_user_for_battle(Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y, 5) of
                        none ->
                            {next_state, sleep, [[], Minfo], 3000};
                        Pid ->
                            {next_state, trace, [Pid, Minfo], 100}
                    end;
                _ -> %% 被动怪
                    auto_revert(Minfo)
            end;
        false ->
            {next_state, revive, [[], Minfo], Minfo#ets_mon.retime}
    end;

sleep(_R, Status) ->
    sleep(timeout, Status).

%%跟踪目标
trace(timeout, [Pid, Minfo]) when is_pid(Pid) ->
    case catch gen:call(Pid, '$gen_call', 'PLAYER') of
        {'EXIT', _} ->
            {next_state, sleep, [[], Minfo], 1000};
        {ok, Player} ->
            X = Player#player_status.x,
            Y = Player#player_status.y,
            Hp = Player#player_status.hp,
            case Hp > 0 of
                true ->
                    case is_attack(Minfo, X, Y) of
                        attack -> % 可以进行攻击了
                            case mod_battle:battle(Minfo#ets_mon.bid, [Minfo, Player, 0]) of
                                none ->
                                    {next_state, trace, [Pid, Minfo]};
                                Aer ->
                                    gen_fsm:send_event_after(Minfo#ets_mon.att_speed*3, repeat),
                                    {next_state, trace, [Pid, Aer]}
                            end;
                        trace -> % 还不能进行攻击就追踪他
                            case trace_line(Minfo#ets_mon.x, Minfo#ets_mon.y, X, Y, Minfo#ets_mon.att_area) of
                                {X1, Y1} ->
                                    move(X1, Y1, [Pid, Minfo]);
                                true ->
                                    {next_state, back, [[], Minfo], 2000}
                            end;
                        back -> %停止追踪
                            {next_state, back, [[], Minfo], 1000};
                        die -> %死亡
                            {next_state, revive, [[], Minfo], Minfo#ets_mon.retime}
                    end;
                false ->
                    {next_state, back, [[], Minfo], 1000}
            end
    end;

trace(repeat, Status) ->
    trace(timeout, Status);

trace(_R, Status) ->
    trace(timeout, Status).

%%返回默认出生点
back(timeout, [[], Minfo]) ->
    Status1 = Minfo#ets_mon{
            x = Minfo#ets_mon.d_x,
            y = Minfo#ets_mon.d_y
        },
    lib_scene:mon_move(Status1#ets_mon.d_x, Status1#ets_mon.d_y, Status1#ets_mon.id, Status1#ets_mon.scene),
    ets:insert(?ETS_MON, Status1),
    {next_state, sleep, [[], Status1], 1000};
%    case trace_line(Minfo#ets_mon.x, Minfo#ets_mon.y, Minfo#ets_mon.d_x, Minfo#ets_mon.d_y) of
%        {X1, Y1} ->
%            Status1 = Minfo#ets_mon{
%                    x = X1,
%                    y = Y1
%                },
%            lib_scene:mon_move(X1, Y1, Status1#ets_mon.id, Status1#ets_mon.scene),
%            ets:insert(?ETS_MON, Status1),
%            {next_state, back, [[], Status1], 500};
%        true ->
%            {next_state, sleep, [[], Minfo], 1000}
%    end;

back(_R, Status) ->
    sleep(timeout, Status).

%%复活
revive(timeout, [[], Minfo]) ->
    if
        Minfo#ets_mon.retime == 0 -> %% 不重生关闭怪物进程
          handle_info(clear, null, [[], Minfo]);
        true ->
            Status1 = Minfo#ets_mon{
                    hp = Minfo#ets_mon.hp_lim,
                    mp = Minfo#ets_mon.mp_lim,
                    x = Minfo#ets_mon.d_x,
                    y = Minfo#ets_mon.d_y
                },

            %%通知客户端我已经重生了
            {ok, Bin_data} = pt_12:write(12007, Status1),
            lib_send:send_to_scene(Status1#ets_mon.scene, Bin_data),

            ets:insert(?ETS_MON, Status1),
            {next_state, sleep, [[], Status1], ?MOVE_TIME}
    end;

revive(_R, [[], Minfo]) ->
    {next_state, revive, [[], Minfo], Minfo#ets_mon.retime}.

%% 判断距离是否可以发动攻击了
is_attack(Status, X, Y) ->
    D_x = abs(Status#ets_mon.x - X),
    D_y = abs(Status#ets_mon.y - Y),
    Att_area = Status#ets_mon.att_area,
    case Status#ets_mon.hp > 0  of
        true ->
            case Att_area>= D_x of
                true ->
                    case Att_area>= D_y of
                        true ->
                            attack;
                        false ->
                            trace_area(Status, X, Y)
                    end;
                false ->
                    trace_area(Status, X, Y)
            end;
        false ->
            die
    end.

%% 追踪区域
trace_area(Status, X, Y) ->
    Trace_area = Status#ets_mon.trace_area,
    D_x = abs(Status#ets_mon.d_x - X),
    D_y = abs(Status#ets_mon.d_y - Y),
    %不在攻击范围内了停止追踪
    case  Trace_area >= D_x of
        true ->
             case Trace_area >= D_y of
                true ->
                    trace;
                false ->
                    back
             end;
        false ->
            back
    end.

%%先进入曼哈顿距离遇到障碍物再转向A*
%%每次移动2格
trace_line(X1, Y1, X2, Y2, AttArea) ->
    MoveArea = 2,
   %%先判断方向
   if 
       %目标在正下方
       X2 == X1 andalso Y2 - Y1 > 0 ->
            Y = Y2 - Y1,
            if 
                Y < MoveArea ->
                    {X1, Y2-AttArea};
                true ->
                    {X1, Y1+MoveArea}
            end;

      %目标在正上方
       X2 == X1 andalso Y2 - Y1 < 0 ->
            Y = abs(Y2 - Y1),
            if 
                Y < MoveArea ->
                    {X1, Y2+AttArea};
                true ->
                    {X1, Y1-MoveArea}
            end;

       %目标在正左方
       X2 - X1 < 0 andalso Y2 == Y1 ->
            X = abs(X2 - X1),
            if 
                X < MoveArea ->
                    {X2+AttArea, Y1};
                true ->
                    {X1-MoveArea, Y1}
            end; 

       %目标在正右方
       X2 - X1 > 0 andalso Y2 == Y1 ->
            X = X2 - X1,
            if 
                X < MoveArea ->
                    {X2-AttArea, Y1};
                true ->
                    {X1+MoveArea, Y1}
            end; 

       %目标在左上方
       X2 - X1 < 0 andalso Y2 - Y1 < 0 ->
            Y = abs(Y2 - Y1),
            X = abs(X2 - X1),
            if 
                Y < MoveArea ->
                    if 
                        X < MoveArea -> {X2+AttArea, Y2+AttArea};
                        true -> {X1-MoveArea, Y2+AttArea}
                    end;
                true ->
                    if
                        X < MoveArea -> {X2+AttArea, Y1-MoveArea};
                        true -> {X1-MoveArea, Y1-MoveArea}
                    end
            end;

       %目标在左下方
       X2 - X1 < 0 andalso Y2 - Y1 > 0 ->
            Y = Y2 - Y1,
            X = abs(X2 - X1),
            if 
                Y < MoveArea ->
                    if
                        X < MoveArea -> {X2+AttArea, Y2-AttArea};
                        true -> {X1-MoveArea, Y2-AttArea}
                    end;
                true ->
                    if
                        X < MoveArea -> {X2+AttArea, Y1+MoveArea};
                        true -> {X1-MoveArea, Y1+MoveArea}
                    end
            end;

       %目标在右上方
       X2 - X1 > 0 andalso Y2 - Y1 < 0 ->
            Y = abs(Y2 - Y1),
            X = X2 - X1,
            if 
                Y < MoveArea ->
                    if
                        X < MoveArea -> {X2-AttArea, Y2+AttArea};
                        true -> {X1+MoveArea, Y2+AttArea}
                    end;
                true ->
                    if
                        X < MoveArea -> {X2-AttArea, Y1-MoveArea};
                        true -> {X1+MoveArea, Y1-MoveArea}
                    end
            end;

       %目标在右下方
       X2 - X1 > 0 andalso Y2 - Y1 > 0 ->
            Y = Y2 - Y1,
            X = X2 - X1,
            if 
                Y < MoveArea ->
                    if
                        X < MoveArea -> {X2-AttArea, Y2-AttArea};
                        true -> {X1+MoveArea, Y2-AttArea}
                    end;
                true ->
                    if
                        X < MoveArea -> {X2-AttArea, Y1+MoveArea};
                        true -> {X1+MoveArea, Y1+MoveArea}
                    end
            end;

       true ->
            true
    end.

%%怪物移动 
move(X, Y, [Pid, Minfo]) ->
    %判断是否障碍物
    case lib_scene:is_blocked(Minfo#ets_mon.scene, [X, Y]) of
        true -> %无障碍物
            Status1 = Minfo#ets_mon{
                    x = X,
                    y = Y
                },
            lib_scene:mon_move(X, Y, Status1#ets_mon.id, Status1#ets_mon.scene),
            ets:insert(?ETS_MON, Status1),
            %继续追踪
            Time = round(40 * 2000 / Status1#ets_mon.speed) ,
            gen_fsm:send_event_after(Time, repeat),
            {next_state, trace, [Pid, Status1]};
        false -> %有障碍物
            {next_state, back, [[], Minfo], 1000}
    end.

%%随机移动
auto_move(Minfo) ->
    {_,_,R} = erlang:now(),
    Rand = R div 1000 rem 4,
    if
        Rand == 0 ->
            X = Minfo#ets_mon.x + 2,
            Y = Minfo#ets_mon.y;
        Rand == 1 ->
            X = Minfo#ets_mon.x,
            Y = Minfo#ets_mon.y+2;
        Rand == 2 ->
            X = abs(Minfo#ets_mon.x - 2),
            Y = Minfo#ets_mon.y;
        Rand == 3 ->
            X = Minfo#ets_mon.x,
            Y = abs(Minfo#ets_mon.y - 2)
    end,
    %判断是否障碍物
    case lib_scene:is_blocked(Minfo#ets_mon.scene, [X, Y]) of
        true ->
            Status1 = Minfo#ets_mon{
                    x = X,
                    y = Y
                },
            lib_scene:mon_move(X, Y, Status1#ets_mon.id, Status1#ets_mon.scene),
            ets:insert(?ETS_MON, Status1),
            {next_state, sleep, [[], Minfo], ?MOVE_TIME + ?MOVE_TIME * (Status1#ets_mon.id rem 20)};
        false -> %有障碍物
            {next_state, sleep, [[], Minfo], ?MOVE_TIME}
    end.

%% 自动回复血和蓝
auto_revert(Minfo) ->
    case Minfo#ets_mon.hp >= Minfo#ets_mon.hp_lim andalso Minfo#ets_mon.mp >= Minfo#ets_mon.mp_lim of
        true ->
            auto_move(Minfo);
        false ->
            %%判断是否超过气血上限
            CurHp = Minfo#ets_mon.hp + Minfo#ets_mon.hp_num,
            if
                CurHp < Minfo#ets_mon.hp_lim ->
                    Status1 =  Minfo#ets_mon{
                        hp = CurHp
                    };
                true ->
                    Status1 =  Minfo#ets_mon{
                        hp = Minfo#ets_mon.hp_lim
                    }
            end,

            %%判断是否超过内力上限
            CurMp = Status1#ets_mon.mp + Status1#ets_mon.mp_num,
            if
                CurMp >= Status1#ets_mon.mp_lim ->
                    Status2 =  Status1#ets_mon{
                        mp = CurMp
                    };
                true ->
                    Status2 =  Status1#ets_mon{
                        mp = Status1#ets_mon.mp_lim
                    }
            end,
            %%  广播给附近玩家
            {ok, BinData} = pt_12:write(12081, [Status2#ets_mon.id, Status2#ets_mon.hp]),
            lib_send:send_to_scene(Status2#ets_mon.scene, BinData),
            
            ets:insert(?ETS_MON, Status2),
            {next_state, sleep, [[], Status2], ?RETIME}
    end.

%%获取范围内的玩家
get_user_for_battle(Q, X, Y, Area) ->
    X1 = X + Area,
    X2 = X - Area,
    Y1 = Y + Area,
    Y2 = Y - Area,
    AllUser = ets:match(?ETS_ONLINE, #ets_online{pid = '$1', x='$2', y='$3', scene = Q, _='_'}),
    AllUser1 = [[Pid, X0, Y0] || [Pid, X0, Y0] <- AllUser, X0 >= X2 andalso X0 =< X1, Y0 >= Y2 andalso Y0 =< Y1],
    get_user_for_battlle_near(AllUser1, [X, Y], 1000000, none).

%% 获取一个最近的玩家
get_user_for_battlle_near([], _, _, N) ->
    N;
get_user_for_battlle_near([[Pid, X0, Y0]| T], [X, Y], L, N) ->
    L0 = abs(X0 - X) + abs(Y0 - Y),
    [L1, N1] = if
        L0 < L ->
            [L0, Pid];
        true ->
            [L, N]
    end,
    get_user_for_battlle_near(T, [X, Y], L1, N1).