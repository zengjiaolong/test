%%%--------------------------------------
%%% @Module  : pp_team
%%% @Author  : zzm
%%% @Email   : ming_up@163.com
%%% @Created : 2010.07.06
%%% @Description:  组队功能管理
%%%--------------------------------------
-module(pp_team).
-export([handle/3]).
-include("record.hrl").
-include("common.hrl").

%%创建队伍
handle(24000, Status, TeamName) ->
    case is_pid(Status#player_status.pid_team) of
        false ->
            case validate_team_name(len, TeamName) of
                   {true, ok} ->  %%队名合法 
                        case mod_team:start(Status#player_status.id, Status#player_status.pid, Status#player_status.nickname, TeamName) of
                            {ok, PidTeam} ->
                                lib_team:send_leaderid_area_scene(Status#player_status.id, 1), %%告诉场景
                                {ok, BinData} = pt_24:write(24000, [1, TeamName]),
                                lib_send:send_one(Status#player_status.socket, BinData),
                                {ok, create_team, Status#player_status{pid_team = PidTeam, leader = 1}};
                            _Any ->
                                {ok, BinData} = pt_24:write(24000, [0, []]),
                                lib_send:send_one(Status#player_status.socket, BinData)
                        end;
                    {false, len_error} -> %%队名长度不符合
                        {ok, BinData} = pt_24:write(24000, [3, []]),
                        lib_send:send_one(Status#player_status.socket, BinData);
                    {false, illegal} ->   %%非法字符
                        {ok, BinData} = pt_24:write(24000, [4, []]),
                        lib_send:send_one(Status#player_status.socket, BinData)
             end;
        true ->
            {ok, BinData} = pt_24:write(24000, [2, []]),
            lib_send:send_one(Status#player_status.socket, BinData)
    end;

%%加入队伍
handle(24002, Status, Uid) ->
    case is_pid(Status#player_status.pid_team) of
        false ->
            case ets:lookup(?ETS_ONLINE, Uid) of
                [] -> %% 玩家不在线
                    {ok, BinData} = pt_24:write(24002, 3),
                    lib_send:send_one(Status#player_status.socket, BinData);
                [Record] ->
                    %%队伍是否存在
                    case is_pid(Record#ets_online.pid_team) of
                        true -> 
                            case gen_server:call(Record#ets_online.pid_team, 'JOIN_TEAM_REQ') of
                                {ok, mb_max, _LeaderId} -> 
                                    {ok, BinData} = pt_24:write(24002, 2),
                                    lib_send:send_one(Status#player_status.socket, BinData);
                                {ok, 1, LeaderId} ->
                                    %%向队长发送加入队伍请求
                                    Data = [Status#player_status.id, Status#player_status.lv, Status#player_status.career, Status#player_status.realm, Status#player_status.nickname],
                                    {ok, BinData} = pt_24:write(24003, Data),
                                    lib_send:send_to_uid(LeaderId, BinData),
                                    lib_chat:send_sys_msg_one(Status#player_status.socket, "入队请求已发出，等待队长回应");
                                {ok, in_dungeon, _} -> %%队伍在副本中
                                    {ok, BinData} = pt_24:write(24002, 5),
                                    lib_send:send_one(Status#player_status.socket, BinData);
                                _ -> ok
                                end;
                        false ->
                            {ok, BinData} = pt_24:write(24002, 3),
                            lib_send:send_one(Status#player_status.socket, BinData)
                    end
            end;
        true -> 
            {ok, BinData} = pt_24:write(24002, 4),
            lib_send:send_one(Status#player_status.socket, BinData)
    end;

%%队长回应加入队伍请求
handle(24004, Status, [Res, Uid]) -> 
       case is_pid(Status#player_status.pid_team) andalso is_process_alive(Status#player_status.pid_team) of
           true ->
            case gen_server:call(Status#player_status.pid_team, {'JOIN_TEAM_RES', Res, Uid}) of
                not_leader -> %%不是队长，无权操作
                    {ok, BinData} = pt_24:write(24004, 3),
                     lib_send:send_one(Status#player_status.socket, BinData);
                offline -> %%申请进队人下线了
                    {ok, BinData} = pt_24:write(24004, 0),
                    lib_send:send_one(Status#player_status.socket, BinData);
                mb_max -> %% 队伍人数已满
                    {ok, BinData} = pt_24:write(24002, 2),
                    lib_send:send_to_uid(Uid, BinData); 
                0 -> %%队长拒绝申请人进队
                    {ok, BinData} = pt_24:write(24002, 0),
                    lib_send:send_to_uid(Uid, BinData); 
                1 -> %% 申请人进队了
                    {ok, BinData} = pt_24:write(24004, 1),
                    lib_send:send_one(Status#player_status.socket, BinData),
                    {ok, BinData1} = pt_24:write(24002, 1),
                    lib_send:send_to_uid(Uid, BinData1);
                2 -> %% 申请人已经进其他队伍了
                    {ok, BinData} = pt_24:write(24004, 2),
                    lib_send:send_one(Status#player_status.socket, BinData);
                5 -> %% 队伍已经在副本中了
                    {ok, BinData} = pt_24:write(24002, 5),
                    lib_send:send_to_uid(Uid, BinData),
                    {ok, BinData1} = pt_24:write(24004, 5),
                    lib_send:send_one(Status#player_status.socket, BinData1);
                _ -> ok
            end;
        false -> %%你没有队伍
            {ok, BinData} = pt_24:write(24004, 4),
            lib_send:send_one(Status#player_status.socket, BinData)
    end;

%%离开队伍
%%Type: 
%%    offline => 下线离开队伍 
%%    [] => 玩家主动离开队伍
handle(24005, Status, Type) ->
    case is_pid(Status#player_status.pid_team) of
        false -> ok;
        true -> 
            R =  gen_server:call(Status#player_status.pid_team, {'QUIT_TEAM', Type}),
            case lists:member(R, [0, 1, 2]) of
                true ->
                    {ok, BinData} = pt_24:write(24005, R),
                    lib_send:send_one(Status#player_status.socket, BinData);
                _ -> ok
            end
    end;

%%邀请别人加入队伍
handle(24006, Status, Uid) ->
    case is_pid(Status#player_status.pid_team) of
        true ->
            case gen_server:call(Status#player_status.pid_team, {'INVITE_REQ', Uid}) of
                not_leader -> %%非队长
                    {ok, BinData} = pt_24:write(24006, 4),
                    lib_send:send_one(Status#player_status.socket, BinData);
                max_mb -> %%队伍人数已满
                    {ok, BinData} = pt_24:write(24006, 3),
                    lib_send:send_one(Status#player_status.socket, BinData);
                player_offline -> %%被邀请人已经下线
                    {ok, BinData} = pt_24:write(24006, 5),
                    lib_send:send_one(Status#player_status.socket, BinData);
                in_other_team -> %%被邀请人已经在其他队伍中
                    {ok, BinData} = pt_24:write(24006, 2),
                    lib_send:send_one(Status#player_status.socket, BinData);
                in_team -> ok; %%被邀请人已经在队伍中了
                {ok, TeamName} -> %% 向被邀请人发送信息
                    {ok, BinData} = pt_24:write(24007, [Status#player_status.id, Status#player_status.nickname, TeamName]),
                    lib_send:send_to_uid(Uid, BinData),
                    lib_chat:send_sys_msg_one(Status#player_status.socket, "邀请入队请求已发出，等待对方回应");
                _ -> ok
            end;
        false -> %%邀请人没有队伍
            {ok, BinData} = pt_24:write(24006, 6),
            lib_send:send_one(Status#player_status.socket, BinData)
    end;

%%邀请人回应邀请请求
handle(24008, Status, [LeaderId, Res]) ->
    case Res of
        0 -> ok; %%被邀请人拒绝了
        1 -> %%被邀请人同意了，检查队长还在线不
            case ets:lookup(?ETS_ONLINE, LeaderId) of
                [Record] -> %%检查队伍还存在不
                   case is_pid(Record#ets_online.pid_team) of
                     true ->
                         case is_pid(Status#player_status.pid_team) of
                             false -> %%邀请人没有加入队伍
                                 case gen_server:call(Record#ets_online.pid_team, {'INVITE_RES', Status#player_status.id, Status#player_status.pid, Status#player_status.nickname}) of
                                    1 ->  %%成功加入队伍
                                        {ok, BinData} = pt_24:write(24008, 1),
                                        lib_send:send_one(Status#player_status.socket, BinData);
                                    mb_max -> %%队伍人数已满
                                         {ok, BinData} = pt_24:write(24008, 0),
                                         lib_send:send_one(Status#player_status.socket, BinData);
                                    in_team -> ok; %% 正常不会出现这种情况
                                     in_dungeon -> 
                                        {ok, BinData} = pt_24:write(24008, 3),
                                        lib_send:send_one(Status#player_status.socket, BinData);
                                    _ -> ok
                                end;
                            true -> ok %%邀请人已经加入队伍了
                        end;
                     false -> 
                        %%队伍已经不存在了
                        {ok, BinData} = pt_24:write(24008, 2),
                        lib_send:send_one(Status#player_status.socket, BinData)
                    end;
                [] -> ok %%队长不在线
             end
     end;

%%踢出队伍
%%Uid 被踢人id
%%TeamId 队伍id
handle(24009, Status, Uid) ->
    Res = case Status#player_status.id =:= Uid of
        false ->
            case gen_server:call(Status#player_status.pid_team, {'KICK_OUT', Uid}) of
                0 -> 0; %% 踢出失败
                1 -> 1; %% 踢出成功
                2 -> 2; %% 你不是队长
                4 -> 0; %% 在副本中不能踢出队员
                _ -> 0
            end;
        true -> 3 %% 不能踢自己
    end,
    {ok, BinData1} = pt_24:write(24009, Res),
    % io:format("24009, Res: ~p~n", [Res]),
    lib_send:send_one(Status#player_status.socket, BinData1);
    

%%委任队长
%handle(24013, Status, Uid) ->
%     Res = case gen_server:call(Status#player_status.pid_team, {'CHANGE_LEADER', Uid}) of
%        not_leader -> 0;
%        not_team_member -> 0;
%        1 -> 1;
%        _ -> 0
%    end,
%    {ok, BinData} = pt_24:write(24013, Res),
%    lib_send:send_one(Status#player_status.socket, BinData);

%%更改队名
%handle(24014, Status, TeamName) ->
%    Res = case validate_team_name(len, TeamName) of
%        {true, ok} -> 
%            case gen_server:call(Status#player_status.pid_team, {'CHANGE_TEAMNAME', TeamName}) of
%                not_leader -> 0;
%                1 -> 1;
%                _ -> 0
%            end;
%        {false, len_error} -> 2;    %%队名长度不符合
%        {false, illegal} -> 3       %%非法字符
%    end,
%     {ok, BinData} = pt_24:write(24014, Res),
%     lib_send:send_one(Status#player_status.socket, BinData);

%%获取队伍信息
handle(24016, Status, Uid) ->
    %%是否在线
    case ets:lookup(?ETS_ONLINE, Uid) of
        [] -> ok;
        [Record] ->%%是否有队伍
            case is_pid(Record#ets_online.pid_team) of
                true ->
                    gen_server:cast(Record#ets_online.pid_team, {'SEND_TEAM_INFO', Status#player_status.id});
                false ->
                    {ok, BinData} = pt_24:write(24016, [0, 0, [], []]),
                    lib_send:send_one(Status#player_status.socket, BinData)
            end
    end;

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_team no match", []),
    {error, "pp_team no match"}.

%%检查队名长度是否合法
validate_team_name(len, TeamName) ->
    case asn1rt:utf8_binary_to_list(list_to_binary(TeamName)) of
        {ok, CharList} ->
            Len = string_width(CharList),  
            %% 队名最大长度暂时设为15个中文字 
            case Len < 31 andalso Len > 1 of
                true ->
                    {true, ok};
                false ->
                    %%队伍名称长度为1~15个汉字
                    {false, len_error}
            end;
        {error, _Reason} ->
            %%非法字符
            {false, illegal}
    end.

%% 字符宽度，1汉字=2单位长度，1数字字母=1单位长度
string_width(String) ->
    string_width(String, 0).
string_width([], Len) ->
    Len;
string_width([H | T], Len) ->
    case H > 255 of
        true ->
            string_width(T, Len + 2);
        false ->
            string_width(T, Len + 1)
    end.
