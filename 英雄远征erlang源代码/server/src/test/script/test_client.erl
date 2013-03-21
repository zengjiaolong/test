%%%---------------------------------------------
%%% @Module  : test_client
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.11
%%% @Description: 客户端
%%%---------------------------------------------
-module(test_client).
-export([start/0, login/1]).

start() ->
    case gen_tcp:connect("localhost", 6666, [binary, {packet, 0}]) of
        {ok, Socket1} ->
            gen_tcp:send(Socket1, <<"<policy-file-request/>\0">>),
            rec(Socket1),
            gen_tcp:close(Socket1);
        {error, _Reason1} ->
            io:format("connect failed!~n")
	end,
    
    %%case gen_tcp:connect("121.10.141.249", 6666, [binary, {packet, 0}]) of
    case gen_tcp:connect("localhost", 6666, [binary, {packet, 0}]) of
		{ok, Socket} ->
			login(Socket),
            create(Socket),
            player_list(Socket),
            enter(Socket),
%            load_scene(Socket),
            load_player(Socket),
            get_npc(Socket),
            get_task(Socket),
%            attack_mon(Socket),
            ok;
		{error, _Reason} ->
            io:format("connect failed!~n")
	end.

%%登陆
login(Socket) ->
    L = byte_size( <<1:16,10000:16,2:32,1273027133:32,3:16,"htc",32:16,"b33d9ace076ca0ac7a8afa56923a03a4">>),
    gen_tcp:send(Socket, <<L:16,10000:16,2:32,1273027133:32,3:16,"htc",32:16,"b33d9ace076ca0ac7a8afa56923a03a4">>),
    rec(Socket).

%%创建角色
create(Socket) -> 
    L = byte_size( <<1:16,10003:16,1:16,1:16,6:16,"逍遥">>),
    gen_tcp:send(Socket, <<L:16,10003:16,1:16,1:16,6:16,"逍遥">>),
    %%gen_tcp:send(Socket, <<10003:16,3:16,"htc",1:16,1:16>>),
    rec(Socket).

%%玩家列表
player_list(Socket) ->
    gen_tcp:send(Socket, <<6:16,10002:16,1:16>>),
    rec(Socket).

%%选择角色进入
enter(Socket) ->
    gen_tcp:send(Socket, <<8:16,10004:16, 1:32>>),
    %gen_tcp:send(Socket, <<10004:16, 20:32>>),
    rec(Socket).

%%加载场景
%load_scene(Socket) ->
%    io:format("send:12002~n"),
%    gen_tcp:send(Socket, <<6:16,12002:16,1:16>>),
%    rec(Socket).

%%用户信息
load_player(Socket) ->
    gen_tcp:send(Socket, <<6:16,13001:16,1:16>>),
    rec(Socket).

%%获取对话
get_npc(Socket) ->
    io:format("send:32000~n"),
    gen_tcp:send(Socket, <<8:16,32000:16,10001:32>>),
    rec(Socket).

%%获取任务
get_task(Socket) ->
    io:format("send:30000~n"),
    gen_tcp:send(Socket, <<4:16,30000:16>>),
    rec(Socket).

%%人攻击怪
%attack_mon(Socket) ->
%    io:format("send:20001~n"),
%    gen_tcp:send(Socket, <<10:16,20001:16,1:32,1:16>>),
%    rec(Socket).

rec(Socket) ->
    receive
        {tcp, Socket, <<"<cross-domain-policy><allow-access-from domain='*' to-ports='*' /></cross-domain-policy>">>} -> 
            io:format("revc : ~p~n", ["flash_file"]);

        %%用户信息
        {tcp, Socket, <<_L:16,13001:16, Scene:32, X:16, Y:16, Id:32, Hp:32, Hp_lim:32, Mp:32, Mp_lim:32,Sex:16, Lv:16, Bin/binary>>} -> 
            {Nick, _} = read_string(Bin),
            io:format("revc player info:~p~n",[[Scene,X,Y,Id,Hp,Hp_lim,Mp,Mp_lim,Sex,Lv,Nick]]);

        %%场景
        {tcp, Socket, <<_L:16,12002:16, Bin/binary>>} -> 
            <<L:16, Bin22/binary>> = Bin,
            F = fun(Bin3) ->
                <<X1:16, Y1:16, Uid1:32, _X1:32, _X2:32, _X3:32, _X4:32, _X5:16, Bin4/binary>> = Bin3,
                {Nick1, Bin5} = read_string(Bin4),
                io:format("revc scene user online :~p~n",[[X1,Y1,Uid1,_X1,_X2,_X3,_X4,_X5,Nick1]]),
                Bin5
            end,
            Bin2 = for(0, L, F, Bin22),

            <<L2:16, Bin222/binary>> = Bin2,
            F2 = fun(Bin3) ->
                <<X1:16, Y1:16, Uid1:32, _X1:32, _X2:32, _X3:32, _X4:32, _X5:16, Bin4/binary>> = Bin3,
                {Nick1, Bin5} = read_string(Bin4),
                io:format("revc scene mon online :~p~n",[[X1,Y1,Uid1,_X1,_X2,_X3,_X4,_X5,Nick1]]),
                Bin5
            end,
            for(0, L2, F2, Bin222);

        {tcp, Socket, <<_L:16,Cmd:16, Bin:16>>} -> 
            io:format("revc : ~p~n", [[Cmd, Bin]]);

        %战斗获取NPC
        {tcp, Socket, <<_L:16, 32000:16, Bin/binary>>} ->
            io:format("rev 32000 : ~p~n", [Bin]);

        %任务
        {tcp, Socket, <<_L:16, 30000:16, Bin/binary>>} ->
            io:format("rev 30000 : ~p~n", [Bin]);

        %战斗结果
        {tcp, Socket, <<_L:16, _Cmd:16, Id:32, Hp:32, Mp:32,Id2:32, Hp2:32, Mp2:32,S1:32, S2:16>>} ->
            io:format("revc battle: ~p,~p,~p,~p,~p,~p,~p,~p~n", [Id, Id2, Hp, Hp2, Mp, Mp2, S1, S2]),
            rec(Socket);

         %复活
        {tcp, Socket, <<_L:16,Cmd:16, _X:16, _Y:16, Id:32, Hp:32, Mp:32, _Hp_lim:32, _Mp_lim:32, Lv:16, _Len:16, _Name1/binary>>} ->
            io:format("revc revive: ~p:~p~n", [Cmd, [Id, Hp, Mp, Lv]]);

        %%角色列表啊
        {tcp, Socket, <<_L:16,Cmd:16, Len:16, Bin/binary>>} -> 
            F = fun(Bin2) ->
                <<Id:32, S:16, C:16, Sex:16, Lv:16, L:16, Bin1/binary>> = Bin2,
                io:format("revc player list: ~p", [[Cmd, Id, S,C,Sex,Lv,L]]),
                <<Str:L/binary-unit:8, Rest/binary>> = Bin1,
                io:format("~p~n", [Str]),
                Rest
            end,
            for(0, Len, F, Bin);

        {tcp_closed, Socket} ->
            gen_tcp:close(Socket)
    end.

for(Max, Max, _F, X) ->
    X;
for(Min, Max, F, X) ->
    X1 = F(X),
    for(Min+1, Max, F, X1).

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
