%%%-----------------------------------
%% Author: ygzj
%% Created: 2010-11-17
%% Description: TODO: 师徒关系逻辑处理
%%%-----------------------------------
-module(lib_master_apprentice).
-compile(export_all).

-include("common.hrl").
-include("record.hrl").

%%-----------------------------------------------
%%加载所有的师徒关系 0默认值，1已出师，2学徒，3申请中
%%-----------------------------------------------
load_master_apprentice() ->
	MastApprList = db_agent:load_master_apprentice(),
	lists:map(fun load_master_apprentic_into_ets/1,MastApprList).

load_master_apprentic_into_ets(MastApprRecord) ->
	MastApprRecordEts = list_to_tuple([ets_master_apprentice]++MastApprRecord),
	ets_insert_master_apprentice(MastApprRecordEts).

%%玩家上下线
update_master_charts_online(PlayerId,State)->
	db_agent:update_master_charts_online(PlayerId,State).

%%查询师傅信息
get_master_info(Player_Id) ->
	Master_id = get_own_master_id(Player_Id),
	Data = db_agent:get_master_charts(Master_id),
	case Data of
		[]->
			[];
		_->
			[_Id,Master_id,Master_name,Master_lv,_Realm,Career,_Award_count,Score_lv,Appre_num,_Regist_time,_Lover_type,_Sex,_Online] = Data,
			[Master_id,Master_name,Master_lv,Career,Score_lv,Appre_num+1]
	end.

%%查询的伯乐榜所有数据 ,lover_type为1才能上榜
get_all_master_info_page(PageNumber) ->
	Result = db_agent:load_master_charts(PageNumber),
	[DataSize] = db_agent:load_master_charts_count(),
	Totalpage = 
		case DataSize rem 10 of
			0 -> DataSize div 10;
			_ -> DataSize div 10+1
		end,
%% 	Result1 = 
%% 	case Result of
%% 		[] -> [];
%% 		_ ->
%% 			F = fun(R) ->
%% 						[_Id,Master_id,_Master_name,_Master_lv,_Realm,_Career,_Award_count,_Score_lv,_Appre_num,_Regist_time,_Lover_type,_Sex,_Online] = R,
%% 						Pid = lib_player:get_player_pid(Master_id),
%% 						case Pid of
%% 							[] -> lists:append(R,[0]);
%% 							_ -> lists:append(R,[1])
%% 						end
%% 				end,
%% 			[F(R) ||R <- Result]
%% 	end,
	[PageNumber, Totalpage, Result].

%%查询自己在师徒表缓存中的数据
get_own_info(Player_Id) ->
	Pattern = #ets_master_apprentice{apprentenice_id=Player_Id,_='_'},
	match_all(?ETS_MASTER_APPRENTICE, Pattern).

get_own_statu(Player_Id) ->
	Data = get_own_info(Player_Id),
	case Data of
		[] -> 7;%%未在师徒列表中
		_ ->
			[{_Ets_master_apprentice,_Id1,_Apprentenice_id,_Apprentenice_name,_Master_id,_Lv,_Career,Status,_Report_lv,_Join_time,_Last_report_time,_Sex}] = Data,
			Status
	end.

%%查询当前角色的师道值，成绩，人数
get_current_role_info(Player_Id) ->
	Data = db_agent:get_master_charts(Player_Id),
	case Data of
		[]->
			[];
		_->
			[_Id,_Master_id,_Master_name,_Master_lv,_Realm,_Career,Award_count,Score_lv,Appre_num,_Regist_time,_Lover_type,_Sex,_Online] = Data,
			[Award_count,Score_lv,Appre_num+1]
	end.

%%查询自己师傅的id
get_own_master_id(Player_Id) ->
	Pattern = #ets_master_apprentice{apprentenice_id=Player_Id,_='_'},
	Result = match_all(?ETS_MASTER_APPRENTICE, Pattern),
	case Result of 
		[] ->
			0;
		_ ->
			[{_Ets_master_apprentice,_Id1,_Apprentenice_id,_Apprentenice_name,Master_id,_Lv,_Career,_Status,_Report_lv,_Join_time,_Last_report_time,_Sex}] = Result,
			Master_id
	end.

