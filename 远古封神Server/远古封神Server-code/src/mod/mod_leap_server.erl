%%%------------------------------------
%%% @Module  : mod_leap_server
%%% @Author  : ygfs
%%% @Created : 2011.10.04
%%% @Description: 跨服通信服务端模块
%%%------------------------------------
-module(mod_leap_server).

-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export(
    [
   		start_link/1,
		get_mod_leap_server_pid/0,
		notice_syn_data_fir/0,
		notice_syn_data_sec/2,
		remote_server_msg/1,
		remote_server_msg_by_sn/3,
		war_award/4,
		war_record/1,
		clear_database/0,
		socket_state/1,
		syn_equip/3,
		syn_award_to_remore/5,
		war2_elimination/1,
		elimination_history/4,
		elimination_champion/1,
		notice_war2_award/0,
		notice_bet_provide/0,
		sync_war2_state/1,
		sync_war2_bet/1,
		sync_war2_pape/1,
		sync_war_rank/1,
		answer_war_rank/1,
		test/0
    ]
).

-record(state, {
	socket_list = [],												%% socket接口
	server_list = []				
}). 

-define(Opt, [binary, {packet, 4}, {reuseaddr, true}, {active, true}]).
-define(Port, 9098).

%% 启动跨服通信服务端模块
start_link(ProcessName) ->
  	gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName], []).

init([ProcessName]) ->
	Self = self(),
	State = #state{},
	case misc:register(unique, ProcessName, Self) of
		yes ->
			case lib_war:is_war_server() of
				true->
					Port = 
						case config:get_war_server_mark() of
							0->9099;
							Other->Other
						end,
					case gen_tcp:listen(Port, ?Opt) of
  						{ok,Listen} ->
   							spawn(fun()-> par_connect(Listen, Self) end);
  						_Other ->
   							io:format("listion error:~p~n", [_Other])
 					end;
				false->skip
			end,
%% 					io:format("9.init war sync server data finish~n"),
			{ok, State};
		_ ->
			{stop, normal, State}
	end.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% 添加客户端连接的SOCKET
handle_info({'ADD_CLIENT_SOCKET', Socket}, State) ->
	NewState = State#state{
		socket_list = [Socket | State#state.socket_list]
	},
	{noreply, NewState};

