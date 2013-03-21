%%%------------------------------------
%%% @Module  : mod_leap_client
%%% @Author  : ygfs
%%% @Created : 2011.10.04
%%% @Description: 跨服通信客户端模块
%%%------------------------------------
-module(mod_leap_client).

-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export(
    [
   		start/1,
	 	get_mod_leap_client_pid/0,
		leap_join/4,
		send_player_data/2,
		update_player_data/2,
		del_player_data/4,
		update_player_att/4,
		war2_sync_player/2,
		war2_update_player/2,
		bet_popular/1,
		re_war_rank/0,
		stop/0,
		test/0,
		reset/0
    ]
).

-record(state, {
	socket = undefined										%% socket接口
}).

%% -define(SERVER_IP, "121.9.242.238"). 
-define(Opt, [binary, {packet, 4}]).
%% -define(Port, 9099).

%% 启动跨服通信客户端模块
start(ProcessName) ->
  	gen_server:start({local, ?MODULE}, ?MODULE, [ProcessName], []).

stop()->
	ok.

reset()->
	gen_server:cast(get_mod_leap_client_pid(),{'reset'}).

init([ProcessName]) ->
	Self = self(),
	io:format("11.init mod leap client!!~p~n",[ProcessName]),
	case misc:register(unique, ProcessName, Self) of
		yes ->
			case config:get_war_server_info() of
				[]->skip;
				[_,_,1,_,_]->
					Self!{'CONNECT',Self};
				[_,_,_,_,1]->
					Self!{'CONNECT',Self};
				[_,_,1,_,1]->
					Self!{'CONNECT',Self};
				_->skip
			end,
			TimerHandle = erlang:send_after(20000,self(),{'HEARTBEAT'}),
			put(heartbeat,TimerHandle),
			{ok, #state{}};
		_ ->
			{stop, normal, #state{}}
	end.

handle_call('test', _From, State) ->
    {reply, State#state.socket, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast({'reset'},State)->
	TimerHandle = erlang:send_after(1000,self(),{'HEARTBEAT'}),
	put(heartbeat,TimerHandle),
	{noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%%发送数据
handle_info({'SEND_MSG', Data}, State) -> 
	case State#state.socket =/= undefined of
		true ->
			gen_tcp:send(State#state.socket, Data);
%% 			case  gen_tcp:send(State#state.socket, Data) of
%% 				ok->ok;
%% 				{error, timeout}->ok;
%% 				_->
%% 					skip
%% 					erlang:send_after(10000,self(),{'CONNECT',self()})
%% 			end;
		false ->
			skip
%% 			erlang:send_after(10000,self(),{'CONNECT',self()})
	end,
	{noreply, State};

%%连接
handle_info({'CONNECT',Pid},State)->
	spawn(fun()->connect(Pid)end),
	{noreply,State};

%%同步玩家属性数据
handle_info({'SYN_DATA'},State)->
%% 	PlayerBag = db_agent:select_war_player_id(),
	PlayerBag = ?DB_MODULE:select_all(war2_record, "pid", [], [], []),
	PlatFormName = config:get_platform_name(),
	ServerNum = config:get_server_num(),
	leap_join(PlayerBag,PlatFormName,ServerNum,[]),
	{noreply,State};

handle_info({'SOCKET',Socket},State)->
	NewState = State#state{socket=Socket},
	{noreply,NewState};

%%发送跨服战力排行榜请求
handle_info({war_rank},State)->
	spawn(fun()->re_war_rank()end),
	{noreply,State};
	
%%心跳包，20S检测一次
handle_info({'HEARTBEAT'},State)->
	misc:cancel_timer(heartbeat),
	case State#state.socket =/= undefined of
		true ->
			PlatFormName = config:get_platform_name(),
			ServerNum = config:get_server_num(), 
			DataList = [
						{platform, PlatFormName},
						{server_num, ServerNum}		
			   		],
			DataListBin = list_to_binary(util:term_to_string(DataList)),
			case gen_tcp:send(State#state.socket, <<45050:32,DataListBin/binary>>) of
				ok->
					ok;
				_->erlang:send_after(10000,self(),{'CONNECT',self()})
			end;
		false ->
			erlang:send_after(10000,self(),{'CONNECT',self()})
	end,
	TimerHandle = erlang:send_after(20000,self(),{'HEARTBEAT'}),
%% 	io:format("heartbeat~p~n",[util:unixtime()]),
	put(heartbeat,TimerHandle),
	{noreply,State};


handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) -> 
  	{ok, State}.

%%建立连接
connect(Pid)->
	case config:get_war_server_info() of
		[]->
%% 			erlang:send_after(10000,Pid,{'CONNECT',Pid}),
			undefined;
		[Ip,Port,1,_,_1]->
			case gen_tcp:connect(Ip,Port, ?Opt) of
				{ok, Socket} ->
					ClentInfo = client_info(),
					gen_tcp:send(Socket,ClentInfo),
					Pid!{'SOCKET',Socket},
					loop(Socket,Pid),
					Socket;
				_Any ->
%% 					erlang:send_after(10000,Pid,{'CONNECT',Pid}),
					undefined
			end;
		[Ip,Port,_1,_,1]->
			case gen_tcp:connect(Ip,Port, ?Opt) of
				{ok, Socket} ->
					ClentInfo = client_info(),
					gen_tcp:send(Socket,ClentInfo),
					Pid!{'SOCKET',Socket},
					loop(Socket,Pid),
					Socket;
				_Any ->
%% 					erlang:send_after(10000,Pid,{'CONNECT',Pid}),
					undefined
			end;
		[Ip,Port,1,_,1]->
			case gen_tcp:connect(Ip,Port, ?Opt) of
				{ok, Socket} ->
					ClentInfo = client_info(),
					gen_tcp:send(Socket,ClentInfo),
					Pid!{'SOCKET',Socket},
					loop(Socket,Pid),
					Socket;
				_Any ->
%% 					erlang:send_after(10000,Pid,{'CONNECT',Pid}),
					undefined
			end;
		_->
%% 			erlang:send_after(10000,Pid,{'CONNECT',Pid}),
			undefined
	end.

%% 接收消息
loop(Socket,Pid) ->
 	receive
		%% 接收服务器端发送过来的的消息
  		{tcp, Socket, Bin} ->
			<<Cmd:32, DataBin/binary>> = Bin,
%% 			io:format("get the CMD is >>>>~p~n",[Cmd]),
			case Cmd of
				%%广播系统信息
				45030 ->
					lib_chat:broadcast_sys_msg(6, DataBin);
				%%发放奖励
				45031 ->
					Info =util:string_to_term(binary_to_list(DataBin)) ,
					mod_war_supervisor:war_award(Info);
				%%同步装备信息
				45032 ->
					Info =util:string_to_term(binary_to_list(DataBin)) ,
%% 					io:format("45032>>>>~p~n",[DataBin]),
					syn_equip(Info);
				%%封神大会历史记录
				45042->
					NewDataBin = zlib:uncompress(DataBin),
					Record = util:string_to_term(binary_to_list(NewDataBin)),
					mod_war_supervisor:add_war_record(Record),
					ok;
				%%参赛玩家数据同步
				45044->
					Pid!{'SYN_DATA'};
				%%45050积分同步
				45050->
					Award =util:string_to_term(binary_to_list(DataBin)) ,
					mod_war_supervisor:syn_war_point(Award),
					ok;
				%%单人竞技淘汰赛数据同步
				45203->
					NewDataBin = zlib:uncompress(DataBin),
					EliminationBag = util:string_to_term(binary_to_list(NewDataBin)),
					mod_war2_supervisor:sync_war2_elimination_local(EliminationBag),
					ok;
				%%玩家历史记录
				45204->
					History = util:string_to_term(binary_to_list(DataBin)),
					mod_war2_supervisor:sync_war2_history_local(History),
					ok;
				%%发放奖励
				45205->
					gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(),{'WAR2_AWARD'});
				%%冠军数据
				45206->
					Champion =util:string_to_term(binary_to_list(DataBin)) ,
					gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(),{'SYNC_CHAMPION',[Champion]});
				45208->
					gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(),{'WAR2_BET_PROVIDE'});
				45210->
					[S] =util:string_to_term(binary_to_list(DataBin)) ,
					mod_war2_supervisor:cmd_change_war2_state(S);
				45211->
					IsBet =util:string_to_term(binary_to_list(DataBin)) ,
					spawn(fun()->mod_war2_supervisor:get_mod_war2_supervisor_pid()!{'IS_BET_UPDATE',IsBet}end);
				45212->
					Page = util:string_to_term(binary_to_list(DataBin)) ,
					gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(),{'WAR2_PAGE',Page});
				%%同步跨服排行榜
				45213->
					NewDataBin = zlib:uncompress(DataBin),
					WarRank = util:string_to_term(binary_to_list(NewDataBin)),
%% 					RankRecord,EquipList,AttList
					gen_server:cast(mod_rank:get_mod_rank_pid(),{'war_battvalue_rank',WarRank}),
					ok;
				_ ->
					skip
			end,
   			loop(Socket,Pid);
  		{tcp_closed, Socket} ->
			skip;
%% 			erlang:send_after(10000,Pid,{'CONNECT',Pid});
  		_Any -> 
   			loop(Socket,Pid)
 	end.

%% 获取跨服通信进程
get_mod_leap_client_pid() ->
	ProcessName = mod_leap_client_mark,
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true ->
					Pid;
				false ->
					start_mod_leap_client(ProcessName)
			end;
		_ ->
			start_mod_leap_client(ProcessName)			
	end.


%% 开启跨服通信进程
start_mod_leap_client(ProcessName) ->
	global:set_lock({ProcessName, undefined}),
	ProcessPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->	
						Pid;		
					false ->
						start_leap_client(ProcessName)
				end;
			_ ->
				start_leap_client(ProcessName)
		end,
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

start_leap_client(ProcessName) ->
	ChildSpec = {
		mod_leap_client,
      	{
			mod_leap_client, 
			start,
			[ProcessName]
		},
   		permanent, 
		10000, 
		supervisor, 
		[mod_leap_client]
	},
	case supervisor:start_child(yg_server_sup, ChildSpec) of
		{ok, Pid} ->
			Pid;
		_ ->
			undefined
	end.
client_info()->
	PlatFormName = config:get_platform_name(),
	ServerNum = config:get_server_num(), 
	DataList = [
				{platform, PlatFormName},
				{server_num, ServerNum}		
			   ],
	DataListBin = list_to_binary(util:term_to_string(DataList)),
	<<45041:32, DataListBin/binary>>.

test()->
	Pid = get_mod_leap_client_pid(),
	io:format("this is a client test!!!!!!!!~p~n",[Pid]),
	Pid ! {'SEND_MSG', <<"this is a client test!">>}.

bet_popular(Data)->
	Data1 = list_to_binary(util:term_to_string(Data)),
	Pid = get_mod_leap_client_pid(),
	Pid ! {'SEND_MSG', <<45207:32, Data1/binary>>},
	ok.

war2_sync_player(PlayerId,NickName)->
	Bin = pack_player_data(PlayerId,NickName,2),
	Pid = get_mod_leap_client_pid(),
	Pid ! {'SEND_MSG', <<45201:32, Bin/binary>>},
	ok.
war2_update_player(PlayerId,NickName)->
	Bin = pack_player_data(PlayerId,NickName,2),
	Pid = get_mod_leap_client_pid(),
	Pid ! {'SEND_MSG', <<45202:32, Bin/binary>>},
	ok.


send_player_data(PlayerId,NickName)->
%% 	io:format("send_player_data>>>>>~p~n",[PlayerId]),
	Bin = pack_player_data(PlayerId,NickName,1),
	Pid = get_mod_leap_client_pid(),
	Pid ! {'SEND_MSG', <<45045:32, Bin/binary>>},
	ok.

update_player_data(PlayerId,NickName)->
%% 	io:format("update_player_data>>>>>~p~n",[PlayerId]),
	Bin = pack_player_data(PlayerId,NickName,1),
	Pid = get_mod_leap_client_pid(),
	Pid ! {'SEND_MSG', <<45046:32, Bin/binary>>},
	ok.
update_player_att(Platform,Sn,Nickname,Att)->
	InfoBag = [Platform,Sn,Nickname,Att],
	DataListBin = list_to_binary(util:term_to_string(InfoBag)),
	%%玩家数据需要压缩
	Bin = zlib:compress(DataListBin),
	Pid = get_mod_leap_client_pid(),
	Pid ! {'SEND_MSG', <<45048:32, Bin/binary>>},
	ok.

del_player_data(Platform,Sn,NickName,PlayerId)->
%% 	PlatFormName = config:get_platform_name(),
%% 	ServerNum = config:get_server_num(),
	[AccId,SnOld] = db_agent:get_accid_sn_by_id(PlayerId),
	AccInfo = db_agent:get_user_accinfo_by_accid_and_sn(AccId,SnOld),
	%%accid,accname,status,sn,ct
	[AccId,AccName,_Status,_Sn,_Ct] = AccInfo,
	InfoBag = [Platform,Sn,NickName,AccId,AccName],
	DataListBin = list_to_binary(util:term_to_string(InfoBag)),
	%%玩家数据需要压缩
	Bin = zlib:compress(DataListBin),
	Pid = get_mod_leap_client_pid(),
	Pid ! {'SEND_MSG', <<45047:32, Bin/binary>>},
	ok.
	
pack_player_data(PlayerId,NickName,Funtion)->
	PlatFormName = config:get_platform_name(),
	ServerNum = config:get_server_num(),
	Info = player_data(PlayerId,PlatFormName,ServerNum,Funtion),
	InfoBag = [PlatFormName,ServerNum,NickName,Info],
	DataListBin = list_to_binary(util:term_to_string(InfoBag)),
	%%玩家数据需要压缩
	Bin = zlib:compress(DataListBin),
	Bin.

player_data(PlayerId,PlatFormName,ServerNum,Funtion) ->
	PlayerInfo = lib_account:get_info_by_id(PlayerId),
	[AccId,SnOld] = db_agent:get_accid_sn_by_id(PlayerId),
	AccInfo = db_agent:get_user_accinfo_by_accid_and_sn(AccId,SnOld),
	TitleInfo = db_agent:get_war_title_by_id(PlayerId),
	EquipList = db_agent:get_war_equip_list(PlayerId),
	EquipAttributeList = get_equip_id_list(EquipList, PlayerId, []),
	Pet = db_agent:get_war_equip_pet(PlayerId),
	MeridianInfo = db_agent:select_meridian_by_playerid(PlayerId),
	SkillInfo = db_agent:get_all_skill(PlayerId),
	if Funtion ==1->
		   War2Record = [],
		   WarInfo = db_agent:select_war_player_by_id(PlayerId);
	   true->
		   WarInfo=[],
		   War2Record = db_agent:select_war2_record_by_id(PlayerId)
	end,
	Deputy = db_agent:get_war_deputy_equip(PlayerId),
	PlatFormInfo = lists:concat(["[",PlatFormName, "-",ServerNum,"]"]),
	MountList = db_agent:get_war_mount_list(PlayerId),
	Mount = get_mount_list(MountList,[]),
	MountSkill = db_agent:select_mount_skill_exp(PlayerId),
	HookSetting = db_agent:get_hook_config(PlayerId),
	FsEra = db_agent:load_player_era_info(PlayerId),
	Backup = get_player_backup(PlayerId),
	DataList = [
		{platform,PlatFormInfo},
		{accinfo,AccInfo},
		{player, PlayerInfo},
		{title,TitleInfo},
		{equip_info, EquipAttributeList},
		{pet, Pet},
		{meridian, MeridianInfo},
		{skill, SkillInfo},
		{war,WarInfo},
		{war2,War2Record},
		{deputy,Deputy},
		{mount,Mount},
		{mountskill,MountSkill},
		{hookconfig,HookSetting},
		{fs_era,FsEra},
		{backup,Backup}
	],
	DataList.

%%请求跨服战力排行
re_war_rank()->
	Platform = config:get_platform_name(),
	Sn = config:get_server_num(),
	DataListBin = list_to_binary(util:term_to_string([Platform,Sn])),
	Pid = get_mod_leap_client_pid(),
	Pid ! {'SEND_MSG', <<45214:32, DataListBin/binary>>}.

syn_equip([NickName])->
	case lib_player:get_role_id_by_name(NickName) of
		null->
			skip;
		[]->skip;
		PlayerId->
%% 			io:format("PlayerId>>>>>~p~n",[PlayerId]),
			EquipList = db_agent:get_war_equip_list(PlayerId),
			EquipAttributeList = get_equip_id_list(EquipList, PlayerId, []),
			DataList = [{nickname,NickName},
						{equip_info, EquipAttributeList}],
			DataListBin = list_to_binary(util:term_to_string(DataList)),
			%%玩家数据需要压缩
			Bin = zlib:compress(DataListBin),
			Pid = get_mod_leap_client_pid(),
			Pid ! {'SEND_MSG', <<45032:32, Bin/binary>>}
	end.

leap_join([],PlatFormName,ServerNum,InfoBag)->
	Info = [PlatFormName,ServerNum,InfoBag],
	DataListBin = list_to_binary(util:term_to_string(Info)),
	%%玩家数据需要压缩
	Bin = zlib:compress(DataListBin),
	Pid = get_mod_leap_client_pid(),
	Pid ! {'SEND_MSG', <<45040:32, Bin/binary>>};
leap_join([[PlayerId]|PlayerList],PlatFormName,ServerNum,InfoBag)->
	Info = join(PlayerId,PlatFormName,ServerNum),
	leap_join(PlayerList,PlatFormName,ServerNum,[Info|InfoBag]).
	
join(PlayerId,PlatFormName,ServerNum) ->
	%PlayerId = 1,
	PlayerInfo = lib_account:get_info_by_id(PlayerId),
	[AccId,SnOld] = db_agent:get_accid_sn_by_id(PlayerId),
	AccInfo = db_agent:get_user_accinfo_by_accid_and_sn(AccId,SnOld),
	TitleInfo = db_agent:get_war_title_by_id(PlayerId),
	EquipList = db_agent:get_war_equip_list(PlayerId),
	EquipAttributeList = get_equip_id_list(EquipList, PlayerId, []),
	Pet = db_agent:get_war_equip_pet(PlayerId),
	MeridianInfo = db_agent:select_meridian_by_playerid(PlayerId),
	SkillInfo = db_agent:get_all_skill(PlayerId),
	WarInfo = db_agent:select_war_player_by_id(PlayerId),
	Deputy = db_agent:get_war_deputy_equip(PlayerId),
	PlatFormInfo = lists:concat(["[",PlatFormName, "-",ServerNum,"]"]),
	MountList = db_agent:get_war_mount_list(PlayerId),
	Mount = get_mount_list(MountList,[]),
	MountSkill = db_agent:select_mount_skill_exp(PlayerId),
	HookSetting = db_agent:get_hook_config(PlayerId),
	FsEra = db_agent:load_player_era_info(PlayerId),
	War2Record = db_agent:select_war2_record_by_id(PlayerId),
	Backup = get_player_backup(PlayerId),
	DataList = [
		{platform,PlatFormInfo},
		{accinfo,AccInfo},
		{player, PlayerInfo},
		{title,TitleInfo},
		{equip_info, EquipAttributeList},
		{pet, Pet},
		{meridian, MeridianInfo},
		{skill, SkillInfo},
		{war,WarInfo},
		{deputy,Deputy},
		{mount,Mount},
		{mountskill,MountSkill},
		{hookconfig,HookSetting},
		{fs_era,FsEra},
		{war2,War2Record},
		{backup,Backup}
	],
	DataList.

get_equip_id_list([], _PlayerId, EquipAttributeList) ->
	EquipAttributeList;
get_equip_id_list([Equip | E], PlayerId, EquipAttributeList) ->
	[EquipId | _] = Equip,
	EquipAttrList = db_agent:get_war_equip_attr_list(PlayerId, EquipId),
	get_equip_id_list(E, PlayerId, EquipAttributeList ++ [{Equip,EquipAttrList}]).	
	
get_mount_list([],MountList)->
	MountList;
get_mount_list([Mount|M],MountList)->
	[MountId | _] = Mount,
	MountInfo = db_agent:select_mount_info(MountId),
	get_mount_list(M,MountList++[{Mount,MountInfo}]).

%%获取玩家分身备份数据
get_player_backup(PlayerId)->
	FieldList = "hp_lim, mp_lim, att_max, att_min, buff, hit, dodge, crit, deputy_skill, deputy_passive_skill, deputy_prof_lv, anti_wind, anti_water, anti_thunder, anti_fire, anti_soil, stren, suitid, goods_ring4, equip_current",
	db_agent:select_row(player_backup, FieldList, [{player_id, PlayerId}]).