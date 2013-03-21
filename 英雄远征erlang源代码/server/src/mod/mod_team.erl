%%%------------------------------------
%%% @Module  : mod_team
%%% @Author  : zzm
%%% @Email   : ming_up@163.com
%%% @Created : 2010.07.06
%%% @Description: 组队模块
%%%------------------------------------
-module(mod_team).
-behaviour(gen_server).
-export([start/4            %% 开启组队服务
        ,send_to_member/2   %% 广播给队员
        ,get_dungeon/1      %% 返回副本id
        ,create_dungeon/3   %% 创建副本
    ]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").
-define(TEAM_MEMBER_MAX, 5).

%% 开启组队进程
start(Uid, Pid, Nick, TeamName) ->
    gen_server:start_link(?MODULE, [Uid, Pid, Nick, TeamName], []).

%% 广播给队员
send_to_member(TeamPid, Bin) ->
    case is_pid(TeamPid) andalso is_process_alive(TeamPid) andalso is_binary(Bin) of
        false -> false;
        true -> gen_server:cast(TeamPid, {'SEND_TO_MEMBER', Bin})
    end.

%% 返回副本进程id
get_dungeon(TeamPid) ->
    case is_pid(TeamPid) andalso is_process_alive(TeamPid) of
        false -> false;
        true -> gen_server:call(TeamPid, get_dungeon)
    end.

%% 创建副本服务
create_dungeon(TeamPid, From, RoleInfo) ->
    gen_server:call(TeamPid, {create_dungeon, From, RoleInfo}).

init([Uid, Pid, Nick, TeamName]) ->
    {ok, #team{leaderid = Uid, leaderpid = Pid, teamname = TeamName, member = [#mb{id = Uid, pid = Pid, nickname = Nick}]}}.

%%申请加入队伍请求
handle_call('JOIN_TEAM_REQ', _From, State) ->
    Result = case length(State#team.member) of
                ?TEAM_MEMBER_MAX -> {ok, mb_max, State#team.leaderid};
                _Any ->
                    case is_pid(State#team.dungeon_pid) of
                        false ->
                            %%向队长发送进队申请
                            {ok, 1, State#team.leaderid};
                        true ->
                            {ok, in_dungeon, 0}
                    end
            end,
            {reply, Result, State};

%%队长回应加入队伍申请
handle_call({'JOIN_TEAM_RES', Res, Uid}, {From, _}, State) ->
    case From =:= State#team.leaderpid of
        false ->
           %%不是队长，无权操作    
            {reply, not_leader, State};
        true ->%%检查是否在副本中
            case is_pid(State#team.dungeon_pid) of
              false ->
                  case Res of
                     0 -> %%拒绝申请
                           {reply, 0, State};
                     1 -> %%检查申请进队的人是否还在线
                            case is_online(Uid) of
                                [] -> {reply, offline, State};
                                R -> %%队伍是否满人
                                    case length(State#team.member) of
                                        ?TEAM_MEMBER_MAX -> {reply, mb_max, State};
                                        _Any ->
                                             if %%申请人是否加入其他队伍了
                                             is_pid(R#ets_online.pid_team) =:= false ->
                                                    %%更新新队员mod_player中Status的pid_team，同步ets_online的pid_team        
                                                    gen_server:cast(R#ets_online.pid, {'SET_TEAM_PID', self()}),
                                                    NewMemberList = State#team.member ++ [#mb{id = Uid, pid = R#ets_online.pid, nickname = R#ets_online.nickname}],
                                                    NewState = State#team{member = NewMemberList},
                                                    gen_server:cast(self(), {'UPDATE_TEAM_INFO', NewState}),

                                                    {ok, BinData} = pt_11:write(11004, lists:concat([R#ets_online.nickname, "加入了队伍"])),
                                                    send_team(State, BinData),
                                                    {reply, 1, NewState};
                                                true -> 
                                                    {reply, 2, State}
                                            end
                                    end                     
                            end
                    end;
            true -> {reply, 5, State}
        end
    end;

%%退出队伍
handle_call({'QUIT_TEAM', Type}, {From, _}, State) ->
    case lists:keyfind(From, 3, State#team.member) of
        false -> 
            {reply, 0, State};
        Mb -> %%检查是否能退出队伍
           CanQuit =  case Type of
                        offline -> true;
                        [] -> 
                            case is_pid(State#team.dungeon_pid) of
                                 true -> false;
                                 false -> true
                            end
                end,
                case CanQuit of
                    true ->
                        case length(State#team.member) of
                             0 -> {reply, 0, State};
                             1 -> %%解散队伍
                                 gen_server:cast(From, {'SET_TEAM_PID', 0}),
                                 gen_server:cast(From, {'SET_TEAM_LEADER', 0}),
                                 lib_team:send_leaderid_area_scene(State#team.leaderid, 0), %%告诉场景
                                 gen_server:cast(self(), 'DISBAND'),
                                {reply, 1, State};
                             _Any -> %检查是否是队长退队
                                case From =:= State#team.leaderpid of
                                    true ->
                                        %%通知队员队伍队长退出了
                                        NewMb = lists:keydelete(From, 3, State#team.member),
                                        [H|_T] = NewMb,
                                        NewState = State#team{leaderid = H#mb.id, leaderpid = H#mb.pid, teamname = H#mb.nickname ++ "的队伍", member = NewMb},
                                        {ok, BinData} = pt_24:write(24011, State#team.leaderid),
                                        gen_server:cast(From, {'SET_TEAM_PID', 0}),
                                        gen_server:cast(From, {'SET_TEAM_LEADER', 0}),
                                        gen_server:cast(H#mb.pid, {'SET_TEAM_LEADER', 1}),
                                        lib_team:send_leaderid_area_scene(State#team.leaderid, 0), 
                                        lib_team:send_leaderid_area_scene(H#mb.id, 1), %%告诉场景
                                        send_team(NewState, BinData),
                                        send_team_info(NewState),
                                        {reply, 1, NewState};
                                    false ->
                                        %非队长退出
                                        NewMb = lists:keydelete(From, 3, State#team.member),
                                        NewState = State#team{member = NewMb},
                                        gen_server:cast(From, {'SET_TEAM_PID', 0}),
                                        {ok, BinData} = pt_24:write(24011, Mb#mb.id),
                                        send_team(NewState, BinData),
                                        {reply, 1, NewState}
                                end
                        end;
                    false -> {reply, 2, State}
                end
    end;

%%踢出队伍
handle_call({'KICK_OUT', Uid}, {From, _}, State) ->
    case From =:= State#team.leaderpid of
        false -> %%你不是队长
            {reply, 2, State};
        true -> 
            case is_pid(State#team.dungeon_pid) of
                false ->
                    case lists:keyfind(Uid, 2, State#team.member) of
                        false -> {reply, 0, State};
                        Mb -> 
                            NewMb = lists:keydelete(Uid, 2, State#team.member),
                            NewState = State#team{member = NewMb},
                            gen_server:cast(Mb#mb.pid, {'SET_TEAM_PID', 0}),
                            {ok, BinData} = pt_24:write(24011, Mb#mb.id),
                            send_team(State, BinData),
                            case is_online(Uid) of
                                [] -> ok;
                                R -> 
                                    {ok, BinData1} = pt_11:write(11004, lists:concat([R#ets_online.nickname, "被队长请出队伍"])),
                                    send_team(NewState, BinData1)
                            end,
                            {reply, 1, NewState}
                    end;
            true -> {reply, 4, State}
        end
    end;

%%邀请加入组队
handle_call({'INVITE_REQ', Uid}, {From, _}, State) ->
     case From =:= State#team.leaderpid of
        false -> %% 你不是队长
            {reply, not_leader, State};
        true ->  %%是否在副本中
            case is_pid(State#team.dungeon_pid) of
                false ->%% 检查队伍人数
                    case length(State#team.member) >= ?TEAM_MEMBER_MAX of
                        true ->
                            {reply, max_mb, State};
                         false ->%% 检查被邀请人是否在线
                            case is_online(Uid) of
                                 [] ->
                                    {reply, player_offline, State};
                                 R ->%% 检查被邀请人是否加入了其他队伍
                                     case is_pid(R#ets_online.pid_team) of
                                        true ->
                                                 {reply, in_other_team, State};
                                        false -> %% 被邀请人是否已经在我们的队伍中
                                            case lists:keyfind(Uid, 2, State#team.member) of
                                                false ->
                                                        {reply, {ok, State#team.teamname}, State};
                                                 _ ->
                                                         {reply, in_team, State}
                                             end
                                     end
                             end
                     end;
                 true -> {reply, in_dungeon, State}
            end
    end;

%%被邀请人回应加入队伍请求
handle_call({'INVITE_RES', Uid, Pid, Nick}, _From, State) ->
    case is_pid(State#team.dungeon_pid) of
        false -> 
            case lists:keyfind(Uid, 2, State#team.member) of
                false ->
                     case length(State#team.member) < ?TEAM_MEMBER_MAX of
                         true -> 
                             MB = State#team.member ++ [#mb{id = Uid, pid = Pid, nickname = Nick}],
                             NewState = State#team{member = MB},
                             %%更改新队员的pid_team
                             %io:format("NewState: ~p~n", [NewState]),
                             gen_server:cast(Pid, {'SET_TEAM_PID', self()}),
                             %%对其他队员进行队伍信息广播
                             gen_server:cast(self(), {'UPDATE_TEAM_INFO', NewState}), 
                             {ok, BinData} = pt_11:write(11004, lists:concat([Nick, "加入了队伍"])),
                             send_team(State, BinData),
                             {reply, 1, NewState};
                        false ->
                            {reply, mb_max, State}
                    end;
                _ -> {reply, in_team, State}
            end;
        true -> {reply, in_dungeon, State}
    end;

%%获取队伍信息
handle_call('GET_TEAM_INFO', _From, State) ->
    {reply, State, State};

%% 委任队长
%handle_call({'CHANGE_LEADER', Uid}, {From, _}, State) ->
%    case From =:= State#team.leaderpid of
%        false -> %%非队长无法委任队长
%            {reply, not_leader, State};
%        true ->
%            case lists:keyfind(Uid, 2, State#team.member) of
%                false -> 
%                    {reply, not_team_member, State};
%               Mb -> 
%               NewState = State#team{leaderid = Mb#mb.id, leaderpid = Mb#mb.pid, teamname = Mb#mb.nickname ++ "的队伍"},
%                   %%通知所有队员队长更改了
%                   {ok, BinData} = pt_24:write(24012, Mb#mb.id),
%                   send_team(NewState, BinData),
%                   {reply, 1, NewState}
%           end
%   end;

%%更改队名
%handle_call({'CHANGE_TEAMNAME', TeamName}, {From, _}, State) ->
%    case From =:= State#team.leaderpid of
%        false -> %%不是队长，没有权限修改队名
%            {reply, not_leader, State};
%        true -> 
%            NewState = State#team{teamname = TeamName},
%            %%通知队员队名改变了
%            {ok, BinData} = pt_24:write(24015, TeamName),
%            [lib_send:send_to_uid(X#mb.id, BinData) || X <- NewState#team.member],
%            {reply, 1, NewState}
%    end;

%% 获取副本id
handle_call(get_dungeon, _From, State) ->
    {reply, State#team.dungeon_pid, State};

%% 创建队伍的副本服务
handle_call({create_dungeon, From, RoleInfo}, _From, State) ->
    case is_pid(State#team.dungeon_pid) andalso is_process_alive(State#team.dungeon_pid) of
        true -> %%  非队长的队员加入副本
            [_Sceneid, Id, _Pid] = RoleInfo,
            mod_dungeon:join(State#team.dungeon_pid, Id),
            {reply, State#team.dungeon_pid, State}; 
        false ->
            [Sceneid, Id, Pid] = RoleInfo,
            case Id =:= State#team.leaderid of %% 判断是否队长
                true ->
                    DPid = mod_dungeon:start(self(), From, [{Id, Pid}]),
                    %% 通知其它队员加入副本
                    F = fun(Id0) ->
                            case lib_player:get_online_info(Id0) of
                                []->
                                    ok;
                                S ->
                                    {ok, BinData} = pt_24:write(24030, Sceneid),
                                    lib_send:send_to_sid(S#ets_online.sid, BinData)
                            end
                        end,
                    [F(Mb#mb.id) || Mb <- State#team.member],
                    {reply, DPid, State#team{dungeon_pid = DPid}};
                false ->
                    {reply, none, State}
            end
    end;

handle_call(_R, _From, State) ->
    {reply, _R, State}.

%%解散队伍
handle_cast('DISBAND', State) ->
    {ok, BinData} = pt_24:write(24017, []),
    F = fun(Member) ->
            gen_server:cast(Member#mb.pid, {'SET_TEAM_PID', 0}),
            lib_send:send_to_uid(Member#mb.id, BinData)
        end,
    [F(M)||M <- State#team.member],
    {stop, normal, State};

%%队伍聊天
handle_cast({'TEAM_MSG', Id, Nickname, Color, Data}, State) ->
    {ok, BinData} = pt_11:write(11006, [Id, Nickname, Data, Color]),
    send_team(State, BinData),
    {noreply, State};

%%查看队伍信息
handle_cast({'SEND_TEAM_INFO', Id}, State) ->
    case ets:lookup(?ETS_ONLINE, State#team.leaderid) of
        [] -> ok;
        [Record] ->
            Data = [State#team.leaderid, length(State#team.member), Record#ets_online.nickname, State#team.teamname],
            {ok, BinData} = pt_24:write(24016, Data),
            lib_send:send_to_uid(Id, BinData)
    end,
    {noreply, State};

%%更新队伍资料
handle_cast({'UPDATE_TEAM_INFO', Team}, State) ->
    send_team_info(Team),
    {noreply, State};

%%广播给队员
handle_cast({'SEND_TO_MEMBER', Bin}, State) ->
    send_team(State, Bin),
    {noreply, State};

handle_cast(_R, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_R, _State) ->
    ok.

code_change(_OldVsn, State, _Extra)->
    {ok, State}.

%%私有函数-------------------------------------------------------------------

%%查看某玩家是否在线
is_online(Id) ->
    case ets:lookup(?ETS_ONLINE, Id) of
        [] -> [];
        [R] -> R
    end.

%%组装队员列表
pack_member(MemberList) when is_list(MemberList) ->
    F = fun(Id) ->
            case lib_player:get_user_info_by_id(Id) of
                [] -> [0, 0, 0, 0, []];
                Player ->
                    [Player#player_status.id, Player#player_status.lv, Player#player_status.career, Player#player_status.realm, Player#player_status.nickname]
            end
    end,
    [F(I#mb.id) || I <- MemberList].

%%向队伍所有成员发送队伍信息
send_team_info(Team) ->
    Data = [Team#team.leaderid, Team#team.teamname, pack_member(Team#team.member)],
    {ok, BinData} = pt_24:write(24010, Data),
    send_team(Team, BinData).

%%向所有队员发送信息
send_team(Team, Bin) ->
    F = fun(MemberId) ->
            lib_send:send_to_uid(MemberId, Bin)
    end,
    [F(M#mb.id)||M <- Team#team.member].
