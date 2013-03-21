%%%-----------------------------------
%%% @Module  : pt_10
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 10帐户信息
%%%-----------------------------------
-module(pt_10).
-export([read/2, write/2]).
-include("common.hrl").
%%
%%客户端 -> 服务端 ----------------------------
%%

%%登陆
read(10000, <<Sn:16, Accid:32, Tstamp:32, Bin/binary>>) ->
    {Accname, Bin1} = pt:read_string(Bin),
    {Ticket, _} = pt:read_string(Bin1),
%% io:format("~s/~p_read: ~p~n",[?MODULE, misc:time_format(yg_timer:now()), {Accid, Accname, Tstamp, Ticket}]),	
    {ok, login, [Sn, Accid, Accname, Tstamp, Ticket]};

%%退出
read(10001, _) ->  
    {ok, logout};

%%读取列表
read(10002, _R) ->
    {ok, lists, []};

%%创建角色
read(10003, <<Sn:16, Realm:8, Career:8, Sex:8, Bin/binary>>) ->
    {Name1, _} = pt:read_string(Bin),
    {ok, create, [Sn, Realm, Career, Sex, Name1]};

%%选择角色进入游戏
read(10004, <<Sn:16, Id:32>>) ->
    {ok, enter, [Sn, Id]};

%%删除角色
read(10005, <<Id:32>>) ->
    {ok, delete, Id};

%%心跳包
read(10006, <<Time:32>>) ->
    {ok, [heartbeat,Time]};

%%多socket连接
read(10008,<<Sn:16,Accid:32,N:8>>) ->
	{ok,mult_socket,[Sn,Accid,N]};

%% 按照accid创建一个角色，或自动分配一个角色(accid=0)
read(10010, <<Sn:16, Accid:32>>) ->
    {ok, new_role, [Sn, Accid]};

%%进入角色创建页面
read(10020, _) ->
    {ok, getin_createpage};

%%子socket心跳包
read(10030, <<SocketN:8>>) ->
    {ok, [heartbeat,SocketN]};

%%子socekt断开通知
read(10031,<<N:8>>) ->
	{ok,[child_socket_break,N]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%网关登陆
write(9999, [Host, Port]) ->
    HL = byte_size(Host),
    Data = <<HL:16, 
			 Host/binary, 
			 Port:16>>,
    {ok, pt:pack(9999, Data)};

%%登陆返回
write(10000, [Code, L]) ->
	case L of
		[] ->
    		N = 0,
    		LB = <<>>;			
		_ ->	
    		N = length(L),
    		F = fun([Pid, Status, Name, Sex, Lv, Realm, Career]) ->
            	NL = byte_size(Name),
            	<<Pid:32, 
			  	Status:16, 
			  	Realm:16,
			  	Career:16, 
			  	Sex:16, 
			  	Lv:16, 
			  	NL:16, 
			  	Name/binary>>
    		end,
    		LB = tool:to_binary([F(X) || X <- L])
	end,
	Now = util:unixtime(),
    Data = <<Code:16, Now:32,N:16, LB/binary>>,
    {ok, pt:pack(10000, Data)};

%%登陆退出
write(10001, _) ->
    Data = <<>>,
    {ok, pt:pack(10001, Data)};

%% 打包角色列表
write(10002, []) ->
    N = 0,
    LB = <<>>,
    {ok, pt:pack(10002, <<N:16, LB/binary>>)};
write(10002, L) ->
    N = length(L),
    F = fun([Pid, Status, Name, Sex, Lv, Realm, Career]) ->
            NL = byte_size(Name),
            <<Pid:32, 
			  Status:16, 
			  Realm:16,
			  Career:16, 
			  Sex:16, 
			  Lv:16, 
			  NL:16, 
			  Name/binary>>
    end,
    LB = tool:to_binary([F(X) || X <- L]),
    {ok, pt:pack(10002, <<N:16, LB/binary>>)};

%%创建角色
write(10003, [Code, RoleId]) ->
%% io:format("write_10003_/~p/_~n",[Code]),	
    Data = <<Code:16, RoleId:32>>,
    {ok,  pt:pack(10003, Data)};

%%选择角色进入游戏
write(10004, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(10004, Data)};

%%删除角色
write(10005, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(10005, Data)};

%%心跳包
write(10006, _) ->
    Data = <<>>,
    {ok, pt:pack(10006, Data)};

%%被下线通知
write(10007, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(10007, Data)};

%%子socket建立状态
write(10008,[Code,N]) ->
	Data = <<Code:16,N:8>>,
	{ok,pt:pack(10008,Data)};

%%登陆过程监测
write(10009,[N])->
	Data = <<N:16>>,
	{ok,pt:pack(10009,Data)}; 

%% 返回：按照accid创建一个角色，或自动分配一个角色(accid=0)
write(10010, [NewAccid, RoleId, Accname]) ->
    Accname1 = tool:to_binary(Accname),
    NLen = byte_size(Accname1),	
    Data = <<NewAccid:32,
			 RoleId:32,
			 NLen:16, 
			 Accname1/binary>>,	
    {ok, pt:pack(10010, Data)};

%%子socket心跳包
write(10030, _) ->
    Data = <<>>,
    {ok, pt:pack(10030, Data)};


%%推送系统时间
write(10032,[Unixtime]) ->
	Data = <<Unixtime:32>>,
	{ok,pt:pack(10032,Data)};

%%防沉迷信息
write(10040 ,Code) ->
	Data = <<Code:8>>,
	{ok,pt:pack(10040,Data)};

write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.