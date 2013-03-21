%%% -------------------------------------------------------------------
%%% Author  : zkj
%%% Description :神之庄园
%%% Created : 2010-11-18
%%% -------------------------------------------------------------------
-module(pp_manor).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%是否准许进入
handle(42000, PlayerStatus,[Master_Id, Type]) ->
	Data = lib_manor:send_manor_apply(PlayerStatus,Master_Id,Type),
	%%io:format("------------------------send_manor_apply Data=~p-----------------------------------------------.\n",[random:uniform(100)]),
	%%[State,Reson] = Data,
	if
		Data =:= [] ->
			error;
		Data =:= ok ->
			error;
		true ->
			{ok, BinData} = pt_42:write(42000, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;

%%时间同步
handle(42001, PlayerStatus, [_r]) ->
	Data = util:unixtime(),
	if
		Data =:= [] ->
			error;
		true ->
			{ok, BinData} = pt_42:write(42001, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;

%%取场景信息
handle(42010, PlayerStatus, [_r] ) ->
	{Data,Target_User_Id} = lib_manor:get_manor_state(PlayerStatus, [] ),	
	if
		Data =:= [] ->
			error;
		true ->
			{ok, BinData} = pt_42:write(42010, [Data,Target_User_Id]),
			if 
				BinData =:= [<<>>] ->
					error;
				true ->
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
			end
	end;

%%取土地信息
handle(42011, PlayerStatus, Farm_Id) ->
	Data = lib_manor:get_farm_info(PlayerStatus, Farm_Id ),
	if
		Data =:= [] ->
			error;
		true ->
			{ok, BinData} = pt_42:write(42011, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;

%%查看种子信息
handle(42012, PlayerStatus, [_r]) ->
	Data = lib_manor:get_good_info(PlayerStatus, [] ),	
	
			{ok, BinData} = pt_42:write(42012, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%查看加速器信息
handle(42013, PlayerStatus, [_r]) ->
	Data = lib_manor:get_celerate_info(PlayerStatus, [] ),	
	if
		Data =:= [] ->
			error;
		true ->
			{ok, BinData} = pt_42:write(42013, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;

%%取好友，黑名单，仇家列表
handle(42014, PlayerStatus, [_r]) ->
	Data = lib_manor:get_friends_lists(PlayerStatus, []),
	{ok, BinData} = pt_42:write(42014, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%获取今日可偷次数
handle(42015, PlayerStatus, [_r]) ->
	Data = lib_manor:get_steal_remain_times(PlayerStatus#player.id),	
	if
		Data =:= [] ->
			error;
		true ->
			{ok, BinData} = pt_42:write(42015, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;

%%获取LOG
handle(42016, PlayerStatus, [_r]) ->
	Data = lib_manor:get_log(PlayerStatus, [] ),	
	if
		Data =:= [] ->
			error;
		true ->
			{ok, BinData} = pt_42:write(42016, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;


%% 获取本人庄园是否有东西成熟
handle(42017, PlayerStatus, [_r]) ->
	Data = lib_manor:get_mature_status(PlayerStatus, []),
	if
		Data =:= [] ->
			error;
		true ->
			{ok, BinData} = pt_42:write(42017, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;
  
%%播种
handle(42020, PlayerStatus, [Farm_Id, Seed_Id]) ->
	
	Data = lib_manor:seed_on_farm(PlayerStatus, [Farm_Id, Seed_Id]),	
	
	if
		Data =:= [] ->
			error;
		Data =:=[0,0] ->%%发送土地信息
			%%发送土地信息
			Data1 = lib_manor:get_farm_info(PlayerStatus, Farm_Id ),		
			{ok, BinData1} = pt_42:write(42011, Data1),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1);
		true ->
			{ok, BinData} = pt_42:write(42020, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;
			
			
%%收获（偷菜）
handle(42021, PlayerStatus, Farm_Id) ->
	Data = lib_manor:get_on_farm(PlayerStatus, Farm_Id),
	if
		Data =:= [] ->
			error;
		true ->
			%%{ok, BinData} = pt_42:write(42021, lists:sublist(Data,4)),
			{ok, BinData} = pt_42:write(42021, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			%%更新土地信息
			Data1 = lib_manor:get_farm_info(PlayerStatus, Farm_Id ),
			if
				Data1 =:= [] ->
					error;
				true ->
					{ok, BinData1} = pt_42:write(42011, Data1),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1)
			end
	end;

%%一键收获（偷菜）
handle(42022, PlayerStatus, [_r]) ->
	Data = lib_manor:get_on_farm_one_key(PlayerStatus, []),
	if
		Data =:= [] ->
			error;
		true ->
			{ok, BinData} = pt_42:write(42022, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;

%%使用加速器
handle(42023, PlayerStatus, Farm_Id) ->
	Data = lib_manor:use_celerate(PlayerStatus, Farm_Id),	
	if
		Data =:= [] ->
			error;
		true ->
			{ok, BinData} = pt_42:write(42023, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			%%更新土地信息
			Data1 = lib_manor:get_farm_info(PlayerStatus, Farm_Id),
			if
				Data1 =:= [] ->
					error;
				true ->
					{ok, BinData1} = pt_42:write(42011, Data1),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1)
			end
	end;

%%土地开垦
handle(42024, PlayerStatus, Farm_Id) ->
	Data = lib_manor:farm_reclamation(PlayerStatus, Farm_Id ),
	if
		Data =:= [] ->
			error;
		true ->
			[Status, NewStatus] = Data,
			if
				Status =:=[] ->
					error;
				Status =:= ok ->
					%%更新土地信息
					Data1 = lib_manor:get_farm_info(PlayerStatus, Farm_Id ),
					if
						Data1 =:= [] ->
							error;
						true ->
							Num = lib_manor:get_reclaim_farm_num(NewStatus#player.id),
							case Num >= 9 of
								true ->%%开第九块地了
									%%添加成就的记录触发事件
									lib_achieve:check_achieve_finish(NewStatus#player.other#player_other.pid_send, 
																	  NewStatus#player.id, 623, [1]);
								false ->
									skip
							end,
							{ok, BinData1} = pt_42:write(42011, Data1),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1),
							{ok, NewStatus}
					end;
				true ->
					{ok, BinData} = pt_42:write(42024, Data),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
					%%{ok, NewStatus}
			end
	end;

%%退出
handle(42025, PlayerStatus, [_r]) ->
	lib_manor:farm_exit(PlayerStatus, []),	
	{ok, BinData} = pt_42:write(42025, [ok]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);


%%卖出
handle(42031, PlayerStatus, [Goods_list]) ->
	Data = lib_manor:sell_goods(PlayerStatus, Goods_list),
	if
		Data =:= [] ->
			error;
		true ->
			{Stat_Code, NewStatus}=Data,
			{ok, BinData} = pt_42:write(42031, Stat_Code),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			{ok, NewStatus}
	end;

%%取氏族好友
handle(42114, PlayerStatus, [_r]) ->
	Data = lib_guild:get_guild_friend(PlayerStatus#player.guild_id, PlayerStatus#player.id),
	{ok, BinData} = pt_42:write(42014, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData).


