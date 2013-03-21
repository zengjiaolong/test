%%%---------------------------------------------
%%% @Module  : pet_test
%%% @Author  : shebiao
%%% @Email   : shebiao@jieyou.com
%%% @Created : 2010.07.21
%%% @Description: 客户端测试程序
%%%---------------------------------------------
-module(pet_test).
-include("common.hrl").
-compile(export_all).

for(Max, Max, _F, X) ->
    X;
for(Min, Max, F, X) ->
    F(X),
    for(Min+1, Max, F, X).

 sleep_send({T, S}) ->
    receive
    after T -> handle(run, a, S)
    end.

loop2(N) ->
%    case gen_tcp:connect(?HOST, ?PORT, [binary, {packet, 0}], 100000) of
    case gen_tcp:connect("localhost", 6666, [binary, {packet, 0}], 100000) of
        {ok, Socket} ->
            io:format("connect ok: ~p~n", [N]),
            sleep(10),
            % 登录消息10000
            handle(login, {123, integer_to_list(123620)}, Socket),
            sleep(10),
            % 创建角色消息10003
%            handle(create_player, {1, 1, integer_to_list(N)}, Socket),
%            sleep(10),
            % 进入场景消息10004
            handle(enter_player, {1}, Socket),
            sleep(10),
            % 心跳消息10006
%            handle(heart, 0, Socket),
%            sleep(10),
            % 移动消息12001
%            handle(run, a, Socket),
%            sleep(10),
            %%孵化宠物
%            handle(incubate_pet, {900001, 1}, Socket),
%            sleep(10),
            %%放生宠物
%            handle(free_pet, {133}, Socket),
%            sleep(10),
            %%改名宠物
%            handle(rename_pet, {134, "我的宠物"}, Socket),
%            sleep(10),
            %%出战宠物
%            handle(fighting_pet, {8}, Socket),
%            sleep(10),
            %%休息宠物
%            handle(rest_pet, {8}, Socket),
%            sleep(10),
            %%属性洗练
%            handle(shuffle_attribute, {135, 1, 900006, 1}, Socket),
%            sleep(10),
            %%洗练属性使用
%            handle(use_attribute, {9, 1}, Socket),
%            sleep(10),
            %%获取宠物信息
            handle(get_pet_info, {123}, Socket),
            sleep(10),
            %%获取宠物列表
%            handle(get_pet_list, {1}, Socket),
%            sleep(10),
            %%宠物出战替换
%            handle(fighting_replace, {8, 9}, Socket),
%            sleep(10),
            %%获取升级队列个数
%            handle(get_upgrade_que_num, {}, Socket),
%            sleep(10),
            %%开始升级
%            handle(start_upgrade, {8}, Socket),
%            sleep(10),
            %%完成升级
%            handle(finish_upgrade, {8}, Socket),
%            sleep(10),
            %%加速升级
%            handle(shorten_upgrade, {8, 2000}, Socket),
%            sleep(10),
            %%扩展队列
%            handle(extent_que, {}, Socket),
%            sleep(10),
            %%宠物喂养
%            handle(feed_pet, {135, 900003, 100}, Socket),
%            sleep(10),
            %%宠物驯养
%            handle(domesticate_pet, {135, 0, 900007, 10}, Socket),
%            sleep(10),            handle(enhance_quality, {135, 900010, 1}, Socket),
%            sleep(10),
%            %%宠物进阶
%            handle(enhance_quality, {135, 900010, 1}, Socket),
%            sleep(10),
             %%取消升级
%            handle(cancel_upgrade, {8}, Socket),
%            sleep(10),
             %%体力值同步
%            handle(strength_sync, {}, Socket),
%            sleep(10),
            rec(Socket);
        {error, Reason} ->
            io:format("connect failed: ~p~n", [Reason])   
    end.

for(Max, Max, _F) ->
    [];
for(Min, Max, F) ->
    [F(Min) | for(Min+1, Max, F)].

%% 循环测试
ct(N) ->
    F = fun(N1) ->
            spawn(fun() -> loop2(N1+10000) end),
            sleep(500)
        end,
    for(1, N+1, F),
    ok.


%%心跳包
handle(heart, _, Socket) ->
    io:format("client send: heart Cmd=[10006]~n"),
    gen_tcp:send(Socket, <<4:16, 10006:16>>),
    ok;%rec(Socket);
