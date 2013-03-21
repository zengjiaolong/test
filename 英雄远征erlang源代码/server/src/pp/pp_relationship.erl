%%%--------------------------------------
%%% @Module  : pp_relationship
%%% @Author  : zzm
%%% @Email   : ming_up@163.com
%%% @Created : 2010.06.07
%%% @Description:  管理玩家间的关系
%%%--------------------------------------
-module(pp_relationship).
-export([handle/3, export_is_exists/3]).
-include("record.hrl").
-include("common.hrl").


%%请求好友列表
handle(14000, Status, []) ->
    set_ets_rela_record(Status#player_status.id),
    L = get_ets_rela_record(Status#player_status.id, 1),
    GL = case  ets:lookup(?ETS_RELA_SET, Status#player_status.id) of %%获取好友分组名字
            [] ->
                [list_to_binary("分组1"), list_to_binary("分组2"),  list_to_binary("分组3")];
            [G] -> [G#ets_rela_set.name1, G#ets_rela_set.name2, G#ets_rela_set.name3]
        end,
    L2 = [pack_friend_list(X)||X <- L],
    {ok,BinData} = pt_14:write(14000, [GL,L2]),
    lib_send:send_one(Status#player_status.socket, BinData);

%%发送好友请求
%%Type:加好友的类型(1:常规加好友,2:黑名单里加好友,3:仇人里加好友)
%%_Uid:用户ID
%%_Nick:角色名
handle(14001, Status, [Type, _Uid, _Nick]) ->
%    io:format("id ~p, nick ~p~n", [_Uid, _Nick]),
    %%检查回应方是否在线和是否已经是好友关系
    %%保证有数据
    set_ets_rela_record(Status#player_status.id),
    Val = case _Uid of 
            0 -> 
                %%检查用户名是否存在
            %    case db:find(player, nickname, _Nick) of
            %        {atomic, []} ->
            %            {not_exists_name};
            %        {atomic, _Val} ->
            case _Nick =:= Status#player_status.nickname of
                false ->
                     case ets:match(?ETS_ONLINE, #ets_online{id = '$1', nickname = _Nick, _ = '_'}) of
                        [] -> {offline, 0};
                        [[L]|_T] -> 
                            case is_exists(Status#player_status.id, L, 1) of
                                {_, true} -> error;
                                {ok, false} ->{online, L}
                            end
                     end;
                 true -> error
            end;
            Other -> 
                case _Uid =:= Status#player_status.id of
                    false ->
                        %%检查是否在线
                        case is_online(by_id, Other) of
                            0 -> {offline, 0};
                            1 -> %%检查是否已经存在好友关系
                                 case is_exists(Status#player_status.id, Other, 1) of
                                     {_, true} -> error;
                                     {ok, false} ->{online, Other}
                                 end
                         end;
                    true -> error
                end
        end,
    case Val of
        %%回应方在线
        {online, Id} ->
%           io:format("Id ~p~n", [Id]),
            %%保证有数据
            set_ets_rela_record(Id),
            case is_exists(Id, Status#player_status.id, 2) of
                {ok, false} ->
                    case is_exists(Id, Status#player_status.id, 1) of
                        {ok, false} ->
                            %%回应方没有加发送方为好友
%                           io:format("no friend relationship!!~n"),
                            Data1 = [Type, Status#player_status.id,Status#player_status.lv, Status#player_status.sex, Status#player_status.career, Status#player_status.nickname],
                            {ok, BinData} = pt_14:write(14001, Data1),
                            lib_send:send_to_uid(Id, BinData),
                            lib_chat:send_sys_msg_one(Status#player_status.socket, "加好友请求已发出，等待对方回应");
                            
                   
                        {_Rid, true} ->
                            %%回应方已经加了发送方为好友 
                            case get_info(by_id, Id) of
                                [] -> ok;
                                Info ->
                                    lib_relationship:add(Status#player_status.id, Id, 1),
                                    Data1 = [1, Info#ets_rela_info.id, Info#ets_rela_info.lv, Info#ets_rela_info.sex, Info#ets_rela_info.career, Info#ets_rela_info.nickname],
                                    {ok, BinData} = pt_14:write(14002, Data1),
                                    lib_send:send_to_uid(Status#player_status.id, BinData)
                             end
                            %case is_exists(Status#player_status.id, Id, 3) of
                            %    {Rid2, true} ->
                            %        lib_relationship:delete(Rid2),
                            %        handle(14008, Status, []);   
                            %    {ok, false} -> ok
                            %end
                    end;
                {_, true} ->
%                    io:format("you're in ~p blacklist~n", [Id]),
                    {ok, BinData} = pt_14:write(14002, [3]),
                    lib_send:send_one(Status#player_status.socket, BinData)
            end;
        %%回应方不在线
        {offline, _} ->
%           io:format("friend req but user offline!!~n"),
            {ok, BinData} = pt_14:write(14002, [2]),
            lib_send:send_one(Status#player_status.socket, BinData);
        %%加自己为好友
        error -> ok
        %%用户名不存在
%        {not_exists_name} ->
%            io:format("not exists name !!~n"),
%            {ok, BinData} = pt_14:write(14002, [4]),
%            lib_send:send_one(Status#player_status.socket, BinData)
    end;

%%回应好友请求
%%Type:加好友的类型(1:常规加好友,2:黑名单里加好友,3:仇人里加好友)
%%Res:拒绝或接受请求(0表示拒绝/1表示接受)
%%Uid:用户ID
handle(14002, Status, [_Type, Res, Uid]) ->
%   io:format("friend res ~p~n", [[Res, Uid]]),
    case Res of
        0 -> 
            Data1 = [Res, Status#player_status.id,Status#player_status.lv, Status#player_status.sex, Status#player_status.career, Status#player_status.nickname],
            {ok, BinData} = pt_14:write(14002, Data1),
            lib_send:send_to_uid(Uid, BinData);
        1 ->
            %%保证有数据
            set_ets_rela_record(Status#player_status.id),
            set_ets_rela_record(Uid),
            %%查看是否已经加过好友了
            {_, F1} = is_exists(Uid, Status#player_status.id, 1),
            {_, F2} = is_exists(Status#player_status.id, Uid, 1),
            case F1 or F2 of
                false ->
                    lib_relationship:add(Uid, Status#player_status.id, 1),
                    lib_relationship:add(Status#player_status.id, Uid, 1),
                    case is_exists(Status#player_status.id, Uid, 3) of
                        {Rid, true} -> 
                            lib_relationship:delete(Rid),
                            handle(14008, Status, []);
                        {ok, false} -> ok
                    end,
                     handle(14000, Status, []),
                    Data1 = [Res, Status#player_status.id,Status#player_status.lv, Status#player_status.sex, Status#player_status.career, Status#player_status.nickname],
                    {ok, BinData} = pt_14:write(14002, Data1),
                    lib_send:send_to_uid(Uid, BinData),                
                    %%如果发出请求方与被请求方有黑名单/仇人关系，则需刷新请求方的黑名单/仇人列表
                    case is_exists(Uid, Status#player_status.id, 2) of
                        {Rid1, true} ->
                             lib_relationship:delete(Rid1),
                             BL = get_ets_rela_record(Uid, 2),        %% 获取黑名单列表
                             BL2 = [pack_blacklist_list(X)||X <- BL],
                             {ok,BinData1} = pt_14:write(14007,BL2),
                             lib_send:send_to_uid(Uid, BinData1);
                         {ok, false} -> ok
                    end;
                   % case is_exists(Uid, Status#player_status.id, 3) of
                   %     {Rid2, true} ->
                   %          lib_relationship:delete(Rid2),
                   %          EL = get_ets_rela_record(Uid, 3),        %% 获取仇人列表
                   %          EL2 = [pack_enemy_list(X)||X <- EL],
                   %          {ok,BinData2} = pt_14:write(14008, EL2),
                   %          lib_send:send_to_uid(Uid, BinData2);
                   %      {ok, false} -> ok
                   % end;
                true -> ok
            end
    end;
    

%%删除好友
%%Uid 要删除的好友Id
handle(14003, Status, Rid) ->
    case ets:lookup(?ETS_RELA, Rid) of
        [] -> ok;
        [Record] -> 
            case Record#ets_rela.idA =:= Status#player_status.id of
                true ->
                    case lib_relationship:delete(Rid) of
                    {ok, 1} ->
                        {ok, BinData} = pt_14:write(14003, 1),
                        lib_send:send_one(Status#player_status.socket, BinData);
                    {ok, 0} ->
                        {ok, BinData} = pt_14:write(14003, 0),
                        lib_send:send_one(Status#player_status.socket, BinData)
                    end;
                false -> ok
            end
    end;

%%添加黑名单
%%_Uid 玩家友Id
%%_Nick 玩家名字
handle(14004, Status, Uid) ->
    %%保证有数据
    set_ets_rela_record(Status#player_status.id),
    case is_exists(Status#player_status.id, Uid, 2) of
        {_, true} -> ok;
        {ok, false} ->
            %%添加黑名单关系
            case lib_relationship:add(Status#player_status.id, Uid, 2) of
                {ok, 1} ->
                %%删除好友关系
                    case is_exists(Status#player_status.id, Uid, 1) of
                        {Rid, true} ->
                            lib_relationship:delete(Rid);
                        {ok, false} ->
                            ok
                    end,
                    %%告之双方客户端
                    {ok, BinData} = pt_14:write(14004,[1,Uid]),
                    lib_send:send_one(Status#player_status.socket, BinData),

                    %%保证有数据
                    set_ets_rela_record(Uid),
                    case is_exists(Uid, Status#player_status.id, 1) of
                        {ok, false} -> 
                            ok;
                        {Rid1, true} ->
                            %%告之被加黑名单的用户,更新好友列表
                            lib_relationship:delete(Rid1),
                            Data = [2, Status#player_status.id],
                            {ok, BinData1} = pt_14:write(14004, Data),
                            lib_send:send_to_uid(Uid, BinData1)
                    end;
                {ok, 0} ->
                    {ok, BinData} = pt_14:write(14004, [0,0]),
                    lib_send:send_one(Status#player_status.socket, BinData)
            end
    end;

%%添加仇人
%%Uid:仇人id
handle(14005, Status, Uid) ->
    %%保证有数据
    set_ets_rela_record(Status#player_status.id),
    case is_exists(Status#player_status.id, Uid, 3) of
        {_, true} -> ok;
        {ok, false} ->
            case lib_relationship:add(Status#player_status.id, Uid, 3) of
                {ok, 1} -> 
                    % 删除好友关系
                    %case is_exists(Status#player_status.id, Uid, 1) of
                    %    {Rid, true} ->
                    %        lib_relationship:delete(Rid);
                    %    {ok, false} -> ok
                    %end,
                    {ok, BinData} = pt_14:write(14005, [1, Uid]),
                    lib_send:send_one(Status#player_status.socket, BinData);
                {ok, 0} ->
                    {ok, BinData} = pt_14:write(14005, [0, 0]),
                    lib_send:send_one(Status#player_status.socket, BinData)
            end
    end;

%%改变好友分组的名字
%%Id:用户角色id
%%N:第N个分组(N = 1,2,3)
%%Gname:分组新名字
handle(14006, Status, [N, Gname]) ->
    case is_integer(N) andalso N > 0 andalso N < 4 of
        true ->
            case ets:lookup(?ETS_RELA_SET, Status#player_status.id) of
                [] -> 
                    {ok, R} = lib_relationship:new_friend_group(Status#player_status.id, N, Gname),
                    New = #ets_rela_set{id = Status#player_status.id},
                    New1 = setelement(N+2, New, list_to_binary(Gname)),
                    ets:insert(?ETS_RELA_SET, New1),
                    {ok, BinData} = pt_14:write(14006, R),
                    lib_send:send_one(Status#player_status.socket, BinData);
                [Record] ->       
                    %% 更新数据库
                    {ok, R} = lib_relationship:set_friend_group_name(Status#player_status.id, N, Gname),
                    %% 更新ets_rela_set表
                    NewR = setelement(N+2, Record, list_to_binary(Gname)),
                    ets:insert(?ETS_RELA_SET, NewR),
                    {ok, BinData} = pt_14:write(14006, R),
                    lib_send:send_one(Status#player_status.socket, BinData)
            end;
        false -> ok
    end;

%%请求黑名单列表
handle(14007, Status, []) ->
    set_ets_rela_record(Status#player_status.id),
    L = get_ets_rela_record(Status#player_status.id, 2),        %% 获取黑名单列表
    L2 = [pack_blacklist_list(X)||X <- L],
    {ok,BinData} = pt_14:write(14007,L2),
    lib_send:send_one(Status#player_status.socket, BinData);

%%请求仇人列表
handle(14008, Status, []) ->
    set_ets_rela_record(Status#player_status.id),
    L = get_ets_rela_record(Status#player_status.id, 3),        %% 获取仇人列表
    L2 = [pack_enemy_list(X)||X <- L],
    {ok,BinData} = pt_14:write(14008, L2),
    lib_send:send_one(Status#player_status.socket, BinData);

%%移动好友到别的分组
handle(14009, Status, [Id, N]) ->
    case ets:lookup(?ETS_RELA, Id) of
        [] -> ok;
        [Record] ->
            {ok, R} = lib_relationship:move_friend(Id, N),
            ets:insert(?ETS_RELA, Record#ets_rela{group = N}),
            {ok, BinData} = pt_14:write(14009, R),
            lib_send:send_one(Status#player_status.socket, BinData)
    end;

%%查找角色
handle(14010, Status, Nick) ->
    if 
        Nick /= Status#player_status.nickname ->
           Val = case ets:match(?ETS_ONLINE, #ets_online{id = '$1', nickname = Nick, _ = '_'}) of
                [] -> {offline, 0};
                [[L]|_T] -> {online, L}
                 end,
            case Val of
                {offline, _} -> 
                    {ok, BinData} = pt_14:write(14010,[]),
                    lib_send:send_one(Status#player_status.socket, BinData);
                {online, Id} ->%% NOTE:get_user_info_by_id/1使用了handle_call回调,不能查自己的信息
                case lib_player:get_user_info_by_id(Id) of
                        [] -> 
                            {ok, BinData} = pt_14:write(14010,[]),
                            lib_send:send_one(Status#player_status.socket, BinData);
                        Player ->
                            Data = [1, Player#player_status.id, Player#player_status.lv, Player#player_status.sex, Player#player_status.career, Player#player_status.guild_name, Player#player_status.nickname],
                            {ok, BinData} = pt_14:write(14010, Data),
                            lib_send:send_one(Status#player_status.socket, BinData)
                 end
            end;
        true -> %%查询自己
            Data = [1, Status#player_status.id, Status#player_status.lv, Status#player_status.sex, Status#player_status.career, Status#player_status.guild_name, Status#player_status.nickname],
            {ok, BinData} = pt_14:write(14010, Data),
            lib_send:send_one(Status#player_status.socket, BinData)
 end;

%%查询陌生人资料
handle(14013, Status, Uid) ->
    if Uid =:= Status#player_status.id ->
            ok;
        true -> case lib_player:get_user_info_by_id(Uid) of
                [] -> ok;
                Player -> 
                    Data = [Player#player_status.id, Player#player_status.lv, Player#player_status.sex, Player#player_status.career, Player#player_status.nickname],
                    {ok, BinData} = pt_14:write(14013, Data),
                    lib_send:send_to_sid(Status#player_status.sid, BinData)
            end
    end;

%%发送自动回复设置
%handle(14011, _Status, Id) ->
%    Data = lib_relationship:get_auto_res(Id),
%    {ok, BinData} = pt_14:write(14011, Data),
%    lib_send:send_to_uid(Id, BinData);

%%设置自动回复
%handle(14012, Status, [AutoRes, Msg]) ->
%     {ok, R} = lib_relationship:set_auto_res(Status#player_status.id, AutoRes, Msg),
%    {ok, BinData} = pt_14:write(14012, R),
%    lib_send:send_one(Status#player_status.socket, BinData);

%%被好友杀死
%%Aid 攻击方id
%%Anick 攻击方名字
%%Did 被攻击方id
%handle(14013, [Aid, Anick], [Did, Dnick]) ->
%    %%保证有数据 
%    set_ets_rela_record(Did),
%    case is_exists(Did, Aid, 3) of
%        {ok, false} -> 
%            case is_exists(Did, Aid, 1) of
%                {ok, false} ->
                    %%没有好友关系，直接添加仇人
%                    lib_relationship:add(Did, Aid, 3),
%                    EL = get_ets_rela_record(Did, 3),        %% 获取仇人列表
%                    EL2 = [pack_enemy_list(X)||X <- EL],
%                    {ok,BinData2} = pt_14:write(14008, EL2),
%                    lib_send:send_to_uid(Did, BinData2);
%                 {_, true} ->
%                    io:format("14013~n"),
%                    %%有好友关系，向被杀死的玩家发送邮件
%                    Title = "您被好友" ++ Anick ++ "杀死",
%                    {{Y, Mo, D}, {H, Mi, S}} = erlang:localtime(),
%                    Time = lists:concat([Y, "年", Mo, "月", D, "日 ", H, "时", Mi, "分", S, "秒"]),
%                    Content = lists:concat(["尊敬的玩家：\n", "    您于", Time, "被好友", Anick, "杀死"]),
%                    lib_mail:send_sys_mail([Dnick], Title, Content, 0, 0, 0, 0)
%            end;
%       _ -> ok
%    end;

%%删除黑名单
handle(14020, Status, Id) ->
    case ets:lookup(?ETS_RELA, Id) of
        [] -> ok;
        [R]-> 
            case R#ets_rela.idA =:= Status#player_status.id of
                true ->
                    {ok, Res} = lib_relationship:delete(Id),
                    {ok, BinData} = pt_14:write(14020, Res),
                    lib_send:send_one(Status#player_status.socket, BinData);
                false -> ok
            end
    end;

%%删除仇人
handle(14021, Status, Id) ->
    case ets:lookup(?ETS_RELA, Id) of
        [] -> ok;
        [R] ->
            case R#ets_rela.idA =:= Status#player_status.id of
                true ->
                    {ok, Res} = lib_relationship:delete(Id),
                    {ok, BinData} = pt_14:write(14021, Res),
                    lib_send:send_one(Status#player_status.socket, BinData);
                false -> ok
            end
    end;

%%好友上下线通知
%%Uid 上下线角色id
%%Line 上线:1;下线:0
handle(14030, _Status, [Uid, Line, Nick]) ->
    L = get_idA_list(Uid, 1),
    {ok, BinData} = pt_14:write(14030, [Uid, Line, Nick]),
    F = fun(Id)->  
            lib_send:send_to_uid(Id, BinData)
    end,
    [F(IdA) || [IdA] <- L];

%%仇人上下线通知
handle(14031, _Status, [Uid, Line, Nick]) ->
    L = get_idA_list(Uid, 3),
    {ok, BinData} = pt_14:write(14031, [Uid, Line, Nick]),
    F = fun(Id)->        
            lib_send:send_to_uid(Id, BinData)
    end,
    [F(IdA) || [IdA] <- L];

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_relationship no match", []),
    {error, "pp_relationship no match"}.

%%IdA是否加了IdB为Rela关系(用于外部模块)
%%Rela: 1:好友;2:黑名单;3:仇人
export_is_exists(IdA, IdB, Rela) ->
   %%保证有数据 
    set_ets_rela_record(IdA),
    case ets:match(?ETS_RELA, #ets_rela{id = '$1', idA = IdA, idB = IdB, rela = Rela, _ = '_'}) of
        [] ->{ok, false};
        [[Id]|_T] -> {Id, true}
    end.

%% 私有函数---------------------------------------------------

%% 检查是否在线
is_online(by_id, Id) ->
    case ets:lookup(?ETS_ONLINE, Id) of
            [] -> 0;
            _Other -> 1
    end;
is_online(by_nick, Nick) ->
    case ets:match(?ETS_ONLINE, #ets_online{id = '$1', nickname = Nick, _ = '_'}) of
            [] -> 0;
            _Other -> 1
    end.

%设置某玩家在ets_rela中的所有记录
set_ets_rela_record(Uid) ->
    case ets:match_object(?ETS_RELA, #ets_rela{idA = Uid, _ = '_'}) of
        [] -> 
            %%如果为空，则从数据库中读取全部关系
            L = lib_relationship:find(Uid),                %% 从数据库中读取
            [ets:insert(?ETS_RELA, write_ets_rela_object(R)) || R <- L],    %% 所有关系存放到ets表中
            ok;
        _L -> ok
    end.

%%读取ets_rela中是否有某玩家的好友/黑名单/仇人记录
get_ets_rela_record(Uid, Rela) ->
    case ets:match_object(?ETS_RELA, #ets_rela{idA = Uid, rela = Rela, _ = '_'}) of
        [] -> [];
        L -> L
    end.

%%编写ets_rela记录对象
write_ets_rela_object([Id, IdA, IdB, Rela, Intimacy, Group]) ->
    #ets_rela{
            id = Id, 
            idA = IdA, 
            idB = IdB, 
            rela = Rela, 
            intimacy = Intimacy, 
            group = Group
        }.

%%组装好友列表
pack_friend_list(R) when is_record(R, ets_rela)->
    case get_info(by_id, R#ets_rela.idB) of
       [] -> %% 有可能用户不存在，既然不存在此用户，把这条记录也删去了
           lib_relationship:delete(R#ets_rela.id),
           [];
       Info ->
             [is_online(by_id, R#ets_rela.idB), R#ets_rela.idB, R#ets_rela.intimacy, R#ets_rela.group, Info#ets_rela_info.lv, Info#ets_rela_info.sex, Info#ets_rela_info.career, Info#ets_rela_info.nickname, R#ets_rela.id]
    end.

%%组装仇人列表
pack_enemy_list(R) when is_record(R, ets_rela) ->
    case get_info(by_id, R#ets_rela.idB) of
        [] -> %% 有可能用户不存在，既然不存在此用户，把这条记录也删去了
           lib_relationship:delete(R#ets_rela.id),
           [];
        Info ->
            [is_online(by_id, R#ets_rela.idB), R#ets_rela.idB, Info#ets_rela_info.lv, Info#ets_rela_info.sex, Info#ets_rela_info.career, Info#ets_rela_info.nickname, R#ets_rela.id]
    end.

%%组装黑名单列表
pack_blacklist_list(R) when is_record(R, ets_rela) ->
    case get_info(by_id, R#ets_rela.idB) of
       [] -> %% 有可能用户不存在，既然不存在此用户，把这条记录也删去了
           lib_relationship:delete(R#ets_rela.id),
           [];
       Info ->
            [R#ets_rela.idB, Info#ets_rela_info.lv, Info#ets_rela_info.sex, Info#ets_rela_info.career, Info#ets_rela_info.nickname, R#ets_rela.id]
    end.

%%查找角色信息(从缓存中读取，如果没有则从数据库中读取)
get_info(by_id, Id) ->
    case ets:lookup(?ETS_RELA_INFO, Id) of
        [] ->
            case db_sql:get_row(io_lib:format(<<"select id, nickname, sex, lv, career from player where id = ~p">>, [Id])) of
                [] ->
                    [];
                [Id, Nick, Sex, Lv, Career] -> 
                    R = #ets_rela_info{id = Id, nickname = Nick, sex = Sex, lv = Lv, career = Career},
                    ets:insert(?ETS_RELA_INFO, R),
                    R
            end;
        [Info] -> Info
    end.

%%检查A与B是否存在Rela关系
is_exists(IdA, IdB, Rela) ->
    case ets:match(?ETS_RELA, #ets_rela{id = '$1', idA = IdA, idB = IdB, rela = Rela, _ = '_'}) of
        [] ->{ok, false};
        [[Id]|_T] -> {Id, true}
    end.

%%获取某条记录的id(从ets中获取)
%get_id(IdA, IdB, Rela) ->
%    case ets:match(?ETS_RELA, #ets_rela{id = '$1', idA = IdA, idB = IdB, rela = Rela, _ = '_'}) of
%        [] -> 0;
%        [[Id]] -> Id
%    end.

%% 取ets_rela{idB = Uid, rela = Rela}的记录，返回idA的列表
get_idA_list(Uid, Rela) ->
    case ets:match(?ETS_RELA, #ets_rela{idA = '$1', idB = Uid, rela = Rela, _ = '_'}) of
        [] -> [];
        L -> L
    end.
