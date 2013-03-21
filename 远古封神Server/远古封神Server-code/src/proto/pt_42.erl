%%%-----------------------------------
%%% @Module  : pt_42
%%% @Author  : ZKJ
%%% @Created : 2011.4.15
%%% @Description: 神之庄园
%%%-----------------------------------
-module(pt_42).
-export([read/2,write/2]).
-include("common.hrl").
-include("record.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%是否准许进入
read(42000,<<MasterId:32,Type:8>>) ->
	{ok,[MasterId,Type]};

%%时间同步
read(42001,_r) ->
    {ok,[_r]};

%%取场景信息
read(42010,_r) ->
    {ok,[_r]};

%%取土地信息
read(42011,<<Farm_Id:8>>) ->
    {ok,Farm_Id};

%%查看种子信息
read(42012,_r) ->
    {ok,[_r]};

%%查看加速器信息
read(42013,_r) ->
    {ok,[_r]};

%%取好友，黑名单，仇家列表
read(42014,_r) ->
    {ok,[_r]};

%%获取今日可偷次数
read(42015,_r) ->
    {ok,[_r]};

%%获取LOG
read(42016,_r) ->
    {ok,[_r]};

%%获取本人庄园是否有东西成熟
read(42017,_r) ->
    {ok,[_r]};

%%播种
read(42020,<<Farm_Id:8, Seed_Id:32>>) ->
    {ok,[Farm_Id, Seed_Id]};

%%收获（偷菜）
read(42021, <<Farm_Id:8>>) ->
    {ok,Farm_Id};

%%一键收获（偷菜）
read(42022,_r) ->
    {ok,[_r]};

%%使用加速器
read(42023,<<Farm_Id:8>>) ->
    {ok,Farm_Id};

%%土地开垦
read(42024, <<Farm_Id:8>>) ->
    {ok,Farm_Id};

%%退出
read(42025,_r) ->
    {ok,[_r]};

%%卖出
read(42031,<<Len:16, Bin/binary>>) ->
	F = fun(_, [Bin1,L]) ->
        <<GoodsId:32, GoodsNum:32, Rest/binary>> = Bin1,
        L1 = [{GoodsId,GoodsNum}|L],
        [Rest, L1]
    end,
    [_, GoodsInfoList] = lists:foldl(F, [Bin,[]], lists:seq(1, Len)),
	{ok,[GoodsInfoList]};

%%取氏族好友
read(42114,_r) ->
    {ok, [_r]}.
%%
%%服务端 -> 客户端 ------------------------------------
%%
%%是否准许进入
write(42000, Result) ->
	if
		Result=:=[] ->
			[];
		true ->
			[Reson, Nickname] = Result,
			Nickname1 = tool:to_binary(Nickname),
			PL = byte_size(Nickname1),
				Data = <<
					 Reson:8,PL:16,Nickname1/binary
    	       		   >>,
			{ok, pt:pack(42000, Data)}
	end;

write(42001, Result) ->
	if
		Result=:=[] ->
			[];
		true ->
			[Reson] = Result,
				Data = <<Reson:32>>,
			{ok, pt:pack(42001, Data)}
	end;

%%取场景信息
write(42010, [Fame_Info_list,Target_User_Id]) ->
	try
    	ListNum = length(Fame_Info_list),
    	F = fun(Fame_Info) ->
	            Fid = Fame_Info#ets_farm_info_back.fid,
    	        Fstate = Fame_Info#ets_farm_info_back.fstate,
				Sgoodsid = Fame_Info#ets_farm_info_back.sgoodsid,
				Sstate = Fame_Info#ets_farm_info_back.sstate,
				Max_Fruit = Fame_Info#ets_farm_info_back.max_fruit,
				Remain_Fruit = Fame_Info#ets_farm_info_back.remain_fruit,
				Remain_Time = Fame_Info#ets_farm_info_back.remain_time,
				Player_Lv = Fame_Info#ets_farm_info_back.player_lv,
				Gold_Use = Fame_Info#ets_farm_info_back.gold_use,
				Fruit_Id = Fame_Info#ets_farm_info_back.fruit_id,
				All_time = Fame_Info#ets_farm_info_back.all_time,
				Steal_Times = Fame_Info#ets_farm_info_back.steal_times,
				Res_id = Fame_Info#ets_farm_info_back.res_id,
    	        <<Fid:8, Fstate:8, Sgoodsid:32, Sstate:8, Max_Fruit:8, Remain_Fruit:8, Remain_Time:32, Player_Lv:8, Gold_Use:32, Fruit_Id:32, All_time:32, Steal_Times:8, Res_id:32>>
        	end,
	
    	ListBin = tool:to_binary(lists:map(F, Fame_Info_list)),
    	{ok, pt:pack(42010, <<Target_User_Id:32, ListNum:16, ListBin/binary>>)}
	catch
		_ : _ ->
			{ok, pt:pack(42010, <<>>)}
	end;

%%取土地信息
write(42011, Result) ->
			[Fid, Fstate, Sgoodsid, Sstate, Max_Fruit, Remain_Fruit, Remain_Time,Player_Lv,Gold_Use,Fruit_Id, All_time, Steal_Times,Res_id] = Result,	
			Data = <<
					 Fid:8,
					 Fstate:8,
					 Sgoodsid:32,
					 Sstate:8,
					 Max_Fruit:8,
					 Remain_Fruit:8,
					 Remain_Time:32,	
					 Player_Lv:8, 
					 Gold_Use:32,
					 Fruit_Id:32,
					 All_time:32,
					 Steal_Times:8,
					 Res_id:32				 
           		   >>,
			
			{ok, pt:pack(42011, Data)};


%%查看种子信息
write(42012, Seed_Info_List) ->
    ListNum = length(Seed_Info_List),
	if
		ListNum =:=0 ->
			{ok, pt:pack(42012, <<ListNum:16>>)};
		true ->
    		F = fun(Seed_Info) ->
            	{Seed_Id,Seed_Count}=Seed_Info,
            	<<Seed_Id:32, Seed_Count:32>>
        	end,
    		ListBin = tool:to_binary(lists:map(F, Seed_Info_List)),
    		{ok, pt:pack(42012, <<ListNum:16, ListBin/binary>>)}
	end;

%%查看加速器信息
write(42013, Result) ->
	if
		Result=:=[] ->
			[];
		true ->
				Data = <<Result:8>>,
			{ok, pt:pack(42013, Data)}
	end;

%%取好友，黑名单，仇家列表
write(42014, Friends_List) ->
    ListNum = length(Friends_List),
    F = fun(Friend_Info) ->
            {Id, Sex, Career, Lv, Nickname}=Friend_Info,
			Nickname1 = tool:to_binary(Nickname),
			NL = byte_size(Nickname1),
			%%是否可偷取
			Canmature = lib_manor:is_mature_status(Id),
			Result =
				if Lv < 30 ->
					   0;
				  Lv >= 30 andalso Canmature > 0 ->
					  1;
				   true ->
					   0
				end,
            <<Id:32, Sex:8, Career:8, Lv:8, Result:8, NL:16, Nickname1/binary>>
        end,
    ListBin = tool:to_binary(lists:map(F, Friends_List)),
    {ok, pt:pack(42014, <<ListNum:16, ListBin/binary>>)};


%%获取今日可偷次数
write(42015, Result) ->
	Data = <<Result:8>>,
	{ok, pt:pack(42015, Data)};

%%获取LOG
write(42016, Log_Info_List) ->
    ListNum = length(Log_Info_List),
    F = fun(Log_Info) ->
            %%{Steal_time, Actions, Player_name, Fid, Sgoodsid, Count}=Log_Info,
			{_ , _, _, Steal_time, Actions, _Pid, Nickname, Fid, Sgoodsid, Count, _}=Log_Info,
			Nickname1 = tool:to_binary(Nickname),
			PL = byte_size(Nickname1),
            <<Steal_time:32, Actions:8, PL:16,Nickname1/binary, Fid:8, Sgoodsid:32, Count:32>>
        end,
    ListBin = tool:to_binary(lists:map(F, Log_Info_List)),
    {ok, pt:pack(42016, <<ListNum:16, ListBin/binary>>)};

%%获取本人庄园是否有东西成熟
write(42017, Result) ->
	Data = <<Result:8>>,
	{ok, pt:pack(42017, Data)};

%%播种
write(42020, Result) ->
	if
		Result=:=[] ->
			[];
		true ->
			[Status, Seed_lv]=Result,
				Data = <<Status:8,Seed_lv:8>>,
			{ok, pt:pack(42020, Data)}
	end;

%%收获（偷菜）
write(42021, Result) ->
	if
		Result=:=[] ->
			[];
		true ->
			[Err_Code, Farm_Id, Good_Id, Remain, Pick_Count] = Result,			
				Data = <<Err_Code:8, Farm_Id:8, Good_Id:32, Remain:8, Pick_Count:8>>,
			{ok, pt:pack(42021, Data)}
	end;

%%一键收获（偷菜）
write(42022, Result) ->
	Data = <<Result:8>>,
	{ok, pt:pack(42022, Data)};
%%write(42022, [Status, Fruit_Info_List]) ->
    %%ListNum = length(Fruit_Info_List),
    %%F = fun(Fruit_Info) ->
    %%        {Farm_Id,Good_Id,Pick_Count}=Fruit_Info,
    %%        <<Farm_Id : 8 ,Good_Id : 32,Pick_Count : 8>>
    %%    end,
    %%ListBin = tool:to_binary(lists:map(F, Fruit_Info_List)),
    %%{ok, pt:pack(42022, <<Status:8, ListNum:32, ListBin/binary>>)};


%%使用加速器
write(42023, Result) ->
	if
		Result=:=[] ->
			[];
		true ->
			[Farm_Id, Error_Code, Remain_Time] = Result,
				Data = <<Farm_Id:8, Error_Code:8, Remain_Time:32>>,
			{ok, pt:pack(42023, Data)}
	end;

%%土地开垦
write(42024, Result) ->
	
	[Farm_Id, Error_Info] = Result,
	Data = <<Farm_Id:8,Error_Info:8>>,
	{ok, pt:pack(42024, Data)};

%%退出
write(42025, [_r]) ->
	Result = 0,
	Data = <<Result:8>>,
	{ok, pt:pack(42025, Data)};



%%卖出
write(42031, Result) ->
		Data = <<Result:8>>,
		{ok, pt:pack(42031, Data)};

%%取氏族好友
write(42114, Friends_List) ->
    ListNum = length(Friends_List),
    F = fun(Friend_Info) ->
            {Id, Sex, Career, Lv, Nickname}=Friend_Info,
			Nickname1 = tool:to_binary(Nickname),
			NL = byte_size(Nickname1),
            <<Id:32, Sex:8, Career:8, Lv:8, NL:16, Nickname1/binary>>
        end,
    ListBin = tool:to_binary(lists:map(F, Friends_List)),
    {ok, pt:pack(42114, <<ListNum:16, ListBin/binary>>)}.