%%登陆
handle(login, {Accid, AccName}, Socket) ->
    io:format("client send: login Cmd=[10000], Accid=[~p], AccName=[~p] ~n", [Accid, AccName]),
    AccStamp = 1273027133,
    Tick = integer_to_list(Accid) ++ AccName ++ integer_to_list(AccStamp) ++ ?TICKET,
    TickMd5 = util:md5(Tick),
    TickMd5Bin = list_to_binary(TickMd5),
    AccNameLen = byte_size(list_to_binary(AccName)),
    AccNameBin = list_to_binary(AccName),
    Data = <<Accid:32, AccStamp:32, AccNameLen:16, AccNameBin/binary, 32:16, TickMd5Bin/binary>>,
    Len = byte_size(Data) + 4,
    gen_tcp:send(Socket, <<Len:16, 10000:16, Data/binary>>),
    ok;%rec(Socket);
%%创建用户
handle(create_player, {Pro, Sex, Name}, Socket) ->
    io:format("client send: create_player Cmd=[10003], Pro=[~p], Sex=[~p], Name[~p] ~n", [Pro, Sex, Name]),
    NameBin = list_to_binary(Name),
    NameLen = byte_size(NameBin),
    Data = <<Pro:16, Sex:16, NameLen:16, NameBin/binary>>,
    Len = byte_size(Data) + 4,
    gen_tcp:send(Socket, <<Len:16, 10003:16, Data/binary>>),
    ok;%%rec(Socket);
%%玩家列表
handle(list_player, _, Socket) ->
    io:format("client send: list_player Cmd=[10002]~n"),
    gen_tcp:send(Socket, <<6:16, 10002:16, 1:16>>),
    rec(Socket);
%%选择角色进入
handle(enter_player, {PlayerId}, Socket) ->
    io:format("client send: enter_player Cmd=[10004], PlayerId=[~p] ~n", [PlayerId]),
    gen_tcp:send(Socket, <<8:16, 10004:16, PlayerId:32>>),
    ok;%rec(Socket);

%%孵化宠物
handle(incubate_pet, {GoodsId, GoodsNum}, Socket) ->
    io:format("client send: incubate_pet Cmd=[41001], GoodsId=[~p],GoodsNum=[~p]~n", [GoodsId, GoodsNum]),
    MsgLen = byte_size(<<1:16,41001:16,GoodsId:32,GoodsNum:16>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41001:16, GoodsId:32,GoodsNum:16>>),
    ok;%rec(Socket);

%%放生宠物
handle(free_pet, {PetId}, Socket) ->
    io:format("client send: free_pet Cmd=[41002], PetId=[~p] ~n", [PetId]),
    MsgLen = byte_size(<<1:16,41002:16,PetId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41002:16, PetId:32>>),
    ok;%rec(Socket);

%%改名宠物
handle(rename_pet, {PetId, PetName}, Socket) ->
    Name  = list_to_binary(PetName),
    NameLen = byte_size(Name),
    io:format("client send: free_pet Cmd=[41003], PetId=[~p] ~n", [PetId]),
    MsgLen = byte_size(<<1:16,41003:16,PetId:32, NameLen:16,"我的宠物">>),
    gen_tcp:send(Socket, <<MsgLen:16, 41003:16, PetId:32, NameLen:16,"我的宠物">>),
    ok;%rec(Socket);

%%出战宠物
handle(fighting_pet, {PetId}, Socket) ->
    io:format("client send: fighting_pet Cmd=[41004], PetId=[~p] ~n", [PetId]),
    MsgLen = byte_size(<<1:16,41004:16,PetId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41004:16, PetId:32>>),
    ok;%rec(Socket);

%%休息宠物
handle(rest_pet, {PetId}, Socket) ->
    io:format("client send: rest_pet Cmd=[41005], PetId=[~p] ~n", [PetId]),
    MsgLen = byte_size(<<1:16,41005:16,PetId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41005:16, PetId:32>>),
    ok;%rec(Socket);

%%属性洗练
handle(shuffle_attribute, {PetId, PayType, GoodsId, GoodsNum}, Socket) ->
    io:format("client send: shuffle_attribute Cmd=[41006], PetId=[~p], PayType=[~p], GoodsId=[~p], GoodsNum=[~p]~n", [PetId, PayType, GoodsId, GoodsNum]),
    MsgLen = byte_size(<<1:16,41006:16,PetId:32,PayType:16,GoodsId:32,GoodsNum:16>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41006:16, PetId:32,PayType:16,GoodsId:32,GoodsNum:16>>),
    ok;%rec(Socket);

%%洗练属性使用
handle(use_attribute, {PetId, ActionType}, Socket) ->
    io:format("client send: use_attribute Cmd=[41007], PetId=[~p], ActionType=[~p]~n", [PetId, ActionType]),
    MsgLen = byte_size(<<1:16,41007:16,PetId:32,ActionType:16>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41007:16, PetId:32, ActionType:16>>),
    ok;

