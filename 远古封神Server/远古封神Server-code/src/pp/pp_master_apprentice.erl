%%% -------------------------------------------------------------------
%%% Author  : ygzj
%%% Description :师徒关系
%%% Created : 2010-11-18
%%% -------------------------------------------------------------------
-module(pp_master_apprentice).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").


%%拜师申请
handle(27000, PlayerStatus, Master_Id) ->
	Data = mod_master_apprentice:send_apprentice_apply(PlayerStatus,Master_Id),
	{ok, BinData} = pt_27:write(27000, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	MasterStatus  = lib_player:get_online_info(Master_Id),
	case MasterStatus of
		[] -> skip;
		_ ->
			handle(27021, MasterStatus, Master_Id)
	end;

%%接受拜师申请
handle(27001, PlayerStatus, Apprentenice_Id) ->
	Data = mod_master_apprentice:accept_apprentice_apply(PlayerStatus,Apprentenice_Id),
	if Data == [] ->
		   Data1 = 2;
	   true ->
		  Data1 = Data
	end,
	case Data1 of
		1 ->%%拥有一个徒弟
			lib_achieve:check_achieve_finish(PlayerStatus#player.other#player_other.pid_send, PlayerStatus#player.id, 624, [1]);
		_Other ->
			skip
	end,
	{ok, BinData} = pt_27:write(27001, Data1),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	ApprenteniceStatus  = lib_player:get_online_info(Apprentenice_Id),
	case ApprenteniceStatus of
		[] -> skip;
		_ ->
			handle(27010, ApprenteniceStatus, Apprentenice_Id),
			handle(27011, ApprenteniceStatus, Apprentenice_Id) 
	end,
	handle(27011, PlayerStatus, Apprentenice_Id),
	handle(27021, PlayerStatus, Apprentenice_Id);	

%%收徒邀请， 邀请对象角色ID
handle(27002, PlayerStatus, Apprentenice_Id) ->
	Data = mod_master_apprentice:invite_apprentice(PlayerStatus,Apprentenice_Id),
	[Forward,State,Master_id,Master_name] = Data,
	Data1 = [1,State,Master_id,Master_name],
	case Forward == 2 of %%成功时两边同时发消息
		false -> 
			{ok, BinData} = pt_27:write(27002, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		true -> 
			{ok, BinData} = pt_27:write(27002, Data1),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			Pid = lib_player:get_player_pid(Apprentenice_Id),
			case Pid of
				[] -> 
					skip;
				_ ->
					Data2 = [2,State,Master_id,Master_name],
					{ok, BinData1} = pt_27:write(27002, Data2),
					lib_send:send_to_uid(Apprentenice_Id, BinData1)
			
			end
	end;
    
%%是否同意拜师， 邀请对象角色ID
handle(27003, PlayerStatus, [Master_Id0,Status]) ->
	Data = mod_master_apprentice:accpet_invite_apprentice(PlayerStatus,Master_Id0,Status),
	case Data of
		[] -> skip;
		_ -> 
			[Forward,State1,Master_id,Master_name,State2,ApprenticeId,ApprenticeName] = Data,
			Data1 = [1,State1,Master_id,Master_name,State2,ApprenticeId,ApprenticeName],
			{ok, BinData} = pt_27:write(27003, Data1),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			%% MasterStatus = lib_player:get_online_info(Master_Id0),
			Pid = lib_player:get_player_pid(Master_Id0),
			%%两边同时发消息
			case Pid of
				[] ->
					skip;
				_ ->
					case Forward of
						2 ->
							{ok, BinData1} = pt_27:write(27003, Data),
							lib_send:send_to_uid(Master_Id0, BinData1);
						1 ->
							Data2 = [2,State1,Master_id,Master_name,State2,ApprenticeId,ApprenticeName],
							{ok, BinData1} = pt_27:write(27003, Data2),
							lib_send:send_to_uid(Master_Id0, BinData1)
					end
			end
	end,
	handle(27011, PlayerStatus, Master_Id0),
	handle(27021, PlayerStatus, Master_Id0);
		
%%查询当前角色的师傅信息
handle(27010, PlayerStatus, _Player_Id) ->
	Data = mod_master_apprentice:get_master_info(PlayerStatus#player.id),
	%io:format("Data is ~p~n",[Data]),
	{ok, BinData} = pt_27:write(27010, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%查询同门师兄弟信息列表
handle(27011, PlayerStatus, _Player_Id) ->
	Data = mod_master_apprentice:get_master_apprentice_info_page(PlayerStatus#player.id),
	{ok, BinData} = pt_27:write(27011, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%可否汇报成绩
handle(27012, PlayerStatus, _Player_Id) ->
	Data = 1,%%mod_master_apprentice:is_need_report(PlayerStatus),%%1
	{ok, BinData} = pt_27:write(27012, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);


%%汇报成绩
handle(27013, PlayerStatus, Player_Id) ->
	Data = mod_master_apprentice:report_lv(PlayerStatus),
	[State,_Forward,Exp,Spirit] = Data,
	Data1 = [State,2,round(Exp*0.05),round(Spirit*0.025)],
	{ok, BinData} = pt_27:write(27013, Data1),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	case State  == 1 of%%成功则向师傅发信息
		false -> skip;
		true -> 
			Master_id = mod_master_apprentice:get_own_master_id(PlayerStatus#player.id),
%% 		MasterStatus = lib_player:get_online_info(Master_id),
			Pid = lib_player:get_player_pid(Master_id),
			case Pid of 
				[] -> skip;
				_ ->
					Data2 = [State,1,round(Exp*0.025),round(Spirit*0.0125)],
					{ok, BinData1} = pt_27:write(27013, Data2),
					lib_send:send_to_uid(Master_id, BinData1)
			end
	end,
	handle(27020, PlayerStatus, Player_Id);


%%退出师门,State是否使用决裂书
handle(27014, PlayerStatus, State) ->
	Master_id = mod_master_apprentice:get_own_master_id(PlayerStatus#player.id),
	Data = mod_master_apprentice:exit_master_apprentice(PlayerStatus,State),
	if Data == [] ->
		   skip;
	   true ->
		   {ok, BinData} = pt_27:write(27014, Data),
		   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
		   MasterStatus  = lib_player:get_online_info(Master_id),
		   case MasterStatus of
			   [] -> skip;
			   _->
				   handle(27021, MasterStatus, Master_id)
		   end,
		   handle(27011, PlayerStatus, State),
		   handle(27010, PlayerStatus, State)
	end;	   

%%查询当前角色的信息
handle(27020, PlayerStatus, _Player_Id) ->
	Data = mod_master_apprentice:get_current_role_info(PlayerStatus#player.id),
	{ok, BinData} = pt_27:write(27020, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%查询当前角色的徒弟信息
handle(27021, PlayerStatus, _Player_Id) ->
	Data = mod_master_apprentice:get_my_apprentice_info_page(PlayerStatus#player.id),
	case Data of
		[] ->
			skip;
		_ ->%%拥有一个徒弟
			lib_achieve:check_achieve_finish(PlayerStatus#player.other#player_other.pid_send, PlayerStatus#player.id, 624, [1])
	end,
	{ok, BinData} = pt_27:write(27021, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%逐出师门,State是否使用决裂书
handle(27022, PlayerStatus, [Apprentenice_Id, State]) ->
	Data = mod_master_apprentice:kick_out_master_apprentice(PlayerStatus,Apprentenice_Id,State),
	{ok, BinData} = pt_27:write(27022, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	ApprenteniceStatus  = lib_player:get_online_info(Apprentenice_Id),
	case ApprenteniceStatus of
		[] -> skip;
		_ ->%%师傅删除徒弟申请时通知徒弟更新我的师傅信息和师兄弟列表
			handle(27010, ApprenteniceStatus, Apprentenice_Id),
			handle(27011, ApprenteniceStatus, Apprentenice_Id)
	end,
	handle(27021, PlayerStatus, Apprentenice_Id),
	handle(27020, PlayerStatus, Apprentenice_Id);

%%拜师申请通知 
handle(27023, PlayerStatus, _MasterId) ->
	{ok, BinData} = pt_27:write(27023, 1),%%1表示有拜师申请通知 
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%查询所有伯乐 信息
handle(27030, PlayerStatus, PageNumber) ->
	Data = mod_master_apprentice:get_all_master_info_page(PageNumber),
	{ok, BinData} = pt_27:write(27030, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%登记上榜
handle(27031, PlayerStatus, _Player_Id) ->
	Data = mod_master_apprentice:enter_master_charts(PlayerStatus),
	{ok, BinData} = pt_27:write(27031, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	handle(27030, PlayerStatus, 1);

%%登取消上榜
handle(27032, PlayerStatus, _Player_Id) ->
	Data = mod_master_apprentice:exit_master_charts(PlayerStatus#player.id),
	{ok, BinData} = pt_27:write(27032, Data),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	handle(27030, PlayerStatus, 1);

%%查找伯乐
handle(27033, PlayerStatus, Nickname) ->
	Data = mod_master_apprentice:query_master_charts(Nickname),
	{ok, BinData} = pt_27:write(27033, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%出师
handle(27040, PlayerStatus, _Player_Id) ->
	Data = mod_master_apprentice:finish_apprenticeship(PlayerStatus#player.id),
	if Data == [] ->
		   skip;
	   true ->
		   [Forward,State] = Data,
		   Data1 = 
			   case Forward == 2 of
				   false -> Data;
				   true -> [1,State]
			   end,
		   {ok, BinData} = pt_27:write(27040, Data1),
		   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
		   case State == 1 of
			   false -> skip;
			   true ->
				   Master_id = mod_master_apprentice:get_own_master_id(PlayerStatus#player.id),
				   %% 		MasterStatus = lib_player:get_online_info(Master_id),
			Pid = lib_player:get_player_pid(Master_id),
				   case Pid of
					   [] -> skip;
					   _ ->
						   {ok, BinData1} = pt_27:write(27040, Data),
						   lib_send:send_to_uid(Master_id, BinData1)
				   end
		   end
	end.
	