%% 添加客户端连接的SOCKET
handle_info({'CLIENT_INFO', Socket, Platform, ServerNum}, State) ->
	Key = lists:concat([Platform, "_", ServerNum]), 
	Data = {Key, Platform, ServerNum, Socket},
	case lists:keyfind(Key, 1, State#state.server_list) of
		false->
			NewState = State#state{server_list = [Data | State#state.server_list]};
		_SocketInfo ->
			ServerList = lists:keyreplace(Key, 1, State#state.server_list, Data),
			NewState = State#state{server_list = ServerList}
	end,
	{noreply, NewState};

%%给各服发送消息 
handle_info({'CLIENT_SOCKET_SEND', [Bindata]}, State) ->
	client_socket_send(State#state.server_list, Bindata),
	{noreply, State};

%%给指定的服务器发送消息
handle_info({'CLIENT_SOCKET_SEND_BY_SN', [Platform,Sn,Bindata]}, State) ->
	client_socket_send_by_sn(State#state.server_list, Platform,Sn,Bindata),
	{noreply, State};


%%通知各服同步数据
handle_info({'NOTICE_SYN_DATA',[Bindata]},State)->
	erlang:send_after(1*1000,self(),{'SYN_DATA',[State#state.server_list,Bindata]}),
	{noreply,State};

handle_info({'SYN_DATA',[SocketList,Bindata]},State)->
	case SocketList of
		[]->
%% 			io:format("notice syn data finish!!!!!~p~n",[util:unixtime()]),
			skip;
		_->
			[{_,_P,_S,Socket}|NewSocketList] = SocketList,
%% 			io:format("P_S>>>>>~p/~p~n",[P,S]),
			spawn(fun()-> gen_tcp:send(Socket, Bindata) end),
			erlang:send_after(5*1000,self(),{'SYN_DATA',[NewSocketList,Bindata]})
	end,
	{noreply,State};

%%查看socket连接信息
handle_info({'SOCKET_STATE',Type},State)->
	case Type of
		1->
			io:format("socket state>>>>~p_~p~n",[length(State#state.server_list),State#state.server_list]);
		_->
			io:format("socket state>>>>~p_~p~n",[length(State#state.socket_list),State#state.socket_list])
	end,
	{noreply,State};

handle_info(_Info, State) ->
%io:format("kdsfjlsdjfl ~p~n", [_Info]),
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
  	{ok, State}.

par_connect(Listen, Pid) ->
 	{ok, Socket} = gen_tcp:accept(Listen),
	Pid ! {'ADD_CLIENT_SOCKET', Socket},
 	spawn(fun()-> par_connect(Listen, Pid) end),
 	loop(Socket).

loop(Socket) ->
 	receive
  		{tcp, Socket, Bin} -> 
			<<Cmd:32, DataBin/binary>> = Bin,
			case Cmd of
				%%参赛玩家数据同步（服务器）
				45040 ->
					NewDataBin = zlib:uncompress(DataBin),
					Data = util:string_to_term(binary_to_list(NewDataBin)),
					[Platform,Sn,PlayerBag] = Data,
					mod_war_supervisor:had_syn_data(Platform,Sn),
					syn_data(PlayerBag),
					ok;
				%%玩家数据同步（个人）
				45045->
%% 					io:format("Cmd>>>>>>>>>>>>>~p~n",[Cmd]),
					NewDataBin = zlib:uncompress(DataBin),
					Data = util:string_to_term(binary_to_list(NewDataBin)),
					[Platform,Sn,NickName,PlayerBag] = Data,
					syn_player_data(Platform,Sn,NickName,PlayerBag),
					ok;
				%%更新玩家个人信息
				45046->
%% 					io:format("Cmd>>>>>>>>>>>>>~p~n",[Cmd]),
					NewDataBin = zlib:uncompress(DataBin),
					Data = util:string_to_term(binary_to_list(NewDataBin)),
					[Platform,Sn,NickName,PlayerBag] = Data,
					update_player_data(Platform,Sn,NickName,PlayerBag),
					ok;
				%%删除玩家信息
				45047->
					NewDataBin = zlib:uncompress(DataBin),
					Data = util:string_to_term(binary_to_list(NewDataBin)),
					[Platform,Sn,NickName,AccId,AccName] = Data,
					del_player_data(Platform,Sn,NickName,AccId,AccName),
					ok;
				%%同步战斗力
				45048->
					NewDataBin = zlib:uncompress(DataBin),
					Data = util:string_to_term(binary_to_list(NewDataBin)),
					[Platform,Sn,NickName,Att] = Data,
					update_player_att(Platform,Sn,NickName,Att),
					ok;
				%% 获取客户端IP、平台信息
				45041 ->
					Data = util:string_to_term(binary_to_list(DataBin)),
					{platform, Platform} = lists:keyfind(platform, 1, Data),
					{server_num, ServerNum} = lists:keyfind(server_num, 1, Data),
					Pid = mod_leap_server:get_mod_leap_server_pid(),
					spawn(fun()-> gen_tcp:send(Socket, DataBin) end),
					Pid ! {'CLIENT_INFO', Socket, Platform, ServerNum};
				%%同步玩家装备信息
				45032 ->
%% 					io:format("45032>>>>>~n"),
					NewDataBin = zlib:uncompress(DataBin),
					Data = util:string_to_term(binary_to_list(NewDataBin)),
					syn_player_equip(Data),
					ok;
				%%单人竞技同步玩家信息
 				45201->
%% 					io:format("Cmd>>>>>>>>>>>>>~p~n",[Cmd]),
					NewDataBin = zlib:uncompress(DataBin),
					Data = util:string_to_term(binary_to_list(NewDataBin)),
					[Platform,Sn,NickName,PlayerBag] = Data,
					war2_sync_player(Platform,Sn,NickName,PlayerBag),
					ok;
				%%单人竞技更新玩家信息
				45202->
%% 					io:format("Cmd>>>>>>>>>>>>>~p~n",[Cmd]),
					NewDataBin = zlib:uncompress(DataBin),
					Data = util:string_to_term(binary_to_list(NewDataBin)),
					[Platform,Sn,NickName,PlayerBag] = Data,
					war2_update_player(Platform,Sn,NickName,PlayerBag),
					ok;
				%%参赛玩家人气增加
				45207->
					Data = util:string_to_term(binary_to_list(DataBin)),
					mod_war2_supervisor:bet_popular(Data);
				%%跨服战力排行请求
				45214->
					Data = util:string_to_term(binary_to_list(DataBin)),
					gen_server:cast(mod_rank:get_mod_rank_pid(),{answer_war_rank,Data});
				_ ->
					skip
			end,
   			loop(Socket);
  		{tcp_closed, _Socket} ->
			skip
%%    			io:format("~w error~n", [Socket])
 	end.

%% 获取跨服通信进程
get_mod_leap_server_pid() ->
	ProcessName = mod_leap_server_mark,
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true ->
					Pid;
				false ->
					start_mod_leap_server(ProcessName)
			end;
		_ ->
			start_mod_leap_server(ProcessName)			
	end.

%% 开启跨服通信进程
start_mod_leap_server(ProcessName) ->
	global:set_lock({ProcessName, undefined}),
	ProcessPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->	
						Pid;		
					false ->
						start_leap_server(ProcessName)
				end;
			_ ->
				start_leap_server(ProcessName)
		end,
	global:del_lock({ProcessName, undefined}),
	ProcessPid.
start_leap_server(ProcessName) ->
	ChildSpec = {
		mod_leap_server,
      	{
			mod_leap_server, 
			start_link,
			[ProcessName]
		},
   		permanent, 
		10000, 
		supervisor, 
		[mod_leap_server]
	},
	case supervisor:start_child(yg_server_sup, ChildSpec) of
		{ok, Pid} ->
			Pid;
		_ ->
			undefined
	end.

%% 给各客户端服务器发送信息
client_socket_send([], _Bindata) ->
	ok;
client_socket_send([{_,_,_,Socket} | S], Bindata) ->
	spawn(fun()-> gen_tcp:send(Socket, Bindata) end),
	client_socket_send(S, Bindata).

%%给指定的平台客户端发送消息
client_socket_send_by_sn(SocketList,Platform,Sn,BinData)->
	Plat = tool:to_list(Platform),
	Key = lists:concat([Plat, "_", Sn]),
	case lists:keyfind(Key, 1, SocketList) of
		false->skip;
		Info->
%% 			io:format("Platform,Sn>>>~p/~p~n",[Platform,Sn]),
			{_,_,_,Socket} = Info,
			spawn(fun()-> gen_tcp:send(Socket, BinData) end)
	end.

%%开始同步玩家数据
notice_syn_data_fir()->
	%%清理数据表
	clear_database(),
	Pid = get_mod_leap_server_pid(),
	Pid ! {'NOTICE_SYN_DATA',[<<45044:32,<<>>/binary>>]},
%% 	Pid ! {'CLIENT_SOCKET_SEND',[<<45044:32,<<>>/binary>>]},	
	ok.
notice_syn_data_sec(Platform,Sn)->
	Pid = get_mod_leap_server_pid(),
	Pid ! {'CLIENT_SOCKET_SEND_BY_SN',[Platform,Sn, <<45044:32,<<>>/binary>>]},
	ok.


%%同步玩家装备属性
syn_equip(Platform,Sn,NickName)->
	Pid = get_mod_leap_server_pid(),
	Msg1 = list_to_binary(util:term_to_string([NickName])),
	Pid ! {'CLIENT_SOCKET_SEND_BY_SN',[Platform,Sn, <<45032:32,Msg1/binary>>]},
	ok.

%%同步玩家积分
syn_award_to_remore(Platform,Sn,NickName,Point,Content)->
	Pid = get_mod_leap_server_pid(), 
	Msg1 = list_to_binary(util:term_to_string([NickName,Point,Content])),
	Pid ! {'CLIENT_SOCKET_SEND_BY_SN',[Platform,Sn, <<45050:32,Msg1/binary>>]},
	ok.

%%同步玩家淘汰赛历史记录
elimination_history(Platform,Sn,Nickname,Info)->
	Pid = get_mod_leap_server_pid(), 
	Msg1 = list_to_binary(util:term_to_string([Nickname,Info])),
	Pid ! {'CLIENT_SOCKET_SEND_BY_SN',[Platform,Sn, <<45204:32,Msg1/binary>>]},
	ok.

%%同步比分战报
sync_war2_pape(Data)->
	Pid = get_mod_leap_server_pid(), 
	Msg1 = list_to_binary(util:term_to_string(Data)),
	Pid ! {'CLIENT_SOCKET_SEND',[<<45212:32,Msg1/binary>>]},
	ok.

%%同步跨服战力排行榜
sync_war_rank(Data)->
	Pid = get_mod_leap_server_pid(), 
	Msg1 = list_to_binary(util:term_to_string(Data)),
	%%玩家数据需要压缩
	Bin = zlib:compress(Msg1),
	Pid ! {'CLIENT_SOCKET_SEND',[<<45213:32,Bin/binary>>]},
	ok.

%%同步单人竞技冠军
elimination_champion(Champion)->
	Pid = get_mod_leap_server_pid(),
	Msg1 = list_to_binary(util:term_to_string(Champion)),
	Pid ! {'CLIENT_SOCKET_SEND',[<<45206:32,Msg1/binary>>]},
	ok.

	
%%给各个平台服务器广播消息
remote_server_msg(Msg)->
	Pid = get_mod_leap_server_pid(),
	Msg1 = tool:to_binary(Msg),
	Pid ! {'CLIENT_SOCKET_SEND',[<<45030:32,Msg1/binary>>]},
	ok.

%%给指定的平台广播消息
remote_server_msg_by_sn(Platform,Sn,Msg)->
	Pid = get_mod_leap_server_pid(),
	Msg1 = tool:to_binary(Msg),
	Pid ! {'CLIENT_SOCKET_SEND_BY_SN',[Platform,Sn, <<45030:32,Msg1/binary>>]},
	ok.

%%给指定平台发送奖励信息
war_award(Platform,Sn,GoodsNum,Other)->
	Pid = get_mod_leap_server_pid(),
	Msg1 = list_to_binary(util:term_to_string([GoodsNum,Other])),
	Pid ! {'CLIENT_SOCKET_SEND_BY_SN',[Platform,Sn, <<45031:32,Msg1/binary>>]},
	ok.

%%发送跨服排行
answer_war_rank([Platform,Sn,Data])->
	Pid = get_mod_leap_server_pid(), 
	Msg1 = list_to_binary(util:term_to_string(Data)),
	%%玩家数据需要压缩
	Bin = zlib:compress(Msg1),
	Pid ! {'CLIENT_SOCKET_SEND_BY_SN',[Platform,Sn, <<45213:32,Bin/binary>>]},
	ok.

%%封神大会历史记录
%%协议号45042
war_record(RecordBag)->
	RecordBagBin = list_to_binary(util:term_to_string(RecordBag)),
	Bin = zlib:compress(RecordBagBin),
	Pid = get_mod_leap_server_pid(),
	Pid ! {'CLIENT_SOCKET_SEND',[<<45042:32,Bin/binary>>]},
	ok.

%%同步单人竞技淘汰赛记录
war2_elimination(EliminationBag)->
	RecordBagBin = list_to_binary(util:term_to_string(EliminationBag)),
	Bin = zlib:compress(RecordBagBin),
	Pid = get_mod_leap_server_pid(),
	Pid ! {'CLIENT_SOCKET_SEND',[<<45203:32,Bin/binary>>]},
	ok.

%%通知发放单人竞技奖励
notice_war2_award()->
	Pid = get_mod_leap_server_pid(),
	Pid ! {'CLIENT_SOCKET_SEND',[<<45205:32,<<>>/binary>>]},
	ok.

%%通知发放下注奖励
notice_bet_provide()->
	Pid = get_mod_leap_server_pid(),
	Pid ! {'CLIENT_SOCKET_SEND',[<<45208:32,<<>>/binary>>]},
	ok.

%%
sync_war2_state(S)->
	spawn(fun()->mod_war2_supervisor:cmd_change_war2_state(S)end),
	SBin = list_to_binary(util:term_to_string([S])),
	Pid = get_mod_leap_server_pid(),
	Pid ! {'CLIENT_SOCKET_SEND',[<<45210:32,SBin/binary>>]},
	ok.

sync_war2_bet(IsBet)->
	SBin = list_to_binary(util:term_to_string([IsBet])),
	Pid = get_mod_leap_server_pid(),
	Pid ! {'CLIENT_SOCKET_SEND',[<<45211:32,SBin/binary>>]},
	ok.
	
%查看Socket连接信息
socket_state(Type)->
	Pid = get_mod_leap_server_pid(),
	Pid ! {'SOCKET_STATE',Type}.

test() ->
	Pid = get_mod_leap_server_pid(),
	io:format("this is a war server test!!!!!!!!!!!!!~n"), 
	Pid ! {'CLIENT_SOCKET_SEND',[<<45030:32, <<"亲爱的玩家，封神大会即将打响！">>/binary>>]}.

syn_player_equip(Data)->
	case lists:keyfind(nickname,1,Data) of
		false->skip;
		{nickname,NickName}->
			case ?DB_MODULE:select_all(war_player,"pid",[{nickname,NickName}]) of
				[]->
%% 					io:format("can not find player id>>>~n"),
					skip;
				[PlayerId]->
					case lists:keyfind(equip_info, 1, Data) of
						false->skip;
						{equip_info, EquipInfoList}->
							?DB_MODULE:delete(goods,[{player_id,PlayerId}]),
							insert_equip_info(EquipInfoList, PlayerId),
							ok
					end
			end
	end,
	ok.

%%同步玩家数据（个人）
syn_player_data(Platform,Sn,NickName,Data)->
	case ?DB_MODULE:select_one(war_player, "pid", [{nickname, NickName},{platform,Platform},{sn,Sn}]) of
		null->
			case ?DB_MODULE:select_one(war2_record, "pid", [{nickname, NickName},{platform,Platform},{sn,Sn}]) of
				null->
					new_player_data(Data,1);
				PlayerId->update_war_record(PlayerId,1,Data)
			end;
		PlayerId->update_war_record(PlayerId,1,Data)
	end,
	ok.

update_war_record(PlayerId,Funtion,Data)->
	%%参战信息
	if Funtion ==1->
		   {war,WarInfo} = lists:keyfind(war, 1, Data),
		   insert_war_info(WarInfo, PlayerId);
	   true->
		   {war2,WarRecord} = lists:keyfind(war2, 1, Data),
		   insert_war2_record(WarRecord, PlayerId)
	end,
	ok.
war2_sync_player(Platform,Sn,NickName,Data)->
	case ?DB_MODULE:select_one(war2_record, "pid", [{nickname, NickName},{platform,Platform},{sn,Sn}]) of
		null->
			case ?DB_MODULE:select_one(war_player, "pid", [{nickname, NickName},{platform,Platform},{sn,Sn}]) of
				null->
					new_player_data(Data,2);
				PlayerId->update_war_record(PlayerId,2,Data)
			end;
		PlayerId->update_war_record(PlayerId,2,Data)
	end,
	ok.

new_player_data(Data,Funtion)->
	%%平台信息
	{platform,Platform} =  lists:keyfind(platform, 1, Data),
	%%账号信息
	{accinfo,AccInfo} =  lists:keyfind(accinfo, 1, Data),
	insert_acc_info(AccInfo),
	%% 人物信息
	{player, PlayerInfo} = lists:keyfind(player, 1, Data),
	{PlayerId,NewPlayer} = insert_player_info(PlayerInfo,Platform),
	%%称号信息
	{title,TitleInfo} = lists:keyfind(title,1,Data),
	insert_title_info(TitleInfo,PlayerId),
	%% 装备物品属性信息
	{equip_info, EquipInfoList} = lists:keyfind(equip_info, 1, Data),
	insert_equip_info(EquipInfoList, PlayerId),
	%%神器信息
	{deputy, DeputyList} = lists:keyfind(deputy, 1, Data),
	insert_deputy_equip(DeputyList,PlayerId),
	%% 宠物信息
	{pet, PetList} = lists:keyfind(pet, 1, Data),
	insert_pet_info(PetList, PlayerId),
	%% 经脉信息
	{meridian, MeridianInfo} = lists:keyfind(meridian, 1, Data),
	insert_meridian_info(MeridianInfo, PlayerId),
	%% 技能信息
	{skill, SkillInfo} = lists:keyfind(skill, 1, Data),
	insert_skill_info(SkillInfo, PlayerId),
	%%坐骑信息
	{mount,Mount} = lists:keyfind(mount,1,Data),
	insert_mount_goods(Mount,PlayerId),
	{mountskill,MountSkill} = lists:keyfind(mountskill,1,Data),
	insert_mount_skill(MountSkill,PlayerId),
	{hookconfig,HookConfig} = lists:keyfind(hookconfig, 1, Data),
	insert_hook_config(PlayerId,HookConfig),
	{fs_era,Era} =  lists:keyfind(fs_era, 1, Data),
	insert_fs_era(PlayerId,Era),
	{backup,Backup} = lists:keyfind(backup, 1, Data),
	insert_player_backup(Backup,PlayerId),
	%%参战信息
	if Funtion ==1->
		   {war,WarInfo} = lists:keyfind(war, 1, Data),
		   Id=insert_war_info(WarInfo, PlayerId);
	   true->
		   {war2,WarRecord} = lists:keyfind(war2, 1, Data),
		   Id=insert_war2_record(WarRecord, PlayerId)
	end,
	%%Id,PlayerId,NickName,Career,Realm,Lv,Sex,Platform,Sn,
	{Id,PlayerId,NewPlayer#player.career,NewPlayer#player.realm,NewPlayer#player.lv,NewPlayer#player.sex,NewPlayer#player.vip,0}.

%%更新个人信息
update_player_data(Platform,Sn,NickName,Data)->
%% 	io:format("update_player_data>>>>>~p/~p~n",[Platform,Sn]),
	case ?DB_MODULE:select_one(war_player, "pid", [{nickname, NickName},{platform,Platform},{sn,Sn}]) of
		null->
%% 			io:format("update_player_data can not find~n"), 
			{Id,PlayerId,Career,Realm,Lv,Sex,Vip,Att} = new_player_data(Data,1),
%% 			{Id,PlayerId,NickName,Career,Realm,Lv,Sex,Platform,Sn};
			mod_war_supervisor:update_to_team([Id,PlayerId,NickName,Career,Realm,Lv,Sex,Vip,Att,Platform,Sn]),
			ok;
		PlayerId-> 
%% 			io:format("update pid>>>>>>>>>~p~n",[PlayerId]),
			clear_datebase_player(PlayerId),
			%%平台信息
			{platform,PlatformInfo} =  lists:keyfind(platform, 1, Data),
			%% 人物信息
			{player, PlayerInfo} = lists:keyfind(player, 1, Data),
			update_player_info(PlayerInfo,PlatformInfo,PlayerId),
			%% 装备物品属性信息
			{equip_info, EquipInfoList} = lists:keyfind(equip_info, 1, Data),
			insert_equip_info(EquipInfoList, PlayerId),
			%%神器信息
			{deputy, DeputyList} = lists:keyfind(deputy, 1, Data),
			insert_deputy_equip(DeputyList,PlayerId),
			%% 宠物信息
			{pet, PetList} = lists:keyfind(pet, 1, Data),
			insert_pet_info(PetList, PlayerId),
			%% 经脉信息
			{meridian, MeridianInfo} = lists:keyfind(meridian, 1, Data),
			insert_meridian_info(MeridianInfo, PlayerId),
			%% 技能信息
			{skill, SkillInfo} = lists:keyfind(skill, 1, Data),
			insert_skill_info(SkillInfo, PlayerId),
			%%坐骑信息
			{mount,Mount} = lists:keyfind(mount,1,Data),
			insert_mount_goods(Mount,PlayerId),
			{mountskill,MountSkill} = lists:keyfind(mountskill,1,Data),
			insert_mount_skill(MountSkill,PlayerId),
			{fs_era,Era} =  lists:keyfind(fs_era, 1, Data),
			insert_fs_era(PlayerId,Era),
			{backup,Backup} = lists:keyfind(backup, 1, Data),
			insert_player_backup(Backup,PlayerId),
			ok
	end,
	ok.

war2_update_player(Platform,Sn,NickName,Data)->
	case ?DB_MODULE:select_one(war2_record, "pid", [{nickname, NickName},{platform,Platform},{sn,Sn}]) of
		null->
%% 			{Id,PlayerId,Career,Realm,Lv,Sex,Vip,Att} = new_player_data(Data),
%% 			mod_war_supervisor:update_to_team([Id,PlayerId,NickName,Career,Realm,Lv,Sex,Vip,Att,Platform,Sn]),
			ok;
		PlayerId-> 
			clear_datebase_player(PlayerId),
			%%平台信息
			{platform,PlatformInfo} =  lists:keyfind(platform, 1, Data),
			%% 人物信息
			{player, PlayerInfo} = lists:keyfind(player, 1, Data),
			update_player_info(PlayerInfo,PlatformInfo,PlayerId),
			%% 装备物品属性信息
			{equip_info, EquipInfoList} = lists:keyfind(equip_info, 1, Data),
			insert_equip_info(EquipInfoList, PlayerId),
			%%神器信息
			{deputy, DeputyList} = lists:keyfind(deputy, 1, Data),
			insert_deputy_equip(DeputyList,PlayerId),
			%% 宠物信息
			{pet, PetList} = lists:keyfind(pet, 1, Data),
			insert_pet_info(PetList, PlayerId),
			%% 经脉信息
			{meridian, MeridianInfo} = lists:keyfind(meridian, 1, Data),
			insert_meridian_info(MeridianInfo, PlayerId),
			%% 技能信息
			{skill, SkillInfo} = lists:keyfind(skill, 1, Data),
			insert_skill_info(SkillInfo, PlayerId),
			%%坐骑信息
			{mount,Mount} = lists:keyfind(mount,1,Data),
			insert_mount_goods(Mount,PlayerId),
			{mountskill,MountSkill} = lists:keyfind(mountskill,1,Data),
			insert_mount_skill(MountSkill,PlayerId),
			{fs_era,Era} =  lists:keyfind(fs_era, 1, Data),
			insert_fs_era(PlayerId,Era),
			{backup,Backup} = lists:keyfind(backup, 1, Data),
			insert_player_backup(Backup,PlayerId),
			ok
	end,
	ok.

%%更新人物表
update_player_info([],_Platform,_PlayerId)->skip;
update_player_info(PlayerInfo,Platform,PlayerId) ->
	Player = list_to_tuple([player | PlayerInfo]),
	Plat = tool:to_list(Platform),
	Name = tool:to_list(Player#player.nickname),
	NickName = tool:to_binary(lists:concat([Plat,Name])),
	NewPlayer = Player#player{nickname =NickName },
	ValueList = lists:nthtail(2, tuple_to_list(NewPlayer)),
    [id | FieldList] = record_info(fields, player),
	Data = pack_tuple(FieldList,ValueList,[]),
	?DB_MODULE:update(player, Data, [{id,PlayerId}]), 
	ok.

pack_tuple([],_ValueList,Info)->Info;
pack_tuple(_FieldList,[],Info)->Info;
pack_tuple([File|FieldList],[Value|ValueList],Info)-> 
	case lists:member(File,[scene,gold,coin,cash])of
		true->
		   pack_tuple(FieldList,ValueList,Info);
	   false->
			pack_tuple(FieldList,ValueList,[{File,Value}|Info])
	end.

%%同步玩家战斗力
update_player_att(Platform,Sn,NickName,Att)->
	spawn(fun()->?DB_MODULE:update(war_player,[{att,Att}], [{nickname, NickName},{platform,Platform},{sn,Sn}])end).

%%删除玩家信息
del_player_data(Platform,Sn,NickName,AccId,AccName)->
	case ?DB_MODULE:select_one(war_player, "pid", [{nickname, NickName},{platform,Platform},{sn,Sn}]) of
		null->skip;
		PlayerId->
			clear_database_player_all(PlayerId,AccId,AccName)
	end.
			
syn_data([])->ok;
syn_data([Data|DataBag])->
	%%平台信息
	{platform,Platform} =  lists:keyfind(platform, 1, Data),
	%%账号信息
	{accinfo,AccInfo} =  lists:keyfind(accinfo, 1, Data),
	insert_acc_info(AccInfo),
	%% 人物信息
	{player, PlayerInfo} = lists:keyfind(player, 1, Data),
	{PlayerId,_} = insert_player_info(PlayerInfo,Platform),
	%%称号信息
	{title,TitleInfo} = lists:keyfind(title,1,Data),
	insert_title_info(TitleInfo,PlayerId),
	%% 装备物品属性信息
	{equip_info, EquipInfoList} = lists:keyfind(equip_info, 1, Data),
	insert_equip_info(EquipInfoList, PlayerId),
	%%神器信息
	{deputy, DeputyList} = lists:keyfind(deputy, 1, Data),
	insert_deputy_equip(DeputyList,PlayerId),
	%% 宠物信息
	{pet, PetList} = lists:keyfind(pet, 1, Data),
	insert_pet_info(PetList, PlayerId),
	%% 经脉信息
	{meridian, MeridianInfo} = lists:keyfind(meridian, 1, Data),
	insert_meridian_info(MeridianInfo, PlayerId),
	%% 技能信息
	{skill, SkillInfo} = lists:keyfind(skill, 1, Data),
	insert_skill_info(SkillInfo, PlayerId),
	%%坐骑信息
	{mount,Mount} = lists:keyfind(mount,1,Data),
	insert_mount_goods(Mount,PlayerId),
	{mountskill,MountSkill} = lists:keyfind(mountskill,1,Data),
	insert_mount_skill(MountSkill,PlayerId),
	%%参战信息
	{war,WarInfo} = lists:keyfind(war, 1, Data),
	insert_war_info(WarInfo, PlayerId),
	{war2,WarRecord} = lists:keyfind(war2, 1, Data),
	insert_war2_record(WarRecord, PlayerId),
	{hookconfig,HookConfig} = lists:keyfind(hookconfig, 1, Data),
	insert_hook_config(PlayerId,HookConfig),
	{fs_era,Era} =  lists:keyfind(fs_era, 1, Data),
	insert_fs_era(PlayerId,Era),
	{backup,Backup} = lists:keyfind(backup, 1, Data),
	insert_player_backup(Backup,PlayerId),
	syn_data(DataBag).

%%插入账号信息
insert_acc_info([])->skip; 
insert_acc_info(AccInfo)->
	%%accid,accname,status,sn,ct
	[AccId,AccName,Status,Sn,Ct] = AccInfo,
	?DB_MODULE:insert(user, [accid,accname,status,sn,ct], [AccId,AccName,Status,Sn,Ct]),
	ok.
%% 插入人物信息
insert_player_info([],_Platform)->skip;
insert_player_info(PlayerInfo,Platform) ->
	Player = list_to_tuple([player | PlayerInfo]),
	Plat = tool:to_list(Platform),
	Name = tool:to_list(Player#player.nickname),
	NickName = tool:to_binary(lists:concat([Plat,Name])),
	NewPlayer = Player#player{nickname =NickName },
	ValueList = lists:nthtail(2, tuple_to_list(NewPlayer)),
    [id | FieldList] = record_info(fields, player),
	PlayerId = ?DB_MODULE:insert(player, FieldList, ValueList),
	{PlayerId,NewPlayer}.

insert_title_info(TitleInfo,PlayerId)->
	spawn(fun()->?DB_MODULE:insert(player_other, [pid,ptitles,ptitle,quickbar,war_honor], [PlayerId|TitleInfo])end),
	ok.

%% 插入装备物品信息
insert_equip_info([],_)->ok;
insert_equip_info([EquipInfo|EquipList], PlayerId) -> 
	{Equip,EquipAtt} = EquipInfo,
	[id | FieldList] = record_info(fields, goods),
	NewEquip = list_to_tuple([goods | Equip]),
	
	NewEquip1 = NewEquip#goods{
		player_id = PlayerId							   
	},
	ValueList = lists:nthtail(2, tuple_to_list(NewEquip1)),
	Gid = ?DB_MODULE:insert(goods, FieldList, ValueList),
	insert_equip_attr_info(EquipAtt, PlayerId,Gid),
	insert_equip_info(EquipList, PlayerId).


%% 插入装备物品属性信息
insert_equip_attr_info(EquipList, PlayerId,Gid) ->
	[id | FieldList] = record_info(fields, goods_attribute),
	insert_equip_attr_info_loop(EquipList, PlayerId, FieldList,Gid).
insert_equip_attr_info_loop([], _PlayerId, _FieldList,_Gid) ->
	ok;
insert_equip_attr_info_loop([Equip | E], PlayerId, FieldList,Gid) ->
	EquipInfo = list_to_tuple([goods_attribute | Equip]),
	NewEquipInfo = EquipInfo#goods_attribute{
		player_id = PlayerId,
		gid = Gid			   
	},
	ValueList = lists:nthtail(2, tuple_to_list(NewEquipInfo)),
	?DB_MODULE:insert(goods_attribute, FieldList, ValueList),
	insert_equip_attr_info_loop(E, PlayerId, FieldList,Gid).

%%插入神器信息
insert_deputy_equip(DeputyList,PlayerId)->
	[id | FieldList] = record_info(fields, ets_deputy_equip),
	insert_equip_attr_info_loop(DeputyList, PlayerId, FieldList),
	ok.

insert_equip_attr_info_loop([], _PlayerId, _FieldList)->ok;
insert_equip_attr_info_loop([Deputy|DeputyList], PlayerId, FieldList)->
	DeputyInfo = list_to_tuple([ets_deputy_equip | Deputy]),
	NewDeputyInfo = DeputyInfo#ets_deputy_equip{
		pid = PlayerId
	},
	ValueList = lists:nthtail(2, tuple_to_list(NewDeputyInfo)),
	?DB_MODULE:insert(deputy_equip, FieldList, ValueList),
	insert_equip_attr_info_loop(DeputyList, PlayerId, FieldList).


%% 插入宠物信息
insert_pet_info(PetList, PlayerId) ->
	[id | FieldList] = record_info(fields, ets_pet),
	insert_pet_info_loop(PetList, PlayerId, FieldList).
insert_pet_info_loop([], _PlayerId, _FieldList) ->
	ok;
insert_pet_info_loop([Pet | P], PlayerId, FieldList) ->
	PetInfo = list_to_tuple([ets_pet | Pet]),
	NewPetInfo = PetInfo#ets_pet{
		player_id = PlayerId						 
	},
	ValueList = lists:nthtail(2, tuple_to_list(NewPetInfo)),
	?DB_MODULE:insert(pet, FieldList, ValueList),
	insert_pet_info_loop(P, PlayerId, FieldList).

%% 插入人物经脉信息
insert_meridian_info(MeridianInfo, PlayerId) ->
	Meridian = list_to_tuple([ets_meridian | MeridianInfo]),
	NewMeridian = Meridian#ets_meridian{
		player_id = PlayerId							
	},
	ValueList = lists:nthtail(2, tuple_to_list(NewMeridian)),
    [id | FieldList] = record_info(fields, ets_meridian),
	?DB_MODULE:insert(meridian, FieldList, ValueList).

%% 插入人物技能信息
insert_skill_info([], _PlayerId) ->
	ok;
insert_skill_info([[SkillId, SkillLv,Type ] | S], PlayerId) ->
	?DB_MODULE:insert(skill, [player_id, skill_id, lv, type], [PlayerId, SkillId, SkillLv, Type]),
	insert_skill_info(S, PlayerId).


%%插入战场信息
insert_war_info([],_PlayerId)->skip;
insert_war_info(WarInfo,PlayerId)->
	War = list_to_tuple([ets_war_player | WarInfo]), 
	NewWar = War#ets_war_player{
		pid = PlayerId							
	},
	ValueList = lists:nthtail(2, tuple_to_list(NewWar)),
    [id | FieldList] = record_info(fields, ets_war_player),
	?DB_MODULE:insert(war_player, FieldList, ValueList).

%%插入个人竞技记录
insert_war2_record([],_)->skip;
insert_war2_record(WarInfo,PlayerId)->
	War = list_to_tuple([ets_war2_record | WarInfo]), 
	NewWar = War#ets_war2_record{
		pid = PlayerId							
	},
	ValueList = lists:nthtail(2, tuple_to_list(NewWar)),
    [id | FieldList] = record_info(fields, ets_war2_record),
	?DB_MODULE:insert(war2_record, FieldList, ValueList).

%%插入坐骑信息
insert_mount([],_PlayerId,_Gid)->
	ok;
insert_mount(Mount,PlayerId,Gid)->
	MountInfo = list_to_tuple([ets_mount | Mount]), 
	NewMountInfo = MountInfo#ets_mount{
		id = Gid,
		player_id = PlayerId
	},
	ValueList = lists:nthtail(1, tuple_to_list(NewMountInfo)),
	FieldList = record_info(fields, ets_mount),
	Info = pack_mount_info(FieldList,ValueList,[]),
	?DB_MODULE:replace(mount,Info).   

pack_mount_info([],_ValueList,Info)->lists:reverse(Info);
pack_mount_info(_FieldList,[],Info)->lists:reverse(Info);
pack_mount_info([Field|FieldList],[Value|ValueList],Info)-> 
	pack_mount_info(FieldList,ValueList,[{Field,Value}|Info]).
%% 插入坐骑物品信息
insert_mount_goods([],_)->ok;
insert_mount_goods([Info|MountList], PlayerId) -> 
	{Goods,Mount} = Info,
	[id | FieldList] = record_info(fields, goods),
	NewGoods = list_to_tuple([goods | Goods]),
	
	NewGoods1 = NewGoods#goods{
		player_id = PlayerId							   
	},
	ValueList = lists:nthtail(2, tuple_to_list(NewGoods1)),
	Gid = ?DB_MODULE:insert(goods, FieldList, ValueList),
	insert_mount(Mount, PlayerId,Gid),
	insert_mount_goods(MountList, PlayerId).


%%插入坐骑技能
insert_mount_skill([],_PlayerId)->ok;
insert_mount_skill(Mount,PlayerId)->
	MountInfo = list_to_tuple([ets_mount_skill_exp | Mount]),
	NewMountInfo = MountInfo#ets_mount_skill_exp{
		player_id = PlayerId
	},
	ValueList = lists:nthtail(2, tuple_to_list(NewMountInfo)),
	[id | FieldList] = record_info(fields, ets_mount_skill_exp),
	?DB_MODULE:insert(mount_skill_exp, FieldList, ValueList). 

%%插入挂机配置
insert_hook_config(_PlayerId,[])->skip;
insert_hook_config(PlayerId,Data)->
	?DB_MODULE:insert(player_hook_setting, [player_id, hook_config, time_start, time_limit, timestamp], [PlayerId|Data]),
	ok.

%%插入封神纪元信息
insert_fs_era(_PlayerId,[])->skip;
insert_fs_era(PlayerId,Era)->
	EraInfo = list_to_tuple([ets_fs_era | Era]),
	NewEraInfo = EraInfo#ets_fs_era{
		player_id = PlayerId
	},
	ValueList = lists:nthtail(1, tuple_to_list(NewEraInfo)),
	FieldList = record_info(fields, ets_fs_era),
	?DB_MODULE:insert(fs_era, FieldList, ValueList). 

%%插入玩家分身数据
insert_player_backup([],_PlayerId)->skip;
insert_player_backup(Data,PlayerId)->
	FieldList = [player_id,hp_lim, mp_lim, att_max, att_min, buff, hit, dodge, crit, deputy_skill, deputy_passive_skill, deputy_prof_lv, anti_wind, anti_water, anti_thunder, anti_fire, anti_soil, stren, suitid, goods_ring4, equip_current],
	NewData = [PlayerId|Data],
	spawn(fun()->?DB_MODULE:insert(player_backup,FieldList,NewData)end),
	ok.

clear_database()->
	?DB_MODULE:delete(user,[]),
	?DB_MODULE:delete(player,[]),
	?DB_MODULE:delete(war_player,[]),
	?DB_MODULE:delete(war2_record,[]),
	?DB_MODULE:delete(player_other,[]),
	?DB_MODULE:delete(player_hook_setting,[]),
	?DB_MODULE:delete(player_sys_setting,[]),
	?DB_MODULE:delete(goods,[]),
	?DB_MODULE:delete(goods_attribute,[]),
	?DB_MODULE:delete(goods_buff,[]),
	?DB_MODULE:delete(pet,[]),
	?DB_MODULE:delete(meridian,[]),
	?DB_MODULE:delete(skill,[]),
	?DB_MODULE:delete(deputy_equip,[]),
	?DB_MODULE:delete(mount,[]),
	?DB_MODULE:delete(mount_skill_exp,[]),
	?DB_MODULE:delete(fs_era,[]),
	?DB_MODULE:delete(player_backup,[]),
	?DB_MODULE:delete(batt_value,[]),
	ok.

clear_datebase_player(PlayerId)->
	?DB_MODULE:delete(player_other,[{pid,PlayerId}]),
	?DB_MODULE:delete(player_hook_setting,[{player_id,PlayerId}]),
	?DB_MODULE:delete(player_sys_setting,[{player_id,PlayerId}]),
	?DB_MODULE:delete(goods,[{player_id,PlayerId},{goods_id,"nin",goods_save()}]),
	?DB_MODULE:delete(goods_attribute,[{player_id,PlayerId}]),
	?DB_MODULE:delete(goods_buff,[{player_id,PlayerId}]),
	?DB_MODULE:delete(pet,[{player_id,PlayerId}]),
	?DB_MODULE:delete(meridian,[{player_id,PlayerId}]),
	?DB_MODULE:delete(skill,[{player_id,PlayerId}]),
	?DB_MODULE:delete(deputy_equip,[{pid,PlayerId}]),
	?DB_MODULE:delete(mount,[{player_id,PlayerId}]),
	?DB_MODULE:delete(fs_era,[{player_id,PlayerId}]),
	?DB_MODULE:delete(mount_skill_exp,[{player_id,PlayerId}]),
	?DB_MODULE:delete(player_backup,[{player_id,PlayerId}]),
	?DB_MODULE:delete(batt_value,[{player_id,PlayerId}]),
	ok.
clear_database_player_all(PlayerId,AccId,AccName)->
	?DB_MODULE:delete(user,[{accid,AccId},{accname,AccName}]),
	?DB_MODULE:delete(player,[{id,PlayerId}]),
	?DB_MODULE:delete(war_player,[{pid,PlayerId}]),
	?DB_MODULE:delete(war2_record,[{pid,PlayerId}]),
	?DB_MODULE:delete(player_other,[{pid,PlayerId}]),
	?DB_MODULE:delete(player_hook_setting,[{player_id,PlayerId}]),
	?DB_MODULE:delete(player_sys_setting,[{player_id,PlayerId}]),
	?DB_MODULE:delete(goods,[{player_id,PlayerId}]),
	?DB_MODULE:delete(goods_attribute,[{player_id,PlayerId}]),
	?DB_MODULE:delete(goods_buff,[{player_id,PlayerId}]),
	?DB_MODULE:delete(pet,[{player_id,PlayerId}]),
	?DB_MODULE:delete(meridian,[{player_id,PlayerId}]),
	?DB_MODULE:delete(skill,[{player_id,PlayerId}]),
	?DB_MODULE:delete(deputy_equip,[{pid,PlayerId}]),
	?DB_MODULE:delete(mount,[{player_id,PlayerId}]),
	?DB_MODULE:delete(fs_era,[{player_id,PlayerId}]),
	?DB_MODULE:delete(mount_skill_exp,[{player_id,PlayerId}]),
	?DB_MODULE:delete(player_backup,[{player_id,PlayerId}]),
	?DB_MODULE:delete(batt_value,[{player_id,PlayerId}]),
	ok.

%%重新登录需要保留的物品
goods_save()->
	[31048,31022,31023,31021,23408,23407,23406,23405,23404,23403,23402,23401,23400,
	 23109,23108,23105,23104,23103,23102,23101,23100,23013,23011,23009,23008,23005,
	 23004,23003,23002,23001,23000,23400,24000].