%%开始升级
handle(start_upgrade, {PetId}, Socket) ->
    io:format("client send: start_upgrade Cmd=[41008], PetId=[~p]~n", [PetId]),
    MsgLen = byte_size(<<1:16,41008:16,PetId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41008:16, PetId:32>>),
    ok;

%%加速升级
handle(shorten_upgrade, {PetId, ShortenTime}, Socket) ->
io:format("client send: start_upgrade Cmd=[41009], PetId=[~p], ShortenTime=[~p]~n", [PetId, ShortenTime]),
    MsgLen = byte_size(<<1:16,41009:16,PetId:32, ShortenTime:16>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41009:16, PetId:32, ShortenTime:16>>),
    ok;

%%完成升级
handle(finish_upgrade, {PetId}, Socket) ->
    io:format("client send: finish_upgrade Cmd=[41010], PetId=[~p]~n", [PetId]),
    MsgLen = byte_size(<<1:16,41010:16,PetId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41010:16, PetId:32>>),
    ok;

%%扩展队列
handle(extent_que, {}, Socket) ->
io:format("client send: start_upgrade Cmd=[41011]~n", []),
    MsgLen = byte_size(<<1:16,41011:16>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41011:16>>),
    ok;

%%宠物喂养
handle(feed_pet, {PetId, GoodsId, GoodsNum}, Socket) ->
    io:format("client send: feed_pet Cmd=[41012], PetId=[~p], GoodsId=[~p], GoodsNum=[~p] ~n", [PetId, GoodsId, GoodsNum]),
    MsgLen = byte_size(<<1:16,41012:16,PetId:32,GoodsId:32,GoodsNum:16>>),
    gen_tcp:send(Socket, <<MsgLen:16,41012:16,PetId:32,GoodsId:32,GoodsNum:16>>),
    ok;%rec(Socket);

%%宠物驯养
handle(domesticate_pet, {PetId, Type, GoodsId, GoodsNum}, Socket) ->
    io:format("client send: domesticate_pet Cmd=[41013], PetId=[~p], Type=[~p], GoodsId=[~p], GoodsNum=[~p] ~n", [PetId, Type, GoodsId, GoodsNum]),
    MsgLen = byte_size(<<1:16,41013:16,PetId:32,Type:16, GoodsId:32,GoodsNum:16>>),
    gen_tcp:send(Socket, <<MsgLen:16,41013:16,PetId:32,Type:16, GoodsId:32,GoodsNum:16>>),
    ok;%rec(Socket);

%%宠物进阶
handle(enhance_quality, {PetId, GoodsId, GoodsNum}, Socket) ->
    io:format("client send: enhance_quality Cmd=[41014], PetId=[~p], GoodsId=[~p], GoodsNum=[~p] ~n", [PetId, GoodsId, GoodsNum]),
    MsgLen = byte_size(<<1:16,41014:16,PetId:32,GoodsId:32,GoodsNum:16>>),
    gen_tcp:send(Socket, <<MsgLen:16,41014:16,PetId:32,GoodsId:32,GoodsNum:16>>),
    ok;%rec(Socket);

%%获取宠物信息
handle(get_pet_info, {PetId}, Socket) ->
    io:format("client send: get_pet_info Cmd=[41015], PetId=[~p] ~n", [PetId]),
    MsgLen = byte_size(<<1:16,41016:16,PetId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41016:16, PetId:32>>),
    ok;%rec(Socket);

%%获取宠物列表
handle(get_pet_list, {PlayerId}, Socket) ->
    io:format("client send: get_pet_list Cmd=[41017], PlayerId=[~p] ~n", [PlayerId]),
    MsgLen = byte_size(<<1:16,41017:16,PlayerId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41017:16, PlayerId:32>>),
    ok;%rec(Socket);

%%出战宠物替换
handle(fighting_replace, {PetId, ReplacedPetId}, Socket) ->
    io:format("client send: fighting_pet Cmd=[41018], PetId=[~p], ReplacedPetId=[~p] ~n", [PetId, ReplacedPetId]),
    MsgLen = byte_size(<<1:16,41018:16,PetId:32,ReplacedPetId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41018:16, PetId:32,ReplacedPetId:32>>),
    ok;%rec(Socket);

%%获取升级队列个数
 handle(get_upgrade_que_num, {}, Socket) ->
    io:format("client send: fighting_pet Cmd=[41019]~n", []),
    MsgLen = byte_size(<<1:16,41019:16>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41019:16>>),
    ok;%rec(Socket);

