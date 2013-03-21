%%%--------------------------------------
%%% @Module  : pp_chat
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.06
%%% @Description:  聊天功能
%%%--------------------------------------
-module(pp_chat).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%世界
handle(11001, Status, [Color, Data])
 when is_list(Data)->
    Data1 = [Status#player_status.id, Status#player_status.nickname, Data, Color],
    %% -------------------- 测试命令 ----------------
    case string:tokens(Data, " ") of
        ["del"] ->
            lib_account:delete_role(Status#player_status.id, Status#player_status.accname);
        ["taskdel", "all"] ->
            db_sql:execute(io_lib:format(<<"delete from task_bag where role_id = ~p">>, [Status#player_status.id])),
            db_sql:execute(io_lib:format(<<"delete from task_log where role_id = ~p">>, [Status#player_status.id])),
            lib_task:offline(Status),
            lib_task:flush_role_task(Status),
            lib_task:trigger(10100, Status),
            {ok, BinData1} = pt_30:write(30006, []),
            lib_send:send_one(Status#player_status.socket, BinData1);
        ["spr", Num] ->
            Num1 = list_to_integer(Num),
            Status1 = Status#player_status{spirit=Num1},
            gen_server:cast(Status1#player_status.pid, {'SET_PLAYER', Status1}),
            lib_player:refresh_spirit(Status#player_status.socket, Num1);
        _ -> skip
    end,
    %%--------------------- end --------------------
    {ok, BinData} = pt_11:write(11001, Data1),
    lib_send:send_to_all(BinData);

%%私聊
%%_Uid:用户ID
%%_Nick:用户名
%%Data:内容
%%_Uid 和 _Nick 任意一个即可
handle(11002, Status, [Color, _Uid, _Nick, Data])
 when is_list(Data)->
    Data1 = [Status#player_status.id, Status#player_status.nickname, Data, Color],
    {ok, BinData} = pt_11:write(11002, Data1),
    if  
        _Uid > 0 ->
            %%判断是否存在黑名单关系(存在则屏蔽,并返回信息)
            case pp_relationship:export_is_exists(_Uid, Status#player_status.id, 2) of
                {ok, false} -> lib_send:send_to_uid(_Uid, BinData);
                {_, true} -> lib_chat:chat_in_blacklist(_Uid, Status#player_status.sid)
            end;
        is_list(_Nick) ->  
            case ets:match_object(?ETS_ONLINE, #ets_online{nickname = _Nick, _ = '_'}) of
                [] -> ok;
                [R|_T] ->
                    case pp_relationship:export_is_exists(R#ets_online.id, Status#player_status.id, 2) of
                        {ok, false} -> lib_send:send_to_uid(R#ets_online.id, BinData);
                        {_, true} -> lib_chat:chat_in_blacklist(R#ets_online.id, Status#player_status.sid)
                    end
            end
    end;

%%场景
handle(11003, Status, [Color, Data])
 when is_list(Data)->
    Data1 = [Status#player_status.id, Status#player_status.nickname, Data, Color],
    %%io:format("~p~n",[Data1]),
    {ok, BinData} = pt_11:write(11003, Data1),
    lib_send:send_to_scene(Status#player_status.scene, BinData);

%%帮派
handle(11005, Status, [Color, Data])
 when is_list(Data)->
    Data1 = [Status#player_status.guild_id, Status#player_status.guild_name, Data, Color],
    {ok, BinData} = pt_11:write(11005, Data1),
    lib_send:send_to_guild(Status#player_status.guild_id, BinData);

%%队伍
handle(11006, Status, [Color, Data])
 when is_list(Data)->
     case is_pid(Status#player_status.pid_team) andalso is_process_alive(Status#player_status.pid_team) of
        true ->
            gen_server:cast(Status#player_status.pid_team, {'TEAM_MSG', Status#player_status.id, Status#player_status.nickname, Color, Data});
        false -> ok
    end;

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_chat no match", []),
    {error, "pp_chat no match"}.
