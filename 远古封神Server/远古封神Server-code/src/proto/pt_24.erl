%%%------------------------------------
%%% @Module  : pt_24
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 组队协议
%%%------------------------------------

-module(pt_24).
-export([read/2, write/2]).
-include("common.hrl").
-include("record.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%%创建队伍
read(24000, <<Auto:8,Tyep:16>>) ->
%%     {TeamName, _} = pt:read_string(Bin),
    {ok, [Auto,Tyep]};

%%加入队伍
read(24002, <<Id:32,Type:16>>) ->
    {ok, [Id,Type]};

%%队长处理加入队伍请求
read(24004, <<Res:16, Id:32>>) ->
    {ok, [Res, Id]};

%%离开队伍
read(24005, _R) ->
    {ok, []};

%%邀请人加入队伍
read(24006, <<Id:32,Type:16>>) ->
    {ok, [Id,Type]};

%%被邀请人处理邀请进队信息
read(24008, <<Id:32, Res:16>>) ->
    {ok, [Id, Res]};

%%踢出队伍
read(24009, <<Id:32>>) ->
    {ok, Id};

%%询问队伍信息
read(24010, _R) ->
    {ok, []};

%%委任队长
read(24013, <<Id:32>>) ->
    {ok, Id};

%%更改队名
read(24014, <<Bin/binary>>) ->
    {TeamName, _} = pt:read_string(Bin),
    {ok, TeamName};

%%队伍资料
read(24016, <<Id:32>>) ->
    {ok, Id};

%% 获取场景队伍信息
read(24018, _R) ->
    {ok, []};

%% 可否传送进入副本或封神台
read(24031, <<Sid:32>>) ->
    {ok, Sid};

%%小黑板登记
read(24050, <<Cdn1:8, Cdn2:8, Cdn3:8, MinLv:8, MaxLv:8>>) ->
    {ok, [Cdn1, Cdn2, Cdn3, MinLv, MaxLv]};

%%小黑板查询
read(24051, _R) ->
    {ok, []};

%%修改队伍设置：可否自由组队
read(24052, <<T:8>>) ->
    {ok, T};

%%查询招募信息
read(24025,<<Type:16>>)->
	{ok,[Type]};

%%报名招募
read(24026,<<Type:16>>)->
	{ok,[Type]};

%%取消招募
read(24027,<<Type:16>>)->
	{ok,[Type]};

%%招募公告
read(24028,<<Type:16>>)->
	{ok,[Type]};

%%队员集合
read(24029,<<Type:16>>)->
	{ok,[Type]};

%%队员传送
read(24032,<<Type:16,P:32>>)->
	{ok,[Type,P]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%创建队伍
write(24000, [Res, TeamName, Auto]) ->
    TeamName1 = tool:to_binary(TeamName),
    L = byte_size(TeamName1),
    Data = <<Res:16, L:16, TeamName1/binary, Auto:8>>,  %%新创建的队伍，默认自动入队
    {ok, pt:pack(24000, Data)};

%%加入队伍
write(24002, Res) ->
    Data = <<Res:16>>,
    {ok, pt:pack(24002, Data)};

%%向队长发送加入队伍请求
write(24003, [Id, Lv, Career, Realm, Nick,Type]) ->
    Nick1 = tool:to_binary(Nick),
    L = byte_size(Nick1),
    Data = <<Id:32, Lv:16, Career:16, Realm:16, L:16, Nick1/binary,Type:16>>,
    {ok, pt:pack(24003, Data)};

%%队长处理加入队伍请求
write(24004, Res)->
    Data = <<Res:16>>,
    {ok, pt:pack(24004, Data)};

%%离开队伍
write(24005, Res)->
    Data = <<Res:16>>,
    {ok, pt:pack(24005, Data)};

%%邀请加入队伍
write(24006, Res)->
    Data = <<Res:16>>,
%% io:format("24006__~p~n",[Res]),	
    {ok, pt:pack(24006, Data)};

%%向被邀请人发出邀请
write(24007, [Id, Nick, Lv, TeamName,Type]) ->
    Nick1 = tool:to_binary(Nick),
    NL = byte_size(Nick1),
    TeamName1 = tool:to_binary(TeamName),
    TNL = byte_size(TeamName1),
    Data = <<Id:32, NL:16, Nick1/binary, Lv:8, TNL:16, TeamName1/binary,Type:16>>,
    {ok, pt:pack(24007, Data)};

%%邀请人邀请进队伍
write(24008, Res) ->
    Data = <<Res:16>>,
    {ok, pt:pack(24008, Data)};

%%踢出队员
write(24009, Res) ->
    Data = <<Res:16>>,
    {ok, pt:pack(24009, Data)};

%% 向队员发送队伍信息
%% [{1,2,60000},2,1,60000}],
%% [[{2,60000}],[{1,60000}]]
write(24010, [TeamId, TeamName,Type, Member]) ->
    NewTeamName = tool:to_binary(TeamName),
    TL = byte_size(NewTeamName),
    N = length(Member),
    F = fun([Id, Lv, Career, Realm, Nick, Sta, Hp, HpLim, Mp, MpLim, Sex, Closes]) ->
				
  		NewNick = tool:to_binary(Nick),
      	Len = byte_size(NewNick),
        LenC = length(Closes),
		C = lists:map(fun({Oid,Close}) -> <<Oid:32,Close:32>> end, Closes),
        CB = tool:to_binary(C),
  		<<Id:32, Lv:16, Career:16, Realm:8, Len:16, NewNick/binary, Sta:8, 
		  		Hp:32, HpLim:32, Mp:32, MpLim:32, Sex:8, LenC:16, CB/binary>>
    end,
    LN = tool:to_binary([F(X) || X <- Member]),
    Data = <<TeamId:32, TL:16, NewTeamName/binary,Type:16, N:16, LN/binary>>,
    {ok, pt:pack(24010, Data)};

%%向队员发送有人离队的信息
write(24011, Id) ->
    Data = <<Id:32>>,
    {ok, pt:pack(24011, Data)};

%%向队员发送更换队长的信息
write(24012, [Id, Auto]) ->
    Data = <<Id:32, Auto:8>>,
    {ok, pt:pack(24012, Data)};

%%委任队长
write(24013, Res) ->
    Data = <<Res:16>>,
    {ok, pt:pack(24013, Data)};

%%更改队名
write(24014, Res) ->
    Data = <<Res:16>>,
    {ok, pt:pack(24014, Data)};

%%通知队员队名更改了
write(24015, TeamName) ->
    TeamName1 = tool:to_binary(TeamName),
    L = byte_size(TeamName1),
    Data = <<L:16, TeamName1/binary>>,
    {ok, pt:pack(24015, Data)};

%%队伍资料
write(24016, [Id, MbNum, Nick, TeamName, Auto]) ->
    Nick1 = tool:to_binary(Nick),
    NL = byte_size(Nick1),
    TeamName1 = tool:to_binary(TeamName),
    TNL = byte_size(TeamName1),
    Data = <<Id:32, MbNum:16, NL:16, Nick1/binary, TNL:16, TeamName1/binary, Auto:8>>,
    {ok, pt:pack(24016, Data)};

%%通知队员队伍解散
write(24017, []) ->
    {ok, pt:pack(24017, <<>>)};

%% 场景队伍信息
write(24018, []) ->
    NL = 0,
    Data = <<NL:16>>,
    {ok, pt:pack(24018, Data)};
write(24018, Data) ->
    NL = length(Data),
    F = fun([Id, Nick, Lv, Career, Realm, Num, Auto]) ->
            Nick1 = tool:to_binary(Nick),
            Len = byte_size(Nick1),
            <<Id:32, Len:16, Nick1/binary, Lv:16, Career:16, Realm:16, Num:16, Auto:8>>
    end,
    Data1 = tool:to_binary([F(X)||X <- Data]),
    Data2 = <<NL:16, Data1/binary>>,
    {ok, pt:pack(24018, Data2)};

%% 向队员发送投骰子信息
write(24020, [UserName, MaxNum, GoodsTypeId, TeamRandDropInfo]) ->
    NewUserName = tool:to_binary(UserName),
    UL = byte_size(NewUserName),
    N = length(TeamRandDropInfo),
    F = fun([Num, _Pid, _Id, Name, _Realm, _Career, _Sex, _GoodsPid]) ->
  		NewName = tool:to_binary(Name),
  		L = byte_size(NewName),
  		<<L:16, NewName/binary, Num:8>>
    end,
    LN = tool:to_binary([F(T) || T <- TeamRandDropInfo]),
    Data = <<UL:16, NewUserName/binary, MaxNum:8, GoodsTypeId:32, N:16, LN/binary>>,
    {ok, pt:pack(24020, Data)};

%% 更新队员信息
write(24021, [Id, Sta, Lv, Hp, HpLim, Mp, MpLim]) ->
    Data = <<Id:32, Sta:8, Lv:16, Hp:32, HpLim:32, Mp:32, MpLim:32>>,
    {ok, pt:pack(24021, Data)};

%% 更新队员场景位置信息
write(24022, [PlayerId, X, Y, SceneId]) ->
    Data = <<PlayerId:32, X:16, Y:16, SceneId:32>>,
    {ok, pt:pack(24022, Data)};

%%队员下线
write(24023, [Type, PlayerId]) ->
    Data = <<Type:8, PlayerId:32>>,
    {ok, pt:pack(24023, Data)};

%%即时更新亲密度到队伍头像
write(24024,[Closes])->
	Len = length(Closes),
	F = fun({PlayerId,Close}) ->
				<<PlayerId:32,Close:32>>
		end,
	C = tool:to_binary([F(T) || T <- Closes]),
	Data = <<Len:16,C/binary>>,
	{ok, pt:pack(24024,Data)};

%%发送给队伍进入副本或封神台信息
write(24030, Sid) ->
%% ?DEBUG("24030__111_~p/",[Sid]),
    {ok, pt:pack(24030, <<Sid:32>>)};

%%可否传送进入副本或封神台
write(24031, [Sid, Res]) ->
    {ok, pt:pack(24031, <<Sid:32, Res:8>>)};

%%小黑板登记信息
write(24050, Res) ->
%% ?DEBUG("24050_000000000000: [~p]", [Res]),
    {ok, pt:pack(24050, <<Res:8>>)};

%%小黑板查询
write(24051, []) ->
    NL = 0,
    Data = <<NL:16>>,
    {ok, pt:pack(24051, Data)};
write(24051, L) ->
%% ?DEBUG("35002_return_L_~p ~n",[L]),
	L2 = lists:delete([],L),
%% ?DEBUG("35002_return_L2_~p ~n",[L2]),
    N = length(L2),
%% ?DEBUG("35002_return_N_~p ~n",[N]),
	Data = 
		try
    		F = fun(BBM) ->
						Id = BBM#ets_blackboard.id,
						Nick1 = tool:to_binary(BBM#ets_blackboard.nickname),
						NL = byte_size(Nick1),
						Leader = BBM#ets_blackboard.id,
						Cdn1 = BBM#ets_blackboard.condition_1,
						Cdn2 = BBM#ets_blackboard.condition_2,
						Cdn3 = BBM#ets_blackboard.condition_3,
						Min_lv = BBM#ets_blackboard.min_lv,
						Max_lv = BBM#ets_blackboard.max_lv,
						Career = BBM#ets_blackboard.career,
						Lv = BBM#ets_blackboard.lv,
						Sex = BBM#ets_blackboard.sex,
            	<<Id:32, NL:16, Nick1/binary, Leader:8, Cdn1:8, Cdn2:8, Cdn3:8, Min_lv:8, Max_lv:8, Career:8, Lv:8, Sex:8>>
    			end,
    		LB = tool:to_binary([F(X) || X <- L2, X /= []]),
			<<N:16, LB/binary>>
		catch
			_:_ -> 
				?WARNING_MSG("35002 List[~p],List2[~p],Num[~p]", [L, L2, N]),
				<<0:16, <<>>/binary>>
		end,	
    {ok, pt:pack(24051, Data)};

%%自动入队修改
write(24052, [Res, T]) ->
    {ok, pt:pack(24052, <<Res:8, T:8>>)};

%%查询招募信息
%% array(
%% 		string 队长名字
%% 		int16 等级
%% 		int8 队伍人数
%% 		int8是否允许自动加入
%% 		int32 创建时间
%% 	)
%% 	报名玩家信息
%% 	array(
%% 		string 玩家名字
%% 		int16 等级
%% 		int16 职业
%% 	)
write(24025,[Type,Team,Member])->
	TLen= length(Team),
	TeamBin = tool:to_binary(pack_raise_team(Team,[])),
	MLen = length(Member),
	MemBin = tool:to_binary(pack_raise_member(Member,[])),
	{ok,pt:pack(24025,<<Type:16,TLen:16,TeamBin/binary,MLen:16,MemBin/binary>>)};

%%报名招募
write(24026,[Type,Res])->
	{ok,pt:pack(24026,<<Type:16,Res:16>>)};

%%取消报名招募
write(24027,[Type,Res])->
	{ok,pt:pack(24027,<<Type:16,Res:16>>)};

%%招募公告
write(24028,[Res])->
	{ok,pt:pack(24028,<<Res:16>>)};

%%通知队伍集合
write(24029,[Type,PType,NpcId,NickName])->
	Name = tool:to_binary(NickName),
	Len = byte_size(Name),
	{ok,pt:pack(24029,<<Type:16,PType:16,NpcId:32,Len:16,Name/binary>>)};

write(24032,[Res])->
	{ok,pt:pack(24032,<<Res:16>>)};

write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.


pack_raise_team([],TeamBag)->TeamBag;
pack_raise_team([T|Team],TeamBag)->
	Pid = T#raise_team.player_id,
	Name = tool:to_binary(T#raise_team.nickname),
	Len = byte_size(Name),
	Lv = T#raise_team.lv,
	Nums = T#raise_team.nums,
	Auto = T#raise_team.auto,
	Timestamp = T#raise_team.timestamp,
	Bin = <<Pid:32,Len:16,Name/binary,Lv:16,Nums:8,Auto:8,Timestamp:32>>,
	pack_raise_team(Team,[Bin|TeamBag]).

pack_raise_member([],MemBag)->MemBag;
pack_raise_member([M|Member],MemBag)->
	Pid = M#raise_member.pid,
	Name = tool:to_binary(M#raise_member.nickname),
	Len = byte_size(Name),
	Lv = M#raise_member.lv,
	Career= M#raise_member.career,
	Bin = <<Pid:32,Len:16,Name/binary,Lv:16,Career:16>>,
	pack_raise_member(Member,[Bin|MemBag]).
