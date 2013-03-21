%%%--------------------------------------
%%% @Module  : pt_14
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description:  14玩家间关系信息
%%%--------------------------------------
-module(pt_14).
-export([read/2, write/2]).
-include("common.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%%请求好友列表
read(14000, _R) ->
    {ok, []};

%%添加好友请求
read(14001,<<Type:16, Id:32, Bin/binary>>) ->
    {Nick, _} = pt:read_string(Bin),
    {ok, [Type, Id, Nick]};

%%回应添加好友请求
read(14002,<<Type:16, Res:16, Id:32>>) ->
    {ok,[Type, Res, Id]};

%%删除好友
read(14003, <<Id:32>>) ->
    {ok, Id};

%%添加黑名单
read(14004, <<Id:32>>) ->
    {ok, Id};

%%添加仇人
read(14005, <<Id:32>>) ->
    {ok, Id};

%%改变好友分组名字
read(14006, <<N:16, Bin/binary>>) ->
    {Gname, _} = pt:read_string(Bin),
    {ok, [N, Gname]};

%%请求黑名单列表
read(14007, _R) ->
    {ok, []};

%%请求仇人列表
read(14008, _R) ->
    {ok, []};

%%移动好友到别的分组
read(14009, <<Uid:32, N:16>>) ->
    {ok, [Uid, N]};

%%查找角色
read(14010, <<Bin/binary>>) ->
    {Nick, _} = pt:read_string(Bin),
    {ok, Nick};

%%设置自动回复
%read(14012, <<AutoRes:16, Bin/binary>>) ->
%    {Msg, _} = pt:read_string(Bin),
%    {ok, [AutoRes, Msg]};

%%查询陌生人资料
read(14013, <<Id:32>>) ->
    {ok, Id};

%%删除黑名单
read(14020, <<Id:32>>) ->
    {ok, Id};

%%删除仇人
read(14021, <<Id:32>>) ->
    {ok, Id};

%%发送好友祝福
read(14051,  <<Uid:32, Ulv:8, Type:8>>) ->
    {ok, [Uid, Ulv, Type]};

%%祝福瓶
read(14055, _R) ->
    {ok, []};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%打包好友信息
write(14000, [[]]) ->
    N = 0,
    LB = <<>>,
    Data = <<N:16, LB/binary>>,
    {ok, pt:pack(14000, Data)};
%% write(14000, [GL,[]]) ->
%%     GLen = length(GL),
%%     F1 = fun(GroupName) ->
%% 			GroupName1 = tool:to_binary(GroupName),
%%             GNL = byte_size(GroupName1),
%%             <<GNL:16, GroupName1/binary>>
%%     end,
%%     LA = tool:to_binary([F1(X) || X <- GL]),
%%     N = 0,
%%     LB = <<>>,
%%     Data = <<GLen:16, LA/binary ,N:16, LB/binary>>,
%%     {ok, pt:pack(14000, Data)};
write(14000,[L]) ->
	L2 = lists:delete([],L),
    N = length(L2),
	Data = 
	try
    	F = fun([Online, IdB, Lv, Sex, Career, Nick, Id, Close, Vip]) ->
			Nick1 = tool:to_binary(Nick),	
            NL = byte_size(Nick1),
            <<Online:16, IdB:32, Lv:16, Sex:16, Career:16, 
			  NL:16, Nick1/binary, Id:32, Close:32, Vip:8>>
    	end,
    	LB = tool:to_binary([F(X) || X <- L2, X /= []]),
		<<N:16, LB/binary>>
	catch
		_:_ -> 
			?WARNING_MSG("14000 List[~p],List2[~p],Num[~p]", [L, L2, N]),
			<<0:16, <<>>/binary>>
	end,
    {ok, pt:pack(14000, Data)};

%%添加好友请求
write(14001, [Type, Id, Lv, _Sex, Career, Nick]) ->
    Nick1 = tool:to_binary(Nick),
    Len = byte_size(Nick1),
    Data = <<Type:16, Id:32, Lv:16, Career:16, Len:16, Nick1/binary>>,
    {ok, pt:pack(14001, Data)};

%%回应者不在线/不存在此用户名/发送者被加黑名单
write(14002, [Recer, Res]) ->
    Nick1 = <<>>,
    Data = <<Recer:8, Res:8, 0:32, 0:8, 0:8, 0:16, Nick1/binary>>,
    {ok, pt:pack(14002, Data)};
%%回应添加好友请求
write(14002, [Recer, Res, Id, Lv, _Sex, Career, Nick]) ->
	Nick1 = tool:to_binary(Nick),
    Len = byte_size(Nick1),
    Data = <<Recer:8, Res:8, Id:32, Lv:8, Career:8, Len:16, Nick1/binary>>,
    {ok, pt:pack(14002, Data)};

%删除好友
write(14003, N) ->
    Data = <<N:16>>,
    {ok, pt:pack(14003, Data)};

%%添加黑名单
write(14004, [Res, Id]) ->
    Data = <<Res:16, Id:32>>,
    {ok, pt:pack(14004,Data)};

%%添加仇人
write(14005, [Res, Id]) ->
    Data = <<Res:16, Id:32>>,
    {ok, pt:pack(14005, Data)};

%%改变好友分组名字
write(14006, Res) ->
    Data = <<Res:16>>,
    {ok, pt:pack(14006, Data)};

%%请求黑名单列表
write(14007, L) ->
	L2 = lists:delete([],L),
    N = length(L2),
	Data =
	try
    	F = fun([IdB, Lv, Sex, Career, Nick, Rid, Vip]) ->
			Nick1 = tool:to_binary(Nick),
            NL = byte_size(Nick1),
            <<IdB:32, Lv:16, Sex:16, Career:16, NL:16, Nick1/binary, Rid:32, Vip:8>>
    	end,
    	LB = tool:to_binary([F(X) || X <- L2]),
		<<N:16, LB/binary>>
	catch
		_:_ -> 
			?WARNING_MSG("14007 List[~p],List2[~p],Num[~p]", [L, L2, N]),
			<<0:16, <<>>/binary>>
	end,
    {ok, pt:pack(14007, Data)};

%%请求仇人列表
write(14008, L) ->
	L2 = lists:delete([], L),
    N = length(L2),
	Data =
	try
    	F = fun([Online, IdB, Lv, Sex, Career, Nick, Rid, Vip]) ->
			Nick1 = tool:to_binary(Nick),
            NL = byte_size(Nick1),
            <<Online:16, IdB:32, Lv:16, Sex:16, Career:16, NL:16, Nick1/binary, Rid:32, Vip:8>>
    	end,
    	LB = tool:to_binary([F(X) || X <- L2]),
    	<<N:16, LB/binary>>
	catch
		_:_ -> 
			?WARNING_MSG("14007 List[~p],List2[~p],Num[~p]", [L, L2, N]),
			<<0:16, <<>>/binary>>
	end,
    {ok, pt:pack(14008, Data)};

%%移动好友到别的分组
write(14009, N) ->
    Data = <<N:16>>,
    {ok, pt:pack(14009, Data)};

%%查找角色
write(14010, []) ->
    GuildName = <<>>,
    Nick = <<>>,
    Data = <<0:16, 0:32, 0:16, 0:16, 0:16, 0:16, GuildName/binary, 0:16, Nick/binary, 0:8>>,
    {ok, pt:pack(14010, Data)};
write(14010, [1, Id, Lv, Sex, Career, GuildName, Nick, Realm]) ->
    GuildName1 = tool:to_binary(GuildName),
    Nick1 = tool:to_binary(Nick),
    L1 = byte_size(GuildName1),
    L2 = byte_size(Nick1),
    Data = <<1:16, Id:32, Lv:16, Sex:16, Career:16, L1:16, GuildName1/binary, L2:16, Nick1/binary, Realm:8>>,
    {ok, pt:pack(14010, Data)};

%%发送自动回复设置
%write(14011, [AutoRes, Msg]) ->
%    L = byte_size(Msg),
%    Data = <<AutoRes:16, L:16, Msg/binary>>,
%    {ok, pt:pack(14011, Data)};

%%设置自动回复设置
%write(14012, Res) ->
%    Data = <<Res:16>>,
%    {ok, pt:pack(14011, Data)};

%%查询陌生人资料
write(14013, [Id, Lv, Sex, Career, Nick, Vip]) ->
    Nick1 = tool:to_binary(Nick),
    L = byte_size(Nick1),
    Data = <<Id:32, Lv:16, Sex:16, Career:16, L:16, Nick1/binary, Vip:8>>,
    {ok, pt:pack(14013, Data)};

%%删除黑名单
write(14020, N) ->
    Data = <<N:16>>,
    {ok, pt:pack(14020, Data)};

%%删除仇人
write(14021, N) ->
    Data = <<N:16>>,
    {ok, pt:pack(14021, Data)};

%%好友上下线通知
write(14030, [Uid, Line, Nick]) ->
    Nick1 = tool:to_binary(Nick),
    L = byte_size(Nick1),
    Data = <<Uid:32, Line:8, L:16, Nick1/binary>>,
    {ok, pt:pack(14030, Data)};

%%仇人上下线通知
write(14031, [Uid, Line, Nick]) ->
    Nick1 = tool:to_binary(Nick),
    L = byte_size(Nick1),
    Data = <<Uid:32, Line:8, L:16, Nick1/binary>>,
    {ok, pt:pack(14031, Data)};

%%好友祝福通知
write(14050, [Uid, Nick, Lv, Exp, B_times]) ->
    Nick1 = tool:to_binary(Nick),
    L = byte_size(Nick1),
    Data = <<Uid:32, L:16, Nick1/binary, Lv:8, Exp:32, B_times:8>>,
    {ok, pt:pack(14050, Data)};

%%发送好友祝福
write(14051, [Res, Lf_time, Fid, Flv]) ->
    Data = <<Res:8, Lf_time:8, Fid:32, Flv:8>>,
    {ok, pt:pack(14051, Data)};

%%接收祝福通知
write(14052, [Uid, Nick, Flv, Lv, Type, Exp]) ->
    Nick1 = tool:to_binary(Nick),
    L = byte_size(Nick1),
    Data = <<Uid:32, L:16, Nick1/binary, Flv:8, Lv:8, Type:8, Exp:32>>,
    {ok, pt:pack(14052, Data)};

%%祝福瓶信息
%% write(14053, [Can_get, Result, B_exp, B_spr, Exp_inc, Spr_inc]) ->
%% 	Data = <<Can_get:8, Result:8, B_exp:32, B_spr:32, Exp_inc:32, Spr_inc:32>>,
%%     {ok, pt:pack(14053, Data)};

%%20次之后祝福别人
write(14053, Exp) ->
    Data = <<Exp:32>>,
    {ok, pt:pack(14053, Data)};

%%祝福瓶经验
write(14054, Exp) ->
    Data = <<Exp:32>>,
    {ok, pt:pack(14054, Data)};

%%领取经验
write(14055, Res) ->
    Data = <<Res:8>>,
    {ok, pt:pack(14055, Data)};

write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.
