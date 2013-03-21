%% Author: Administrator
%% Created: 2011-12-16
%% Description: TODO: 队伍招募
-module(mod_team_raise).

-include("common.hrl").
-include("record.hrl").
%% -compile(export_all).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([start_link/1, 
		 start/0,
		 stop/0,
		 get_mod_team_raise_pid/0
		 ]).

-record(state,{
			   timestamp = 0 ,		%%基准时间戳 
			   team= [],		%%试炼队伍[{train,1,[{nickname,lv,nums},{}]},{td,2,[{},{}]},{fst,3,[{},{}]},{zxt,4,[{},{}]}]
			   member = []	%%试炼队员[{train,1,[{nickname,lv,career},{}]},{td,2,[{},{}]},{fst,3,[{},{}]},{zxt,4,[{},{}]}]
			   }).


%% 启动跨服战场超级服务
start_link([ProcessName, Worker_id]) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName, Worker_id], []).

start() ->
    gen_server:start(?MODULE, [], []).

%%停止服务
stop() ->
    gen_server:call(?MODULE, stop). 

init([ProcessName, Worker_id]) ->
    process_flag(trap_exit, true),	
	case misc:register(unique, ProcessName, self()) of
		yes ->
			if 
				Worker_id =:= 0 ->
					misc:write_monitor_pid(self(), mod_team_raise, {}),
					misc:write_system_info(self(), mod_team_raise, {});
				true->
			 		misc:write_monitor_pid(self(), mod_team_raise_child, {Worker_id})
			end,
			erlang:send_after(10*60*1000,self(),{'del_player_loop'}),
			State =  #state{
							timestamp = util:unixtime(),
							team = [{train,1,[]},
									{td,2,[]},
									{fst,3,[]},
									{zxt,4,[]},
									{dungeon_35,5,[]},
									{dungeon_45,6,[]},
									{dungeon_55,7,[]},
									{dungeon_65,8,[]},
									{dungeon_70,9,[]}
								   ],
							member = [{train,1,[]},
									  {td,2,[]},
									  {fst,3,[]},
									  {zxt,4,[]},
									  {dungeon_35,5,[]},
									  {dungeon_45,6,[]},
									  {dungeon_55,7,[]},
									  {dungeon_65,8,[]},
									  {dungeon_70,9,[]}
									 ]
							},
			{ok, State};
		_->
			{stop,normal,#state{}}
	end.

%%动态加载队伍招募处理进程 
get_mod_team_raise_pid() ->
	ProcessName = misc:create_process_name(mod_team_raise_process, [0]),
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> Pid;
				false -> 
					start_mod_team_raise(ProcessName)
			end;
		_ ->
			start_mod_team_raise(ProcessName)
	end.


%%启动队伍招募监控模块 (加锁保证全局唯一)
start_mod_team_raise(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> Pid;
					false -> 
						start_team_raise(ProcessName)
				end;
			_ ->
				start_team_raise(ProcessName)
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%开启队伍招募监控模块
start_team_raise(ProcessName) ->
    case supervisor:start_child(
               yg_server_sup,
               {mod_team_raise,
                {mod_team_raise, start_link,[[ProcessName,0]]},
                permanent, 10000, supervisor, [mod_team_raise]}) of 
		{ok, Pid} ->
				timer:sleep(1000),
				Pid;
		_ ->
				undefined
	end.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%%查询招募信息
handle_cast({'raise_info',[Status,Type]},State)->
	raise_info(Status,State,Type),
	{noreply,State};

%%%%招募队伍[{train,1,[record]},{td,2,[record]},{fst,3,[record]},{zxt,4,[record]}]
handle_cast({'raise_team_info',[TeamPid,NickName,Lv,Type,Auto,PlayerId]},State)->
	case lists:keyfind(Type,2,State#state.team) of
		false->NewState = State;
		Team->
			{FunName,_,TeamMem} =Team,
			NowTime = util:unixtime(),
			case lists:keyfind(TeamPid,2,TeamMem) of 
				false->
					T = #raise_team{team_pid=TeamPid,player_id = PlayerId,nickname=NickName,lv=Lv,nums=1,type=Type,auto = Auto,timestamp=NowTime},
					NewTeamMem = [T|TeamMem];
				T1->
					NewT1 = T1#raise_team{nickname=NickName,player_id = PlayerId,lv=Lv,nums=1,auto = Auto,timestamp=NowTime},
					NewTeamMem = lists:keyreplace(TeamPid, 2, TeamMem, NewT1)
			end,
			NewTeam =  lists:keyreplace(Type, 2, State#state.team, {FunName,Type,NewTeamMem}),
			NewState1 = State#state{team = NewTeam},
			NewState = del_member(NewState1,PlayerId)
	end,
	{noreply,NewState};

%%更新队伍人数
handle_cast({'update_team_member',[TeamPid,TeamType,PlayerId,TeamNums]},State)->
	case lists:keyfind(TeamType,2,State#state.team) of
		false->
			NewState = State;
		Team->
			{FunName,_,TeamMem} =Team,
			case lists:keyfind(TeamPid,2,TeamMem) of 
				false->
					NewState = State;
				T->
					NewT = T#raise_team{nums = TeamNums},
					NewTeamMem = lists:keyreplace(TeamPid, 2, TeamMem, NewT),
					NewTeam =  lists:keyreplace(TeamType, 2, State#state.team, {FunName,TeamType,NewTeamMem}),
					NewState1 = State#state{team = NewTeam},
					NewState = del_member(NewState1,PlayerId)
			end
	end,
	{noreply,NewState};

%%更新队伍是否自动入队
handle_cast({'update_team_auto',[TeamPid,Type,Auto]},State)->
	case lists:keyfind(Type,2,State#state.team) of
		false->NewState = State;
		Team->
			{FunName,_,TeamMem} =Team,
			case lists:keyfind(TeamPid,2,TeamMem) of 
				false->NewState = State;
				T->
					NewT = T#raise_team{auto = Auto},
					NewTeamMem = lists:keyreplace(TeamPid, 2, TeamMem, NewT),
					NewTeam =  lists:keyreplace(Type, 2, State#state.team, {FunName,Type,NewTeamMem}),
					NewState = State#state{team = NewTeam}
			end
	end,
	{noreply,NewState};

%%更改队伍名字
handle_cast({'change_team_name',[TeamPid,Type,NickName,PlayerId,Lv,TeamNums]},State)->
	case lists:keyfind(Type,2,State#state.team) of
		false->NewState = State;
		Team->
			{FunName,_,TeamMem} =Team,
			case lists:keyfind(TeamPid,2,TeamMem) of 
				false->NewState = State;
				T->
					NewT = T#raise_team{nickname = NickName,player_id=PlayerId,lv=Lv,nums= TeamNums},
					NewTeamMem = lists:keyreplace(TeamPid, 2, TeamMem, NewT),
					NewTeam =  lists:keyreplace(Type, 2, State#state.team, {FunName,Type,NewTeamMem}),
					NewState = State#state{team = NewTeam}
			end
	end,
	{noreply,NewState};

%%删除招募队伍
handle_cast({'del_team_info',[TeamPid]},State)->
	TeamBag = del_team_loop(State#state.team,TeamPid,[]),
	NewState = State#state{team=TeamBag},
	{noreply,NewState};

%%招募队员
%% -record(member_info,{
%% 					 pid = 0,			%%玩家id
%% 					 nickname = '',		%%玩家名字
%% 					 lv = 0,			%%玩家等级
%% 					 career = 0 ,		%%玩家职业
%% 					 type = 0,		%%类型1试炼2镇妖，3封神，4诛仙
%% 					 timestamp=0 		%%等级时间
%% 					 }).
%member = [{train,1,[]},{td,2,[]},{fst,3,[]},{zxt,4,[]}]
handle_cast({'raise_member_info',[Status,NickName,Lv,Career,Type]},State)->
	PlayerId = Status#player.id,
	case misc:is_process_alive(Status#player.other#player_other.pid_team) of
		true->Res=3,
			  NewState=State;
		false->
			case lists:keyfind(Type, 2, State#state.member) of
				false->
					Res = 2,
					NewState = State;
				MemberList ->
					{FunName,_,MemberInfo} = MemberList,
					NowTime = util:unixtime()+20*60,
					case lists:keyfind(PlayerId, 2, MemberInfo) of
						false->
							M = #raise_member{pid=PlayerId,nickname=NickName,lv=Lv,career=Career,type=Type,timestamp=NowTime},
							NewMemberInfo = [M|MemberInfo];
						Member->
							NewMember = Member#raise_member{timestamp=NowTime},
							NewMemberInfo = lists:keyreplace(PlayerId, 1, MemberInfo, NewMember)
					end,
					NewMemberList =  lists:keyreplace(Type, 2, State#state.member, {FunName,Type,NewMemberInfo}),
					NewState = State#state{member = NewMemberList},
					Res = 1
			end
	end,
	{ok,BinData} = pt_24:write(24026,[Type,Res]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	{noreply,NewState};

handle_cast({'del_member',[PlayerId]},State)->
	NewState = del_member(State,PlayerId),
	{noreply,NewState};

handle_cast({'cancel_raise',[Status,Type]},State)->
	case lists:keyfind(Type, 2, State#state.member) of
		false->
			Res = 2,
			NewState= State;
		MemberList->
			{FunName,_,MemberInfo} = MemberList,
			case lists:keyfind(Status#player.id, 2, MemberInfo) of
				false->
					Res = 1,
					NewState = State;
				Member ->
					NewMemberInfo = lists:delete(Member, MemberInfo),
					NewMemberList =  lists:keyreplace(Type, 2, State#state.member, {FunName,Type,NewMemberInfo}),
					NewState = State#state{member = NewMemberList},
					Res = 1
			end
	end,
	{ok,BinData} = pt_24:write(24027,[Type,Res]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	{noreply,NewState};

%%招募广告
handle_cast({'raise_msg',[Status,TeamPid,TeamInfo,Type]},State)->
	%%【xxx】创建了闯荡【功能名】的队伍，招募各路英雄共同前往！》》我要加入《《
	case check_funtion_lv(Type,Status#player.lv) of
		false->
			{ok,BinData} = pt_24:write(24028,[2]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			NewState=State;
		true->
			case lists:keyfind(Type, 2, State#state.team) of
				false->
					NewState = State;
				{FunName,Type,Team}->
					NowTime = util:unixtime(),
					case lists:keyfind(TeamPid,2,Team) of 
						false->
							TeamBag = del_team_loop(State#state.team,TeamPid,[]),
							NewState1 = State#state{team=TeamBag},
							msg(Status,Type),
							T = #raise_team{team_pid=TeamPid,player_id = Status#player.id,nickname=Status#player.nickname,lv=Status#player.lv,nums=length(TeamInfo#team.member),type=Type,auto = TeamInfo#team.auto_access,timestamp=NowTime},
							NewTeam =  lists:keyreplace(Type, 2, NewState1#state.team, {FunName,Type,[T|Team]}),
							NewState = NewState1#state{team = NewTeam},
							raise_info(Status,NewState,Type);
						T->
							if T#raise_team.msg_time+10 < NowTime->
									msg(Status,Type),
									NewT = T#raise_team{msg_time= NowTime},
									NewTeamMem = lists:keyreplace(TeamPid, 2, Team, NewT),
									NewTeam =  lists:keyreplace(Type, 2, State#state.team, {FunName,Type,NewTeamMem}),
									NewState = State#state{team = NewTeam};
							   true->
								   NewState = State
							end
					end
			end
	end,
	{noreply,NewState};

%%添加到招募面板
handle_cast({'ADD_TO_TEAM_RAISE',[Status,TeamPid,TeamInfo,Type]},State)->
	case lists:keyfind(Type, 2, State#state.team) of
		false->
			NewState = State;
		{FunName,Type,Team}->
			case lists:keyfind(TeamPid,2,Team) of 
				false->
					TeamBag = del_team_loop(State#state.team,TeamPid,[]),
					NewState1 = State#state{team=TeamBag},
					T = #raise_team{team_pid=TeamPid,player_id = Status#player.id,nickname=Status#player.nickname,lv=Status#player.lv,nums=length(TeamInfo#team.member),type=Type,auto = TeamInfo#team.auto_access,timestamp=0},
					NewTeam =  lists:keyreplace(Type, 2, NewState1#state.team, {FunName,Type,[T|Team]}),
					NewState = NewState1#state{team = NewTeam},
					raise_info(Status,NewState,Type);
				_->NewState = State
			end
	end,
	{noreply,NewState};

handle_cast(_MSg,State)->
	 {noreply, State}.

handle_info({'del_player_loop'},State)->
	NowTime = util:unixtime(),
	Member = del_player_loop(State#state.member,NowTime,[]),
	Team = del_team_timer(State#state.team,NowTime,[]),
	NewState = State#state{member=Member,team = Team},
	erlang:send_after(10*60*1000,self(),{'del_player_loop'}),
	{noreply,NewState};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()).

code_change(_OldVsn, State, _Extra)->
    {ok, State}.
%%
%% Local Functions
%%
raise_info(Status,State,Type)->
	TeamInfo = case lists:keyfind(Type, 2, State#state.team) of
				   false->[];
				   {_,_,Team}->Team
			   end,
	MemberInfo = case lists:keyfind(Type,2,State#state.member) of
					 false->[];
					 {_,_,Member}->Member
				 end,
	{ok,BinData} = pt_24:write(24025,[Type,TeamInfo,MemberInfo]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%删除队伍信息
del_team_loop([],_TeamPid,TeamBag)->TeamBag;
del_team_loop([{FunName,Type,Team}|TeamList],TeamPid,TeamBag)->
	NewTeam = [T||T<-Team,T#raise_team.team_pid=/=TeamPid],
	del_team_loop(TeamList,TeamPid,[{FunName,Type,NewTeam}|TeamBag]).


%%删除玩家
del_member(State,PlayerId)->
	Member = member_loop(State#state.member,PlayerId,[]),
	State#state{member=Member}.

member_loop([],_,MemberBag)->MemberBag;
member_loop([{FunName,Type,MemberInfo}|MemberList],PlayerId,MemberBag)->
	NewMemberInfo = [M || M<-MemberInfo,M#raise_member.pid =/=PlayerId],
	member_loop(MemberList,PlayerId,[{FunName,Type,NewMemberInfo}|MemberBag]).

														
%%循环删除过期的等级玩家信息
%%[{train,1,[]},{td,2,[]},{fst,3,[]},{zxt,4,[]}]
del_player_loop([],_NowTime,MemberList)->MemberList;
del_player_loop([{FunName,Type,MemberInfo}|MBag],NowTime,MemberList)->
	NewMemberInfo = [M||M<-MemberInfo,M#raise_member.timestamp>NowTime],
	del_player_loop(MBag,NowTime,[{FunName,Type,NewMemberInfo}|MemberList]).

del_team_timer([],_NowTime,TeamList)->TeamList;
del_team_timer([{FunName,Type,TeamInfo}|TBag],NowTime,TeamList)->
	NewTeamInfo = [M||M<-TeamInfo,M#raise_team.timestamp+20*60>NowTime],
	del_team_timer(TBag,NowTime,[{FunName,Type,NewTeamInfo}|TeamList]).


msg(Status,Type)->
	Msg = io_lib:format("【<a href='event:1, ~p, ~s, ~p, ~p'><font color='#FEDB4F'>~s</font></a>】创建了闯荡【<font color='#FEDB4F;'>~s</font>】的队伍，招募各路英雄共同前往！<a href='event:7,~p'><font color='#00FF00'><u>》》我要加入《《</u></font></a>",[Status#player.id, Status#player.nickname, Status#player.career, Status#player.sex, Status#player.nickname,get_funtion_name(Type,Status#player.lv),Status#player.id]),
	lib_chat:broadcast_sys_msg(6, Msg).

%%获取功能名字
%%（1试炼副本，2镇妖，3封神，4诛仙,5狐狸洞，6河神殿，7蚩尤墓8王母殿，9天回阵
get_funtion_name(Type,Lv)->
	case Type of
		1->io_lib:format("~p级别远古试炼",[Lv-(Lv rem 10)]);
		2->"多人镇妖台";
		3->"封神台";
		4->"诛仙台";
		5->"35副本•狐狸洞";
		6->"45副本•河神殿";
		7->"55副本•蚩尤墓";
		8->"65副本•王母殿";
		_->"70副本•天回阵"
	end.

check_funtion_lv(Type,Lv)->
	case Type of
		1->Lv>=33;
		2->Lv>=40;
		3->Lv>=35;
		4->Lv>=55;
		5->Lv>=35;
		6->Lv>=45;
		7->Lv>=55;
		8->Lv>=65;
		_->Lv>=70
	end.