%%取消升级
handle(cancel_upgrade, {PetId}, Socket) ->
    io:format("client send: cancel_upgrade Cmd=[41020], PetId=[~p] ~n", [PetId]),
    MsgLen = byte_size(<<1:16,41020:16,PetId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41020:16, PetId:32>>),
    ok;%rec(Socket);

 %%体力值同步
handle(strength_sync, {}, Socket) ->
    io:format("client send: strength_sync Cmd=[41015]~n", []),
    MsgLen = byte_size(<<1:16,41015:16>>),
    gen_tcp:send(Socket, <<MsgLen:16, 41015:16>>),
    ok;

handle(run, a, Socket) ->
    io:format("client send: run Cmd=[12001],X=[100], y=[200] ~n"),
    gen_tcp:send(Socket, <<8:16, 12001:16, 100:16, 200:16>>), 
    ok;%rec(Socket);

handle(Handle, Data, Socket) ->
    io:format("hadle error: ~p ~p~n", [Handle, Data]),
    {reply, handle_no_match, Socket}.



%%玩家列表
read(<<L:16, 10002:16, Num:16, Bin/binary>>) ->
    io:format("client read: ~p ~p ~p~n", [L, 10002, Num]),
    F = fun(Bin1) ->
        <<Id:32, S:16, C:16, Sex:16, Lv:16, Bin2/binary>> = Bin1,
        {Name, Rest} = read_string(Bin2),
        io:format("player list: Id=~p Status=~p Pro=~p Sex=~p Lv=~p Name=~p~n", [Id, S, C, Sex, Lv, Name]),
        Rest
    end,
    for(0, Num, F, Bin),
    io:format("player list end.~n");

read(<<L:16, Cmd:16>>) ->
    io:format("client read: ~p ~p~n", [L, Cmd]);
read(<<L:16, Cmd:16, Status:16>>) ->
    io:format("client read: ~p ~p ~p~n", [L, Cmd, Status]);
read(<<L:16, Cmd:16, Bin/binary>>) ->
    io:format("client read: ~p ~p ~p~n", [L, Cmd, Bin]);
%    case Cmd of
%        40002 ->
%            <<Status:16, Left/binary>> = Bin,
%            io:format("client read: ~p ~p ~p~n", [L, Cmd, Status]),
%            read(Left);
%        true -> io:format("client read: ~p ~p ~p~n", [L, Cmd, Bin])
%    end;
read(<<L:16, Cmd:16, Status:16, Bin/binary>>) ->
    io:format("client read: ~p ~p ~p ~p~n", [L, Cmd, Status, Bin]);
read(Bin) ->
    io:format("client rec: ~p~n", [Bin]).


rec(Socket) ->
    %%io:format("rec start...~n"),
    receive
        %%flash安全沙箱
        {tcp, Socket, <<"<cross-domain-policy><allow-access-from domain='*' to-ports='*' /></cross-domain-policy>">>} ->
             io:format("rec: ~p~n", ["flash_file"]);
        {tcp, Socket, Bin} ->
            io:format("rec: ~p~n", [Bin]),
            read(Bin);
        {tcp_closed, Socket} ->
            io:format("client recv error!~n");
        {handle, Cmd, Data} ->
            handle(Cmd, Data, Socket);
        {handle, Cmd} ->
            handle(Cmd, 0, Socket);
        close ->
            gen_tcp:close(Socket);
        Any ->
            io:format("client recv error=======================>: ~p~n",[Any])
%        after 15000 ->
%            io:format("circle send: heart 10006~n"),
%            gen_tcp:send(Socket, <<4:16, 10006:16>>),
%            rec(Socket)
    end,
    rec(Socket).

%rec(Socket) ->
%    % 收取头
%     case gen_tcp:recv(Socket, 4) of
%         {ok, <<Len:16, Cmd:16>>} ->
%             BodyLen = Len - 4,
%             io:format("\nrecv header, cmd=[~p], body len=[~p]\n", [Cmd, BodyLen]),
%             % 收取体
%             case gen_tcp:recv(Socket, BodyLen) of
%                 {ok, BodyData} ->
%                     io:format("recv body, data =[~p]\n", BodyData),
%                     rec(Socket);
%                 {error, Reason} -> io:format("recv body error, reason=[~p]\n", [Reason])
%             end;
%          {error, Reason}-> io:format("recv header error, reason=[~p]\n", [Reason])
%     end.

%%读取字符串
read_string(Bin) ->
    case Bin of
        <<Len:16, Bin1/binary>> ->
            case Bin1 of
                <<Str:Len/binary-unit:8, Rest/binary>> ->
                    {binary_to_list(Str), Rest};
                _R1 ->
                    {[],<<>>}
            end;
        _R1 ->
            {[],<<>>}
    end.

 sleep(T) ->
    receive
    after T -> ok
    end.
