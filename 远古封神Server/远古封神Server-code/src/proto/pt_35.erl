%%%-----------------------------------
%%% @Module  : pt_35
%%% @Author  : lzz
%%% @Created : 2010.11.29
%%% @Description: 封神台 &&封神纪元
%%%-----------------------------------
-module(pt_35).
-export([read/2, write/2]).

-include("common.hrl").
-include("record.hrl").


%%
%%客户端 -> 服务端 ----------------------------
%%
%%进入封神台
read(35000, _) ->
    {ok, enter};

%%退出封神台
read(35001, _) ->
    {ok, quit};

%%封神台霸主
read(35002, _) ->
    {ok, get_gods};

%%封神台跳层
read(35003, <<Loc:16>>) ->
%% ?DEBUG("35003_get_~p ~n",[Loc]),
    {ok, [Loc]};

%% 封神纪元tooltip
read(35010,<<PlayerId:32>>) ->
	{ok,[PlayerId]};

%% 封神纪元通关信息
read(35011,<<PlayerId:32,Stage:8>>) ->
	{ok,[PlayerId,Stage]};

%% 封神纪元通关奖励领取
read(35014,<<Stage:8,Level:8>>) ->
	{ok,[Stage,Level]};

read(_Cmd, _R) ->
	?DEBUG("_Cmd:~p:~p~n",[_Cmd,_R]),
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%


%%封神台累积奖励
write(35000, [Loc, Hor, Exp, Spr]) ->
%% ?DEBUG("35000_return_~p/~p/~p/~p ~n",[Loc, Hor, Exp, Spr]),	
    {ok, pt:pack(35000, <<Loc:8, Hor:16, Exp:32, Spr:32>>)};
    

%%退出封神台
write(35001,[Res])->
	{ok,pt:pack(35001,<<Res:8>>)};

%%封神台霸主信息
write(35002, L) ->
%% ?DEBUG("35002_return_L_~p ~n",[L]),
	L2 = lists:delete([],L),
%% ?DEBUG("35002_return_L2_~p ~n",[L2]),
    N = length(L2),
%% ?DEBUG("35002_return_N_~p ~n",[N]),
	Data = 
		try
    		F = fun([_Id, _RT, Lv, Realm, Career, Sex, Light, Nickname, Guild_name]) ->
				Nick1 = tool:to_binary(Nickname),	
            	NL = byte_size(Nick1),
				Guild1 = tool:to_binary(Guild_name),	
            	GL = byte_size(Guild1),				
            	<<Lv:16, Realm:8, Career:8, Sex:8, Light:8, NL:16, Nick1/binary, GL:16, Guild1/binary>>
    			end,
    		LB = tool:to_binary([F(X) || X <- L2, X /= []]),
			<<N:16, LB/binary>>
		catch
			_:_ -> 
				?WARNING_MSG("35002 List[~p],List2[~p],Num[~p]", [L, L2, N]),
				<<0:16, <<>>/binary>>
		end,
%% ?DEBUG("35002_return_Data_~p ~n",[Data]),
    {ok, pt:pack(35002, Data)};
   
%%封神台跳层
write(35003, [Res, Gold]) ->
%% ?DEBUG("35003_return_~p/~p ~n",[Res, Gold]),		
    {ok, pt:pack(35003, <<Res:8, Gold:32>>)};

%%封神塔时钟
write(35004, [LeftT, UsedT]) ->
%% ?DEBUG("35004_return_~p//~p ~n",[LeftT, UsedT]),	
    {ok, pt:pack(35004, <<LeftT:32, UsedT:32>>)};

%%封神塔荣誉刷新
write(35005, Hor) ->
%% ?DEBUG("35005_return_~p ~n",[Hor]),		
    {ok, pt:pack(35005, <<Hor:32>>)};

%%封神纪元tooltip
write(35010,[PlayerId,Stage,Lv,Attack,Hp,Mp,Def,AntiAll]) ->
	{ok,pt:pack(35010, <<PlayerId:32,Stage:8,Lv:8,Attack:32,Hp:32,Mp:32,Def:32,AntiAll:32>>)};

%%封神纪元通关信息
write(35011,[PlayerId,Stage,MaxStage,BV,PetBV,MountBV,TimeLimit,RBV,RpetBV,RmountBV,MaxLv,PassTime,Toper,TopTime,
			 PrizeInfo,
			 StagePrizeInfo,AttributeInfo]) ->
		[Cp,Bp,Ap,Sp,SSp,SSSp] = PrizeInfo,
		[Attack,Hp,Mp,Def,AntiAll] = AttributeInfo,
		F = fun([Plv,Pexp,Pspi,Pcul,Pbcoin,PgoodsType,PgoodsNum]) ->
			<<Plv:8,Pexp:32,Pspi:32,Pcul:32,Pbcoin:32,PgoodsType:32,PgoodsNum:16>>
		end,
		StagePrizeLen = length(StagePrizeInfo),
		StagePrizeBin = tool:to_binary([F(D) || D <- StagePrizeInfo]),
		ToperBin = tool:to_binary(Toper),
		ToperByte = byte_size(ToperBin),
		{ok,pt:pack(35011, <<PlayerId:32,Stage:8,MaxStage:8,BV:32,PetBV:32,MountBV:32,TimeLimit:16,RBV:32,RpetBV:32,RmountBV:32,MaxLv:8,PassTime:32,
							ToperByte:16,ToperBin/binary,TopTime:32,
							 Cp:8,Bp:8,Ap:8,Sp:8,SSp:8,SSSp:8,
							 StagePrizeLen:16,StagePrizeBin/binary ,
							 Attack:32,Hp:32,Mp:32,Def:32,AntiAll:32>>)};
%%封神纪元通关剩余时间
write(35012,[Time]) ->
	{ok,pt:pack(35012, <<Time:32>>)};

%% 封神纪元通关结果显示
write(35013,[Stage,Time,TimeAdd,HpHurt,HpAdd,Total,Level]) ->
	{ok,pt:pack(35013, <<Stage:8,Time:32,TimeAdd:32,HpHurt:32,HpAdd:32,Total:32,Level:8>>)};

%% 封神纪元通关奖励领取
write(35014,[Stage,Levl,Code]) ->
	{ok,pt:pack(35014, <<Stage:8,Levl:8,Code:16>>)};

%% 封神纪元连斩数
write(35015,[Num]) ->
	{ok,pt:pack(35015, <<Num:32>>)};

%%剧情对话
write(35016,[Stage,State]) ->
	{ok,pt:pack(35016, <<Stage:8,State:8>>)};

%% 封神纪元风向
write(35017,[Dct]) ->
	{ok,pt:pack(35017,<<Dct:8>>)};
%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