%%拜师申请
send_apprentice_apply(PlayerStatus,MasterId) ->
	Lv = PlayerStatus#player.lv,
	case lib_player:is_online(MasterId) of
			 false -> 2;%% 对方不在线，不能拜师
			 _ ->
				 MasterLv = db_agent:get_player_properties(lv,MasterId),
				 case MasterLv < 30 of
					 true  -> 12; %% 对方等级没有达到30级，不能收徒
					 false ->
						 case  Lv < 10 orelse Lv > 30 of %%等级小于10级不能拜师,大于30级不能拜师
							 true -> 
								 case Lv < 10 of
									 true -> 3;
									 false -> 4
								 end;
							 false ->
								 case is_exist_master(PlayerStatus#player.id) of %%已经有师傅，不能拜师
									 true -> 5;
									 false ->
										 case get_ungraduate_apprentice_count(MasterId) >= 5 of %%对方未出师徒弟有5个，不能拜师
											 true -> 6;
											 false ->
												 case get_applying_apprentice_count(MasterId) >= 10 of
													 true -> 11; %%对方申请中徒弟数量超过10个，不能接受申请
													 false ->
														  case get_own_statu(PlayerStatus#player.id) of
															  1 -> 8;%%已经出师，不能申请拜师
															  2 -> 9;%%已经是学徒，不能申请拜师
															  3 -> 10;%%已经提交申请，请等待批准或撤回申请
															  _ -> handle_send_apprentice_apply(PlayerStatus,MasterId)
														  end
												 end
										 end
								 end
						 end
				 end
		 end.

%%满足条件后处理拜师申请，状态为3申请中
handle_send_apprentice_apply(PlayerStatus,MasterId) ->
	create_master_apprentice(PlayerStatus#player.id,PlayerStatus#player.nickname,MasterId,PlayerStatus#player.lv,PlayerStatus#player.career,3,PlayerStatus#player.lv,0,0,PlayerStatus#player.sex),	
	MasterStatus = lib_player:get_online_info(MasterId),
	case MasterStatus of
		[] -> 2;%% 师傅不在线，不能拜师
		_ ->
			Data = db_agent:get_master_charts(MasterId),
			case Data of 
				[] ->%%插入伯乐表数据
					db_agent:create_master_charts(MasterStatus#player.id,MasterStatus#player.nickname,MasterStatus#player.lv,MasterStatus#player.realm,MasterStatus#player.career,0,0,0,0,0,PlayerStatus#player.sex);
				_ -> %%更新字段
					skip
			end,
			pp_master_apprentice:handle(27023, MasterStatus, MasterId),%%将拜师申请信息推送到客户端
			%%拜师任务接口
%% 		lib_task:event(master,null,PlayerStatus),
			1
	end.

%%接受拜师申请
accept_apprentice_apply(PlayerStatus,Apprentenice_Id) ->
	Lv = PlayerStatus#player.lv,
	case lib_player:is_online(PlayerStatus#player.id) of
			false -> 2;%%对方不在线，不能接受拜师
			_ -> 
				case  Lv >= 30 of %%等级小于30级不能接受拜师
					false -> 3;
					true ->
						 case get_ungraduate_apprentice_count(PlayerStatus#player.id) >= 5 of %%对方未出师徒弟有5个，不能拜师
							 true -> 4;
							 false ->handle_accept_apprentice_apply(PlayerStatus,Apprentenice_Id)
						 end
				 end
	end. 
		
%%满足条件后接受拜师申请   在伯乐表中成员数加1,在师徒表中增加师傅的数据
handle_accept_apprentice_apply(PlayerStatus,Apprentenice_Id) ->
	Data = get_own_info(Apprentenice_Id),
	case Data == [] of
		true -> skip;
		false ->
			CurrentTime = util:unixtime(),
			MasterData = get_own_info(PlayerStatus#player.id),
			case MasterData of %%师傅的数据是否在师徒表中，如果不在，插入数据
				[] -> 
					create_master_apprentice(PlayerStatus#player.id,PlayerStatus#player.nickname,0,PlayerStatus#player.lv,PlayerStatus#player.career,0,PlayerStatus#player.lv,0,0,PlayerStatus#player.sex);
				_ -> skip
			end,	
			[{_Ets_master_apprentice,Id,Apprentenice_id,Apprentenice_name,Master_id,Lv,Career,_Status,Report_lv,_Join_time,Last_report_time,Sex}] = Data,
			Data1 = [Id,Apprentenice_id,Apprentenice_name,Master_id,Lv,Career,2,Report_lv,CurrentTime,Last_report_time,Sex],
			insert_ets_master_apprentice(Data1),%%更新缓存数据的状态2，登记时间
			db_agent:update_master_apprentice(2,CurrentTime,Apprentenice_id,Master_id),
			%%发送信件
			Content1 = io_lib:format("【您成功收~s为徒】",[tool:to_list(Apprentenice_name)]),
			lib_mail:send_sys_mail([tool:to_list(PlayerStatus#player.nickname)],"系统信件", Content1, 0, 0, 0, 0, 0),
			Content2 = io_lib:format("【您成功拜~s为师】",[tool:to_list(PlayerStatus#player.nickname)]),
			lib_mail:send_sys_mail([tool:to_list(Apprentenice_name)],"系统信件", Content2, 0, 0, 0, 0, 0),
			%%同时更新伯乐表中的师门人数等数据，如果没有数据，则新建数据，love_type为0，不在伯乐榜中显示，当他点击申请上榜后将love_type改为1
			Data2 = db_agent:get_master_charts(PlayerStatus#player.id),
			case Data2 of
				[] ->
					db_agent:create_master_charts(PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.lv,PlayerStatus#player.realm,PlayerStatus#player.career,1,0,1,0,0,PlayerStatus#player.sex),
					1;
				_ ->
					[_Id1,Master_id1,_Master_name1,_Master_lv1,_Realm1,_Career1,Award_count1,Score_lv1,Appre_num1,_Regist_time1,_Lover_type1,_Sex,_Online] = Data2,
					db_agent:update_master_charts(Award_count1+1,Score_lv1,Appre_num1+1,Master_id1),
					1
			end
	end.
	
insert_ets_master_apprentice(Data) ->
	EtsData = match_ets_master_apprentice(Data),
	ets:insert(?ETS_MASTER_APPRENTICE,EtsData),
	1.

%%收徒邀请
invite_apprentice(PlayerStatus,Apprentenice_Id) ->
	Lv = PlayerStatus#player.lv,
	Lv2 = db_agent:get_player_properties(lv,Apprentenice_Id),
	case lib_player:is_online(Apprentenice_Id) of
			false -> [1,2,0,""];%%对方不在线，不能接受收徒邀请
			_ -> 
				 case  Lv < 30 of %%等级小于30级,不能发出收徒邀请
					true -> [1,3,0,""];
					false ->
						 case is_exist_master(Apprentenice_Id) of %%已经有师傅，不能拜师
							 true -> [1,5,0,""];
							 false ->
								 case get_ungraduate_apprentice_count(PlayerStatus#player.id) >= 5 of %%未出师徒弟有5个，不能发出收徒邀请
									 true -> [1,6,0,""];
									 false -> 
										  case  Lv2 < 10 orelse Lv2 > 29 of %%对方等级小于10级不能拜师,大于29级不能接受收徒邀请
													 true -> 
														 case Lv2 < 10 of
															 true -> [1,8,0,""];%%等级小于10级
															 false -> [1,9,0,""]%%等级大于29级
														 end;
													 false -> 
														 [2,1,PlayerStatus#player.id,PlayerStatus#player.nickname]
											end
								 end
						 end
				 end
	end.

%%是否同意拜师
accpet_invite_apprentice(PlayerStatus,Master_Id0,Status) ->
	MasterStatus = lib_player:get_online_info(Master_Id0),
	case MasterStatus of
		[] -> [];%%师傅不在线
		_ ->
			case get_ungraduate_apprentice_count(Master_Id0) >= 5 of%%对方未出师的徒弟超过5个
				true -> [];%%徒弟多于5个不能拜师
				false -> 
					case Status of
						0 -> [2,2,MasterStatus#player.id,MasterStatus#player.nickname,2,PlayerStatus#player.id,PlayerStatus#player.nickname];%%对方不同意，返回同意
						1 -> %%当师傅连续发了两次收徒邀请，徒弟界面会显示两个图标，第一次点同意后，第二次则返回成功信息
							ApprenticeState = get_own_statu(PlayerStatus#player.id),
							case ApprenticeState of
								2 -> [1,1,MasterStatus#player.id,MasterStatus#player.nickname,1,PlayerStatus#player.id,PlayerStatus#player.nickname];%%徒弟状态为2，已经成为学徒
								_ ->
									CreateTime = util:unixtime(),
									ApprenteniceData = get_own_info(PlayerStatus#player.id),
									case ApprenteniceData of %%徒弟的数据是否在师徒表中，如果不在，插入数据
										[] ->
											create_master_apprentice(PlayerStatus#player.id,PlayerStatus#player.nickname,Master_Id0,PlayerStatus#player.lv,PlayerStatus#player.career,2,PlayerStatus#player.lv,CreateTime,0,PlayerStatus#player.sex);
										_ -> %%更新徒弟注册时间
											[{_Ets_master_apprentice1,Id1,Apprentenice_id1,Apprentenice_name1,_Master_id1,Lv1,Career1,_Status1,Report_lv1,_Join_time1,Last_report_time1,Sex1}] = ApprenteniceData,
											ApprenteniceData1 = [Id1,Apprentenice_id1,Apprentenice_name1,Master_Id0,Lv1,Career1,2,Report_lv1,CreateTime,Last_report_time1,Sex1],
											insert_ets_master_apprentice(ApprenteniceData1),
											db_agent:update_master_apprentice(2,CreateTime,Apprentenice_id1,Master_Id0)
									end,
									case db_agent:get_master_apprentice(Master_Id0) of %%师傅的数据是否在师徒表中，如果不在，插入数据
										[] ->
											create_master_apprentice(MasterStatus#player.id,MasterStatus#player.nickname,0,MasterStatus#player.lv,MasterStatus#player.career,0,MasterStatus#player.lv,0,0,MasterStatus#player.sex);
										_ -> skip
									end,
									%%发送信件
									Content1 = io_lib:format("【您成功收~s为徒】",[tool:to_list(PlayerStatus#player.nickname)]),
									lib_mail:send_sys_mail([tool:to_list(MasterStatus#player.nickname)],"系统信件", Content1, 0, 0, 0, 0, 0),
									Content2 = io_lib:format("【您成功拜~s为师】",[tool:to_list(MasterStatus#player.nickname)]),
									lib_mail:send_sys_mail([tool:to_list(PlayerStatus#player.nickname)],"系统信件", Content2, 0, 0, 0, 0, 0),
									Data = db_agent:get_master_charts(Master_Id0),
									case Data of
										[] ->%%插入伯乐表数据
											db_agent:create_master_charts(MasterStatus#player.id,MasterStatus#player.nickname,MasterStatus#player.lv,MasterStatus#player.realm,MasterStatus#player.career,1,0,1,0,0,PlayerStatus#player.sex),
											[1,1,MasterStatus#player.id,MasterStatus#player.nickname,1,PlayerStatus#player.id,PlayerStatus#player.nickname];
										_ -> %%更新字段
											[_Id,Master_id,_Master_name,_Master_lv,_Realm,_Career,Award_count,Score_lv,Appre_num,_Regist_time,_Lover_type,_Sex,_Online] = Data,
											db_agent:update_master_charts(Award_count+1,Score_lv,Appre_num+1,Master_id),
											[1,1,MasterStatus#player.id,MasterStatus#player.nickname,1,PlayerStatus#player.id,PlayerStatus#player.nickname]
									end
							end
					end
			end
	end.

create_master_apprentice(Apprentenice_id,Apprentenice_name,Master_id,Lv,Career,Status,Report_lv,Join_time,Last_report_time,Sex) ->
	case db_agent:create_master_apprentice(Apprentenice_id,Apprentenice_name,Master_id,Lv,Career,Status,Report_lv,Join_time,Last_report_time,Sex) of
		{_mongo,Ret} ->%%更新缓存
			Data_master_apprentice = [Ret,Apprentenice_id,Apprentenice_name,Master_id,Lv,Career,Status,Report_lv,Join_time,Last_report_time,Sex],%%db_agent:get_master_apprentice(PlayerStatus#player.id),
			insert_ets_master_apprentice(Data_master_apprentice);
		_ -> %%更新缓存
			Data_master_apprentice = db_agent:get_master_apprentice(Apprentenice_id),
			insert_ets_master_apprentice(Data_master_apprentice)
	end.


%%查询师傅
query_master_charts(Nickname) ->
	Data = db_agent:load_master_charts(),
	case Data of 
		[] -> [];
		_ -> 
			F = fun(Master_charts) ->
						[_Id,Master_id,Master_name,Master_lv,_Realm,Career,Award_count,_Score_lv,Appre_num,Regist_time,_Lover_type,Sex,_Online] = Master_charts,
						Master_name1 = tool:to_list(Master_name),
						{Nickname1,_Bin} = pt:read_string(Nickname),
						case string:str(Master_name1,Nickname1) =/= 0 of
							true -> 
								Pid = lib_player:get_player_pid(Master_id),
								case Pid of
									[] -> [Master_id,Master_name,Master_lv,Career,Sex,Award_count,Appre_num,Regist_time,0];
									_ -> [Master_id,Master_name,Master_lv,Career,Sex,Award_count,Appre_num,Regist_time,1]
								end;
							false -> []
						end
				end,
			R = lists:map(F, Data),
			lists:filter(fun(T)-> T =/= [] end, R)
	end.

%%登记上榜
enter_master_charts(PlayerStatus) ->
	Data = db_agent:get_master_charts(PlayerStatus#player.id),
	CreateTime = util:unixtime(),
	Lv = PlayerStatus#player.lv,
	case Lv < 30 of
		true -> 3;%%等级小于30级，不能上榜
		false ->
			case Data of
				[] ->%%插入伯乐表数据
					db_agent:create_master_charts(PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.lv,PlayerStatus#player.realm,PlayerStatus#player.career,0,0,0,CreateTime,1,PlayerStatus#player.sex),
					1;
				_ -> %%更新字段
					[_Id,Master_id,_Master_name,_Master_lv,_Realm,_Career,_Award_count,_Score_lv,_Appre_num,_Regist_time,Lover_type,_Sex,_Online] = Data,
					case Lover_type of
						1 -> 2; %%已经上榜
						0 -> 
							db_agent:update_master_charts(CreateTime,1,Master_id),
%% 						lib_task:event(master,null,PlayerStatus),%%拜师任务接口
							1
					end
			end
	end.

%%取消上榜
exit_master_charts(Player_Id) ->
	Data = db_agent:get_master_charts(Player_Id),
	case Data of 
		[] -> 2;
		_ ->
			[_Id,Master_id,_Master_name,_Master_lv,_Realm,_Career,_Award_count,_Score_lv,_Appre_num,_Regist_time,_Lover_type,_Sex,_Online] = Data,
			db_agent:update_master_charts(0,Master_id),
			1
	end.

%%判断是否已经登记上榜
is_enter_master_charts(Player_Id) ->
	Lover_type = db_agent:get_master_charts(lover_type,Player_Id),
	case Lover_type of
		1 -> true;
		_ -> false
	end.
	
%%退出师门,State是否使用决裂书
exit_master_apprentice(PlayerStatus,State) ->
	Master_id = get_own_master_id(PlayerStatus#player.id),
	Status = db_agent:get_master_apprentice_properties(status,PlayerStatus#player.id),%%徒弟状态
	case Master_id of
		0 -> 3;%%您没有师傅
		_ ->
			Days = calc_unlogin_time(Master_id),
			case State of
				0 -> %%没有使用决裂书
					case Days > ?UNLOGIN_DAYS of
						false -> 0;
						true -> %%可以退出师门，同时删除数据库中的师徒关系数据，并在伯乐表中减少人数
							db_agent:del_master_apprentice(PlayerStatus#player.id),
							%%删除缓存中的师徒关系中的数据,减少伯乐表中对应的数人
							ets:delete(?ETS_MASTER_APPRENTICE,PlayerStatus#player.id),
							Data = db_agent:get_master_charts(Master_id),
							if Data == [] ->
								   skip;
							   true ->
								   [_Id,_Master_id,Master_name,_Master_lv,_Realm,_Career,Award_count,Score_lv,Appre_num,_Regist_time,_Lover_type,_Sex,_Online] = Data,
								   case Status == 3 of
									   true -> skip;
									   false -> %%只有当状态不为学徒和出师的徒弟退出时才减少师门人数
										   db_agent:update_master_charts(Award_count,Score_lv,Appre_num-1,Master_id)
								   end,
								   Content2 = io_lib:format("【~s已经从您的师门中退出】",[tool:to_list(PlayerStatus#player.nickname)]),
								   mod_mail:send_sys_mail([tool:to_list(Master_name)],"系统信件",Content2, 0, 0, 0, 0, 0)
							end,							
							1
					end;
				1 -> %%使用决裂书
					Reply = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'goods_find',PlayerStatus#player.id,28003}),
					case Reply of
						false -> 2; %%选择决裂书，却没有这个物品
						_ ->
							db_agent:del_master_apprentice(PlayerStatus#player.id),
							%%删除缓存中的师徒关系中的数据,减少伯乐表中对应的数人
							ets:delete(?ETS_MASTER_APPRENTICE,PlayerStatus#player.id),
							Data = db_agent:get_master_charts(Master_id),
							[_Id,_Master_id,Master_name,_Master_lv,_Realm,_Career,Award_count,Score_lv,Appre_num,_Regist_time,_Lover_type,_Sex,_Online] = Data,
							case Status == 3 of
								true -> skip;
								false -> %%只有当状态不为学徒和出师的徒弟退出时才减少师门人数
									db_agent:update_master_charts(Award_count,Score_lv,Appre_num-1,Master_id)
							end,
							gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', 28003, 1}),%%删除玩家的决裂书
							Content2 = io_lib:format("【~s已经从您的师门中退出】",[tool:to_list(PlayerStatus#player.nickname)]),
							mod_mail:send_sys_mail([tool:to_list(Master_name)],"系统信件",Content2, 0, 0, 0, 0, 0),
							1
					end;
				2 -> %%申请状态中不需要使用决裂书
							case Status == 3 of %%申请状态中
								false -> 2; %%选择决裂书，却没有这个物品
								true ->
									db_agent:del_master_apprentice(PlayerStatus#player.id),
									%%删除缓存中的师徒关系中的数据,减少伯乐表中对应的数人
									ets:delete(?ETS_MASTER_APPRENTICE,PlayerStatus#player.id),
									3
							end
			end
	end.
	

%%逐出师门,State是否使用决裂书
kick_out_master_apprentice(PlayerStatus,Apprentenice_Id,State) ->
	Days = calc_unreport_time(Apprentenice_Id),
	Status = db_agent:get_master_apprentice_properties(status,PlayerStatus#player.id),%%徒弟状态
	case State of
				0 -> %% 没有使用决裂书
					case Days > ?UNREPORT_DAYS of
						false -> 0;
						true -> %%可以逐出师门，同时删除数据库中的师徒关系数据，并在伯乐表中减少人数
							Apprentenice_name1 = db_agent:get_master_apprentice_properties(apprentenice_name,Apprentenice_Id),
							db_agent:del_master_apprentice(Apprentenice_Id),
							%%删除缓存中的师徒关系中的数据,减少伯乐表中对应的数人
							ets:delete(?ETS_MASTER_APPRENTICE,Apprentenice_Id),
							Data = db_agent:get_master_charts(PlayerStatus#player.id),
							[_Id,Master_id,_Master_name,_Master_lv,_Realm,_Career,Award_count,Score_lv,Appre_num,_Regist_time,_Lover_type,_Sex,_Online] = Data,
							case Status == 3 of
								true -> skip;
								false -> %%只有当状态不为学徒和出师的徒弟退出时才减少师门人数
									db_agent:update_master_charts(Award_count,Score_lv,Appre_num-1,Master_id)
							end,
							Content2 = io_lib:format("【~s已经 把您逐出师门】",[tool:to_list(PlayerStatus#player.nickname)]),
							mod_mail:send_sys_mail([tool:to_list(Apprentenice_name1)],"系统信件",Content2, 0, 0, 0, 0, 0),
							1
					end;
				1 -> %%使用决裂书
					Reply = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'goods_find',PlayerStatus#player.id,28003}),
					case Reply of
						false -> 2; %%选择决裂书，却没有这个物品
						_ ->
							Apprentenice_name1 = db_agent:get_master_apprentice_properties(apprentenice_name,Apprentenice_Id),
							db_agent:del_master_apprentice(Apprentenice_Id),
							%%删除缓存中的师徒关系中的数据,减少伯乐表中对应的数人
							ets:delete(?ETS_MASTER_APPRENTICE,Apprentenice_Id),
							Data = db_agent:get_master_charts(PlayerStatus#player.id),
							[_Id,Master_id,_Master_name,_Master_lv,_Realm,_Career,Award_count,Score_lv,Appre_num,_Regist_time,_Lover_type,_Sex,_Online] = Data,
							case Status == 3 of
								true -> skip;
								false -> %%只有当状态不为学徒和出师的徒弟退出时才减少师门人数
									db_agent:update_master_charts(Award_count,Score_lv,Appre_num-1,Master_id)
							end,
							gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', 28003, 1}),%%删除玩家的决裂书
							Content2 = io_lib:format("【~s已经 把您逐出师门】",[tool:to_list(PlayerStatus#player.nickname)]),
							mod_mail:send_sys_mail([tool:to_list(Apprentenice_name1)],"系统信件",Content2, 0, 0, 0, 0, 0),
							1
					end;
				2 ->%%删除申请状态中的徒弟记录
							Status1 = db_agent:get_master_apprentice_properties(status,Apprentenice_Id),
							case Status1 == 3 of
								false -> 0;%%用师徒决裂可以删除徒弟
								true ->
									db_agent:del_master_apprentice(Apprentenice_Id),
									%%删除缓存中的师徒关系中的数据,减少伯乐表中对应的数人
									ets:delete(?ETS_MASTER_APPRENTICE,Apprentenice_Id),
									1
							end
	end.

%%返回某人未登陆系统的时间(天数)
calc_unlogin_time(Player_Id)->
	CurrentTime = util:unixtime(),
 	Last_login_Time = db_agent:get_player_properties(last_login_time,Player_Id),
	case Last_login_Time of
		null -> 
			CurrentTime/24/60/60;
		_ ->
			(CurrentTime-Last_login_Time)/24/60/60
	end.

%%返回某人未汇报的时间(天数)
calc_unreport_time(Player_Id)->
	CurrentTime = util:unixtime(),
	Result = db_agent:get_master_apprenticetimes(Player_Id),
	case Result == [] of
		true -> 0;
		false ->
			[Join_time, Last_report_time] = Result,
			case Last_report_time == [] orelse Last_report_time == 0 of
				true ->
					(CurrentTime-Join_time)/24/60/60;
				false ->
					(CurrentTime-Last_report_time)/24/60/60
			end
	end.
	

%%组装更新缓存师徒关系的数据
match_ets_master_apprentice(Ets_master_apprentice)->
	[Id,Apprentenice_id,Apprentenice_name,Master_id,Lv,Career,Status,Report_lv,Join_time,Last_report_time,Sex] = Ets_master_apprentice,
	EtsData = #ets_master_apprentice{
	  							id = Id,	
      							apprentenice_id = Apprentenice_id,
								apprentenice_name = Apprentenice_name,
								master_id = Master_id,
								lv = Lv,
								career = Career,
								status = Status,
								report_lv = Report_lv,
								join_time = Join_time,
								last_report_time = Last_report_time,
								sex = Sex
							},
	EtsData.

%%组装更新缓存伯乐表的数据
match_ets_master_charts(Ets_master_charts)->
	[Id,Master_id,Master_name,Master_lv,Realm,Career,Award_count,Score_lv,Appre_num,Regist_time,Lover_type,Sex,Online] = Ets_master_charts,
	EtsData = #ets_master_charts{
								id = Id,	
      							master_id = Master_id,
								master_name = Master_name,
								master_lv = Master_lv,
								realm = Realm,
								career = Career,
								award_count = Award_count,
								score_lv = Score_lv,
								appre_num = Appre_num,
								regist_time = Regist_time,
								lover_type = Lover_type,
								sex = Sex,
								online=Online
							},
	EtsData.
				  
%%查询某师傅未出师的徒弟数量				  
get_ungraduate_apprentice_count(Master_Id) ->
	Pattern = #ets_master_apprentice{master_id=Master_Id,status=2,_='_'},
	Data = match_all(?ETS_MASTER_APPRENTICE, Pattern),
	length(Data).
				
%%查询某师傅申请中的徒弟数量				  
get_applying_apprentice_count(Master_Id) ->
	Pattern = #ets_master_apprentice{master_id=Master_Id,status=3,_='_'},
	Data = match_all(?ETS_MASTER_APPRENTICE, Pattern),
	length(Data).

%%查询某师傅已出师的徒弟数量				  
get_finish_apprenticeship_count(Master_Id) ->
	Pattern = #ets_master_apprentice{master_id=Master_Id,status=1,_='_'},
	Data = match_all(?ETS_MASTER_APPRENTICE, Pattern),
	length(Data).
				
%%是否有师傅
is_exist_master(Player_Id) ->
%% MasterId = get_own_master_id(Player_Id),
	Pattern1 = #ets_master_apprentice{apprentenice_id=Player_Id,status=1,_='_'},
	Result1 = match_all(?ETS_MASTER_APPRENTICE, Pattern1),
	Pattern2 = #ets_master_apprentice{apprentenice_id=Player_Id,status=2,_='_'},
	Result2 = match_all(?ETS_MASTER_APPRENTICE, Pattern2),
	case Result1 == [] andalso Result2 == [] of
		true -> false;
		false -> true
	end.

%%判断某人是否在伯乐表中
exist_master_charts(Master_Id) ->
	db_agent:get_master_charts(Master_Id).
	
match_all(Table, Pattern) ->
    ets:match_object(Table, Pattern).

%%查询同门师兄弟列表
get_master_apprentice_info_page(Player_Id) ->
	Data = get_all_master_apprentice(Player_Id),
	Data1 = get_own_info(Player_Id),
	handResult(Player_Id,Data,Data1).

%%查询我的徒弟列表
get_my_apprentice_info_page(Player_Id) ->
	Pattern = #ets_master_apprentice{master_id=Player_Id,_='_'},
	Data = match_all(?ETS_MASTER_APPRENTICE, Pattern),
	handResult(Player_Id,Data).

%%我的徒弟列表
handResult(_Player_Id,Data) ->
	case Data of
				[] ->
					[];
				_ ->
					F = fun(R)->
								[{_Ets_master_apprentice,_Id,Apprentenice_id,Apprentenice_name,_Master_id,Lv,Career,Status,Report_lv,Join_time,Last_report_time,Sex}] = [R],
								Realtion = 
								case Status == 3 of
									true -> 8;%%申请中
									false -> 7%%徒弟
								end,
								Report_lv1 = Lv-Report_lv,
								Report_lv2 = 
									case Status == 3 of
										true -> 0;%%申请中等级可汇报为0 
										false -> Report_lv1%%徒弟
									end,
								Report_lv3 = 
								case Lv > ?FINISHED_MASTER_LV of
									true -> 0;
									false ->Report_lv2
								end,
								[Apprentenice_id,Apprentenice_name,Lv,Career,Sex,Realtion,Status,Report_lv3,Join_time,Last_report_time,is_on_line(Apprentenice_id)]
						end,
					[F(R) || R <- Data]
			end.

%%我的同门师兄弟列表
handResult(Player_Id,Data,Data1) ->
	case Data1 of
		[] ->
			[];
		_ ->
			case Data of
				[] ->
					[];
				_ ->
					F = fun(R)->
								Master_id2 = get_own_master_id(Player_Id),
								[{_Ets_master_apprentice,_Id,Apprentenice_id,Apprentenice_name,_Master_id,Lv,Career,Status,Report_lv,Join_time,Last_report_time,Sex}] = [R],
								[{_Ets_master_apprentice1,_Id1,_Apprentenice_id1,_Apprentenice_name1,_Master_id1,_Lv1,_Career1,_Status1,_Report_lv1,Join_time1,_Last_report_time1,Sex1}] = Data1,
								Realtion = 
									case Apprentenice_id == Player_Id of %%先判断是否是自己
										true ->	6;
										false -> %%自己与其他人的关系
											case Master_id2 == Apprentenice_id of 
												true -> 1;%%是师傅
												false ->
													case Sex1 of
														1 -> %%男性
															case Sex of
																1 -> %%师兄师弟
																	case Join_time1 > Join_time of
																		true ->2;%%师弟
																		false ->4%%师兄
																	end;
																2 -> %%师姐师妹
																	case Join_time1 > Join_time of
																		true ->3;%%师妹
																		false ->5%%师姐
																	end
															end;
														2 -> %%女性
															case Sex of
																1 -> %%师兄师弟
																	case Join_time1 > Join_time of
																		true ->2;%%师弟
																		false ->4%%师兄
																	end;
																2 -> %%师姐师妹
																	case Join_time1 > Join_time of
																		true ->3;%%师妹
																		false ->5%%师姐
																	end
															end																	
													end
											end
									end,
								Realtion1 =
									case Status == 3 of
										true -> 8;
										false -> Realtion
									end,
								Report_lv1 = Lv-Report_lv,
								Report_lv2 = 
									case Status == 3 of
										true -> 0;%%申请中可汇报等级为0
										false -> Report_lv1%%徒弟
									end,
								Report_lv3 = 
								case Lv > ?FINISHED_MASTER_LV of
									true -> 0;
									false ->Report_lv2
								end,
								[Apprentenice_id,Apprentenice_name,Lv,Career,Sex,Realtion1,Status,Report_lv3,Join_time,Last_report_time,is_on_line(Apprentenice_id)]
						end,
					[F(R) || R <- Data]
			end
	end.

%%即时更新师傅表和伯乐表中的lv,Master_lv
update_masterAndApprenteniceLv(PlayerStatus) ->
	Master_apprentice_Info = db_agent:get_master_apprentice_info(PlayerStatus#player.id),
	case Master_apprentice_Info == [] of
		true -> skip;
		false ->
			[Lv,Status,Master_id] = Master_apprentice_Info,
			Master_lv = db_agent:get_master_charts_properties(lv,PlayerStatus#player.id),
			case Lv  =/= PlayerStatus#player.lv andalso Lv  =/= null of 
				false -> skip;
				true ->
					case Master_id == null orelse Master_id == 0 of
						true -> %%表示是师傅，直接更新层级，和汇报层级，保持两等级一致
							db_agent:update_master_apprentice_lv_report(PlayerStatus#player.lv,PlayerStatus#player.lv,PlayerStatus#player.id),
							Data_master_apprentice1 = db_agent:get_master_apprentice(PlayerStatus#player.id),%%更新缓存
							insert_ets_master_apprentice(Data_master_apprentice1);
						false -> %%表示是徒弟，直接更新层级，并推送信息到客户端
							db_agent:update_master_apprentice_lv(PlayerStatus#player.lv,PlayerStatus#player.id),
							EtsData = get_own_info(PlayerStatus#player.id),
							[{_Ets_master_apprentice,Id1,Apprentenice_id1,Apprentenice_name1,Master_id1,_Lv1,Career1,Status1,Report_lv1,Join_time1,Last_report_time1,Sex1}] = EtsData,
							EtsData1 = #ets_master_apprentice{
														id = Id1,	
														apprentenice_id = Apprentenice_id1,
														apprentenice_name = Apprentenice_name1,
														master_id = Master_id1,
														lv = PlayerStatus#player.lv,
														career = Career1,
														status = Status1,
														report_lv = Report_lv1,
														join_time = Join_time1,
														last_report_time = Last_report_time1,
														sex = Sex1
													},	
							ets:insert(?ETS_MASTER_APPRENTICE,EtsData1),
							case Lv =< ?FINISHED_MASTER_LV of %%小于等于40级才发送消息且不是申请状态的徒弟
								false -> skip;
								true ->
									case Status =/= 3 of %%申请中的徒弟不发送升级信息到客户端
										false -> skip;
										true -> pp_master_apprentice:handle(27012, PlayerStatus, PlayerStatus#player.id)%%将升级信息推送到客户端
									end
							end,
							prize(PlayerStatus)
					end
			end,
			case Master_lv  =/= PlayerStatus#player.lv andalso Master_lv =/= null of 
				false -> skip;
				true ->
					db_agent:update_master_charts_masterlv(PlayerStatus#player.lv,PlayerStatus#player.id)
			end
	end.

%%徒弟升级到20,30,40级后徒弟和师傅增加相应的奖励
prize(PlayerStatus) ->
	ApprenteniceData = get_own_info(PlayerStatus#player.id),
	case ApprenteniceData of
		[] -> skip;
		_ -> 
			[{_Ets_master_apprentice,_Id,_Apprentenice_id,_Apprentenice_name,Master_id,Lv,Career,Status,_Report_lv,_Join_time,_Last_report_time,_Sex}] = ApprenteniceData,
			case Status == 2 andalso Master_id =/= 0 of %%只有徒弟状态为学徒中时才能增加徒弟，师傅的奖励
				false -> skip;
				true ->
					Master_name = db_agent:get_master_charts_properties(master_name,Master_id),
					case Lv of
						20 ->
							Content1 = io_lib:format("【徒弟~s升到20级，奖励绑定蓝色鉴定石二个】",[tool:to_list(PlayerStatus#player.nickname)]),
							lib_goods:add_new_goods_by_mail(tool:to_list(PlayerStatus#player.nickname),prize_apprentenice(Career,Lv),2,2,"系统信件",Content1),
							Content2 = io_lib:format("【徒弟~s升到20级，奖励师傅~s中级灵力丹一个】",[tool:to_list(PlayerStatus#player.nickname),tool:to_list(Master_name)]),
							lib_goods:add_new_goods_by_mail(tool:to_list(Master_name),23301,2,1,"系统信件",Content2);
						30 ->
							Content1 = io_lib:format("【徒弟~s升到30级，升到30级，奖励27级金装一件】",[tool:to_list(PlayerStatus#player.nickname)]),
 							lib_goods:add_new_goods_by_mail(tool:to_list(PlayerStatus#player.nickname),prize_apprentenice(Career,Lv),2,1,"系统信件",Content1),
							Content2 = io_lib:format("【徒弟~s升到30级，奖励师傅~s大灵力丹一个】",[tool:to_list(PlayerStatus#player.nickname),tool:to_list(Master_name)]),
							lib_goods:add_new_goods_by_mail(tool:to_list(Master_name),23302,2,1,"系统信件",Content2);
						_ -> skip
					end
			end
	end.


%%根据徒弟职业选择相应的奖励
prize_apprentenice(Career,Lv) ->
%%15155麒麟/14155朱雀/13155青龙/12155白虎/11155玄武
	case Career of
		1 -> %%玄武
			case Lv of
				20 -> 21001;
				30 -> 11148
			end;
		2 -> %%白虎
			case Lv of
				20 -> 21001;
				30 -> 12148
			end;
		3 -> %%青龙
			case Lv of
				20 -> 21001;
				30 -> 13148
			end;
		4 -> %%朱雀
			case Lv of
				20 -> 21001;
				30 -> 14148
			end;
		5 -> %%麒麟
			case Lv of
				20 -> 21001;
				30 -> 15148
			end;
		_ -> skip
	end.

add_goods_prize(Player_Id,Goods_Id,Num) ->
	PlayerStatus = lib_player:get_online_info(Player_Id),
	Location = 4,
	Cell = 0,
	GoodsTypeInfo = goods_util:get_goods_type(Goods_Id),
	NewInfo = goods_util:get_new_goods(GoodsTypeInfo),
	NewGoodsInfo = NewInfo#goods{ player_id = Player_Id, location = Location, cell = Cell, num = Num },
%% 	GoodsPid = PlayerStatus#player.other#player_other.pid_goods,
%% 	GoodsStatus = gen_server:call(GoodsPid, {'STATUS'}),
	case PlayerStatus == [] of %%如果角色在线，添加物品，如果不在线，则直接在数据库中添加记录，角色登陆会加载插入数据
		false -> %%角色在线
			lib_goods:add_goods(NewGoodsInfo);
		true -> %%角色不在线
			db_agent:add_goods(NewGoodsInfo),
			NewGoodsInfo1 = goods_util:get_add_goods(NewGoodsInfo#goods.player_id,
											NewGoodsInfo#goods.goods_id,
											NewGoodsInfo#goods.location,
											NewGoodsInfo#goods.cell,
											NewGoodsInfo#goods.num),
			lib_goods:add_attribule_by_type(NewGoodsInfo1)
	end,
	[Gid] = db_agent:get_add_goods_id(Player_Id, Goods_Id, Location, Cell, Num),
	Gid.

%%是否需要汇报
is_need_report(PlayerStatus) ->
	Pattern = #ets_master_apprentice{apprentenice_id=PlayerStatus#player.id,_='_'},
	Data = match_all(?ETS_MASTER_APPRENTICE, Pattern),
	case Data of 
		[] -> 0; %%不汇报
		_ ->
			[{_Ets_master_apprentice,_Id,_Apprentenice_id,_Apprentenice_name,_Master_id,_Lv,_Career,_Status,Report_lv,_Join_time,_Last_report_time,_Sex}] = Data,
			case PlayerStatus#player.lv > Report_lv of
				false -> 0;
				true -> 1
			end
	end.

%%汇报
report_lv(PlayerStatus) ->
	MasterId = get_own_master_id(PlayerStatus#player.id),
	MasterData = db_agent:get_master_charts(MasterId),
	Status = db_agent:get_master_apprentice_properties(status,PlayerStatus#player.id),
	case Status == 2 of %%只有学徒才能汇报
		false -> [2,2,0,0];%%不是学徒，不能汇报等级
		true ->
			case lib_player:is_online(MasterId) of
				false ->
					[0,2,0,0];%%师傅不在线
				_ -> %%师徒两人都增加经验值和灵力
					Report_lv = db_agent:get_master_apprentice_properties(report_lv,PlayerStatus#player.id),
					Lv = PlayerStatus#player.lv,
					case Lv =< Report_lv of
						true -> [3,2,0,0];%%不需要汇报
						false ->
							Exp = calu_exp_by_lv(Report_lv,Lv),
							Spirit = Exp,
							CurrentTime = util:unixtime(),
							[_Id,Master_id,_Master_name,_Master_lv,_Realm,_Career,Award_count,Score_lv,Appre_num,_Regist_time,_Lover_type,_Sex,_Online] = MasterData,
							db_agent:update_master_charts(Award_count+(Lv-Report_lv),Score_lv+(Lv-Report_lv),Appre_num,Master_id),%%增加师傅师道值，
							db_agent:update_master_apprentice_reportlv(Report_lv+(Lv-Report_lv),CurrentTime,PlayerStatus#player.id),%%更新徒弟的汇报等级
							MasterStatus = lib_player:get_online_info(MasterId),%%师傅在线状态
							case MasterStatus of 
								[] -> [0,2,0,0];%%师傅不在线
								_ ->
									%%	NewPlayerStatus = lib_player:add_exp(PlayerStatus, round(Exp*0.005), round(Spirit*0.0025),3),
									%%NewMasterStatus = lib_player:add_exp(MasterStatus, round(Exp*0.0025), round(Spirit*0.00125),3),
									gen_server:cast(PlayerStatus#player.other#player_other.pid,{'EXP', round(Exp*0.012), round(Spirit*0.012),3}),
									gen_server:cast(MasterStatus#player.other#player_other.pid,{'EXP', round(Exp*0.0067), round(Spirit*0.0067),3}),
									EtsData = get_own_info(PlayerStatus#player.id),
									[{_Ets_master_apprentice,Id1,Apprentenice_id1,Apprentenice_name1,Master_id1,Lv1,Career1,Status1,_Report_lv1,Join_time1,_Last_report_time1,Sex1}] = EtsData,
									EtsData1 = #ets_master_apprentice{
																	 id = Id1,	
																	 apprentenice_id = Apprentenice_id1,
																	 apprentenice_name = Apprentenice_name1,
																	 master_id = Master_id1,
																	 lv = Lv1,
																	 career = Career1,
																	 status = Status1,
																	 report_lv = Lv1,
																	 join_time = Join_time1,
																	 last_report_time = CurrentTime,
																	 sex = Sex1
																	},									
									ets:insert(?ETS_MASTER_APPRENTICE,EtsData1),
									[1,1,Exp,Spirit]
							end
					end
			end
	end.

%%计算两个等级间的经验差
calu_exp_by_lv(Report_lv,Lv) ->
	F = fun(I) -> data_exp:get(I) end,
	LvList = [F(I) || I <- lists:seq(Report_lv+1,Lv)],
	Exp = lists:sum(LvList),
	Exp.

	
%%出师
finish_apprenticeship(Player_Id) ->
	ApprenteniceData = get_own_info(Player_Id),
	case ApprenteniceData ==[] of
		true -> [1,3]; %%没有拜师
		false -> 
			[{_Ets_master_apprentice,_Id,Apprentenice_id,_Apprentenice_name,Master_id,Lv,_Career,Status,_Report_lv,_Join_time,_Last_report_time,_Sex}] = ApprenteniceData,
			if Status == 1 ->
				   [1,4];%%您已经出师
			   Status == 0 ->
				   [1,3];%%您没有拜师
 			   Status == 3 ->
				   [1,3];%%您没有拜师
			   true ->
				   case Lv =/= null andalso Lv >= ?FINISHED_MASTER_LV of
					   false -> [1,2];%%等级未达40级				
					   true -> %%成功出师，修改徒弟的状态为1已出师，并更新缓存
						   db_agent:update_master_apprentice_statu_reportlv(1,Lv,Apprentenice_id),
						   Data_master_apprentice = db_agent:get_master_apprentice(Player_Id),
						   if Data_master_apprentice == [] ->
								   [1,3];%%您没有拜师
							  true ->
								  insert_ets_master_apprentice(Data_master_apprentice),
								  %%每出师一个徒弟，师傅增加师道值10+(出师徒弟总数-1)*2
							      FinishApprenticeshipNum = get_finish_apprenticeship_count(Master_id),
								  MasterData = db_agent:get_master_charts(Master_id),
								  [_Id1,_Master_id1,_Master_name1,_Master_lv1,_Realm1,_Career1,Award_count1,Score_lv1,Appre_num1,_Regist_time1,_Lover_type1,_Sex1,_Online] = MasterData,
								  db_agent:update_master_charts(Award_count1+10+(FinishApprenticeshipNum-1)*2,Score_lv1,Appre_num1,Master_id),%%增加师傅师道值，
						  		  %%添加成就系统
								  case FinishApprenticeshipNum of
									  1-> lib_achieve:check_achieve_finish_cast(Master_id, 601, [1]);
									  2 -> lib_achieve:check_achieve_finish_cast(Master_id, 602, [2]);
									  3 -> lib_achieve:check_achieve_finish_cast(Master_id, 603, [3]);
									  _ -> skip
								  end,
								  [2,1]
						   end
				   end
			end
	end.

%%判断某人是否在线
is_on_line(Player_Id) ->
	Pid = lib_player:get_player_pid(Player_Id),
	case Pid of 
		[] -> 0;
		_ -> 1
	end.

%%从内在表中取得指定玩家的等级
get_role_lv(Player_Id) ->
	db_agent:get_role_lv(Player_Id).

%%查询师傅，及状态为1(已出师)或2(未出师)的所有师门记录
get_all_master_apprentice(Player_Id) ->
	ApprenteniceData = get_own_info(Player_Id),
	if ApprenteniceData == [] ->
		   [];
	   true ->
		   [{_Ets_master_apprentice,_Id,_Apprentenice_id,_Apprentenice_name,Master_id,_Lv,_Career,Status,_Report_lv,_Join_time,_Last_report_time,_Sex}] = ApprenteniceData,
		   if Status == 0 ->
				  [];
			  true ->
				  Data = get_own_info(Master_id),%%师傅在师徒表中的数据
				  Pattern1 = #ets_master_apprentice{master_id=Master_id,status=1,_='_'},
				  Data1 = match_all(?ETS_MASTER_APPRENTICE, Pattern1),
				  Pattern2 = #ets_master_apprentice{master_id=Master_id,status=2,_='_'},
				  Data2 = match_all(?ETS_MASTER_APPRENTICE, Pattern2),
				  Pattern3 = #ets_master_apprentice{master_id=Master_id,status=3,_='_'},
				  Data3 = match_all(?ETS_MASTER_APPRENTICE, Pattern3),
				  Data++Data1++Data2++Data3
		   end
	end.

%%-----------------------------------------------
%%师徒关系内部函数
%%-----------------------------------------------
%% 更新师徒关系缓存表
ets_insert_master_apprentice(MastApprRecordEts) ->
	ets:insert(?ETS_MASTER_APPRENTICE, MastApprRecordEts).	

%%更新师徒信息角色名
change_player_name(PlayerId,NickName) ->
	Pattern = #ets_master_apprentice{apprentenice_id=PlayerId,_='_'},
	Data = match_all(?ETS_MASTER_APPRENTICE, Pattern),
	case Data of
		[] -> skip;
		_ ->
			ETS_APPRENTICE = lists:nth(1, Data),
			EtsData = ETS_APPRENTICE#ets_master_apprentice{apprentenice_name = NickName},
			ets_insert_master_apprentice(EtsData),
			db_agent:change_master_apprentice_name(PlayerId,NickName)
	end,
	db_agent:change_master_charts_name(PlayerId,NickName).
