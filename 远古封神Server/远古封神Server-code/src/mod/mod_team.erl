%%%------------------------------------
%%% @Module  : mod_team
%%% @Author  : ygzj
%%% @Created : 2010.10.06
%%% @Description: 组队模块
%%%------------------------------------
-module(mod_team).
-behaviour(gen_server).
-export(
	[
	 	start/1,             		%% 开启组队服务
        send_to_member/2,    		%% 广播给队员
        get_dungeon/1,       		%% 返回副本id
        create_dungeon/4,    		%% 创建副本
		create_fst/4,				%% 创建封神台
		create_td/4,				%% 创建镇妖台
		create_training/4,	 		%% 创建试炼副本
        create_cave/4,				%% 创建幻魔穴
		create_couple_dungeon/5,	%% 创建夫妻副本
		send_team/2
 	]
).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").

-define(TEAM_MEMBER_MAX, 5).

%% 开启组队进程
start(TeamParam) ->
    gen_server:start_link(?MODULE, TeamParam, []).

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([PlayerId, Pid, Nickname, TeamName, DungeonPid, SendPid, SceneId, Realm, Lv, Career, Sex, HpLim, MpLim, Auto, Type]) ->
	case is_pid(DungeonPid) of
		true ->
			lib_dungeon:set_team_pid(DungeonPid, self());
		false -> 
			no_dungeon
	end,
	%% 檫黑板
	mod_delayer:delete_blackboard_info(PlayerId),		
	FstPid =
		if
			SceneId rem 10000 > 1000 ->
				[{SceneId, DungeonPid}];
			true ->
				[]
		end,
	NewDungeonPid =
		if
			SceneId < 1000 ->
				undefined;
			true ->
				DungeonPid
		end,
	Member = #mb{
		id = PlayerId, 
		pid = Pid, 
		nickname = Nickname, 
		pid_send = SendPid, 
		realm = Realm,
		lv = Lv,
		career = Career,
		sex = Sex,
		hp_lim = HpLim,
		mp_lim = MpLim,
		state = 1
	},
	TeamState = #team{
   		leaderid = PlayerId, 
      	leaderpid = Pid,
		leadername = Nickname,
       	teamname = TeamName, 
		member = [Member],
		dungeon_pid = NewDungeonPid,
		dungeon_scene_res_id = lib_scene:get_res_id(SceneId),
		fst_pid = FstPid,
		auto_access = Auto,
		team_type = Type
   	},
	misc:write_monitor_pid(self(), ?MODULE, TeamState),
    {ok, TeamState}.

%% 广播给队员
send_to_member(TeamPid, Bin) ->
	case is_pid(TeamPid) of
		true ->
			gen_server:cast(TeamPid, {'SEND_TO_MEMBER', Bin});
		false ->
			skip
	end.

%% 返回副本进程id
get_dungeon(TeamPid) ->
    case misc:is_process_alive(TeamPid) of
        false -> false;
        true -> gen_server:call(TeamPid, get_dungeon)
    end.

%% 创建副本服务
create_dungeon(TeamPid, From, SceneId, PlayerInfo) ->
	case catch gen:call(TeamPid, '$gen_call', {create_dungeon, From, SceneId, PlayerInfo}, 2000) of
		{'EXIT', _Reason} ->
			{fail, <<"系统繁忙，请稍候重试！">>};
		{ok, Result} ->
			Result
	end.

%% 创建封神台服务
create_fst(TeamPid, From, SceneId, PlayerInfo) ->
	case catch gen:call(TeamPid, '$gen_call', {create_fst, From, SceneId, PlayerInfo}, 2000) of
		{'EXIT', _Reason} ->
			{fail, <<"系统繁忙，请稍候重试！">>};
		{ok, Result} ->
			Result
	end.

%% 创建镇妖台服务
create_td(TeamPid, From, SceneId, PlayerInfo) ->
	case catch gen:call(TeamPid, '$gen_call', {create_td, From, SceneId, PlayerInfo}, 2000) of
		{'EXIT', _Reason} ->
			{fail, <<"系统繁忙，请稍候重试！">>};
		{ok, Result} ->
			Result
	end.

%% 创建试炼副本服务
create_training(TeamPid, From, SceneId, PlayerInfo) ->
	case catch gen:call(TeamPid, '$gen_call', {create_training, From, SceneId, PlayerInfo}, 2000) of
		{'EXIT', _Reason} ->
			{fail, <<"系统繁忙，请稍候重试！">>};
		{ok, Result} ->
			Result
	end.

%% 创建幻魔穴服务
create_cave(TeamPid, From, SceneId, PlayerInfo) ->
	case catch gen:call(TeamPid, '$gen_call', {create_cave, From, SceneId, PlayerInfo}, 2000) of
		{'EXIT', _Reason} ->
			{fail, <<"系统繁忙，请稍候重试！">>};
		{ok, Result} ->
			Result
	end.


%%创建夫妻副本服务
create_couple_dungeon(TeamPid, From, SceneId,CoupleName, PlayerInfo) ->
	case catch gen:call(TeamPid, '$gen_call', {create_couple_dungeon, From, SceneId,CoupleName, PlayerInfo}, 2000) of
		{'EXIT', _Reason} ->
			{fail, <<"系统繁忙，请稍候重试！">>};
		{ok, Result} ->
			Result
	end.

%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 申请加入队伍请求
handle_call('JOIN_TEAM_REQ', _From, State) ->
	Result =
		if
			length(State#team.member) < ?TEAM_MEMBER_MAX ->
				case State#team.auto_access of
					1 ->
						{ok, auto_join, State#team.leaderid};
					_ ->
                   		{ok, 1, State#team.leaderid}
				end;
			true ->
         		{ok, mb_max, State#team.leaderid}
   		end,
	{reply, Result, State};


%% 退出队伍
handle_call({'QUIT_TEAM', FromId, Scene, X, Y}, {From, _}, State) ->
    case lists:keyfind(From, 3, State#team.member) of
        false -> 			
            {reply, 0, State};
        Mb -> %%检查是否能退出队伍
			{Result, RetState} =						
                case length(State#team.member) of
                    0 -> 						
                        {0, State};
                    1 -> %%解散队伍
						case lib_scene:is_fst_scene(Scene) ==true orelse lib_scene:is_zxt_scene(Scene)==true of
							true ->
								case catch gen:call(Mb#mb.pid, '$gen_call', 'FST_OUTTEAM', 2000) of
									{'EXIT', _} ->
										ok;
									{ok, out_team} ->
										member_fst_leave_team(State, FromId);
									_ ->
										ok
								end;
							false ->%%退出试炼副本
								case lib_scene:is_training_scene(Scene) of
									true ->
										mod_training:quit(State#team.dungeon_pid,FromId,1);
									false ->
										ok
								end
						end,
                        lib_team:send_leaderid_area_scene(State#team.leaderid, 0, FromId, Scene, X, Y), %%告诉场景
                        gen_server:cast(self(), 'DISBAND'),
                        {1, State};
                    _Any -> %检查是否是队长退队
						[Dungeon_pid, Fst_pid] =
							case lib_scene:is_fst_scene(Scene) ==true orelse lib_scene:is_zxt_scene(Scene)==true of
								true ->
									case catch gen:call(Mb#mb.pid, '$gen_call', 'FST_OUTTEAM', 2000) of
										{'EXIT', _} ->
											[State#team.dungeon_pid, State#team.fst_pid];
										{ok, out_team} ->
											member_fst_leave_team(State, FromId);
										_ ->
											[State#team.dungeon_pid, State#team.fst_pid]
									end;
								false ->
									%%退出试炼副本
									case lib_scene:is_training_scene(Scene) of
										true ->
											mod_training:quit(State#team.dungeon_pid,FromId,1),
											[State#team.dungeon_pid, State#team.fst_pid];
										false ->
											[State#team.dungeon_pid, State#team.fst_pid]
									end
							end,
                        case From =:= State#team.leaderpid of
                            true ->									
                                %% 通知队员队伍队长退出了
                                NewMb = member_delete(Mb#mb.id,State#team.member),
								%%亲密度处理
								NewClose = lists:filter(fun({{IdA,IdB},_Close})-> IdA =/= FromId andalso IdB =/= FromId end, State#team.close),
								NewCloseRela = [{{IdA,IdB},_R} || {{IdA,IdB},_R} <- State#team.close_rela,IdA == FromId orelse IdB == FromId],
								team_close_cut(FromId,NewMb),
								ExistingMb = lists:filter(fun(R)->
																  R#mb.state == 1
														  end,
														  NewMb),
								case ExistingMb of
									[] ->
										lib_team:send_leaderid_area_scene(State#team.leaderid, 0, FromId, Scene, X, Y), %%告诉场景
                        				gen_server:cast(self(), 'DISBAND'),
                        				{1, State#team{dungeon_pid = Dungeon_pid, fst_pid = Fst_pid}};
									_ ->
										[H|_T] = ExistingMb,
                                		NewState = State#team{
											leaderid = H#mb.id, 
                                 			leaderpid = H#mb.pid, 
                                   			leadername = H#mb.nickname,
                                   			teamname = io_lib:format("~s的队伍",[H#mb.nickname]), 
                                   			member = NewMb,
											close = NewClose,
											close_rela = NewCloseRela					 
										},
                                		{ok, BinData} = pt_24:write(24011, State#team.leaderid),
                                		gen_server:cast(H#mb.pid, {'SET_PLAYER', [{leader, 1}]}),
                                		lib_team:send_leaderid_area_scene(State#team.leaderid, 0, FromId, Scene, X, Y),
                                		lib_team:send_leaderid_area_scene(H#mb.id, 1, FromId, Scene, X, Y), %%告诉场景
                                		send_team(NewState, BinData),
                                		send_team_info(NewState),
										%%队伍招募
										if State#team.team_type=/= 0->
											   gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'change_team_name',[self(),NewState#team.team_type,H#mb.nickname,H#mb.id,H#mb.lv,length(NewState#team.member)]});
										   true->skip
										end,
                                		{1, NewState#team{dungeon_pid = Dungeon_pid, fst_pid = Fst_pid}}
								end;
                            false ->								
                                %非队长退出
								%%亲密度处理	
                                NewMb = member_delete(Mb#mb.id,State#team.member),
								NewClose = lists:filter(fun({{IdA,IdB},_Close})-> IdA =/= Mb#mb.id andalso IdB =/= Mb#mb.id end, State#team.close),
								NewCloseRela = [{{IdA,IdB},_R} || {{IdA,IdB},_R} <- State#team.close_rela,IdA == Mb#mb.id orelse IdB == Mb#mb.id],
								NewState = State#team{member = NewMb,close = NewClose,close_rela=NewCloseRela},
								team_close_cut(Mb#mb.id,NewMb),														
                                {ok, BinData} = pt_24:write(24011, Mb#mb.id),
                                send_team(NewState, BinData),
								%% 通知场景
								lib_team:send_leaderid_area_scene(FromId, 0, Scene, X, Y),
								if State#team.team_type =/= 0->
									   gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'update_team_member',[self(),State#team.team_type,FromId,length(NewMb)]});
								   true->
									   gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_member',[FromId]})
								end,
                                {1, NewState#team{dungeon_pid = Dungeon_pid, fst_pid = Fst_pid}}
                        end
                end,				
			%% 更新队伍成员位置信息
			if
				Result =:= 1 ->
					{ok, TeamBinData} = pt_24:write(24022, [FromId, 0, 0, 0]),
					send_to_other_member(FromId, TeamBinData, RetState);
				true ->
					skip
			end,    
			{reply, Result, RetState}
    end;


%% 被邀请人回应加入队伍请求,FriendList是Uid这个玩家的
handle_call({'INVITE_RES', Uid, Lv, Pid, Nickname, X, Y, Realm, SceneId, SendPid, Career, Sex, HpLim, MpLim, FriendList}, _From, State) ->
	case lists:keyfind(Uid, #mb.id, State#team.member) of
        false ->
			if
       			length(State#team.member) < ?TEAM_MEMBER_MAX ->
					Member = #mb{
						id = Uid, 
						lv = Lv, 
						pid = Pid, 
						nickname = Nickname, 
						pid_send = SendPid, 
						realm = Realm,
						career = Career,
						sex = Sex,
						hp_lim = HpLim,
						mp_lim = MpLim,
						state = 1
					},
                  	%%亲密度处理
                   	State1 = State#team{
						member = [Member | State#team.member]
					},
                   	NewState = join_team_close(State1,Uid,FriendList),
                   	%%亲密度对玩家属性加成
                   	team_close_status(NewState, 1),
					
                   	%% 对其他队员进行队伍信息广播
					gen_server:cast(self(), {'INVITE_RES', Uid, SendPid}),
                   	{ok, BinData} = pt_11:write(11080, io_lib:format("~s加入了队伍",[Nickname])),
                  	send_team(NewState, BinData),
                   	%% 更新队伍队员位置信息
                    {ok, TeamBinData24022} = pt_24:write(24022, [Uid, X, Y, SceneId]),
                    send_team(NewState, TeamBinData24022),
					
                   	mod_delayer:update_delayer_info(Uid, self()),
                   	%% 加入队伍后更新小黑板
                  	mod_delayer:delete_blackboard_info(Uid),
                   	TeamLen=length(NewState#team.member),
                   	%% 队伍招募信息处理
                   	if 
						State#team.team_type =/= 0->
                      		gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'update_team_member',[self(),State#team.team_type,Uid,TeamLen]});
                        true->
                       		gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_member',[Uid]})
                   	end,
                   	{reply, {1, self(), TeamLen}, NewState};
          		true ->
                    {reply, mb_max, State}
            end;
        Teammate ->
            MB = lists:keydelete(Uid, #mb.id, State#team.member),
			Member = Teammate#mb{
				id = Uid, 
				lv = Lv, 
				pid = Pid, 
				nickname = Nickname, 
				pid_send = SendPid, 
				realm = Realm,
				career = Career,
				sex = Sex,
				state = 1
			},
            State1 = State#team{
				member = [Member | MB]
			},
            %%亲密度处理
            NewState = join_team_close(State1, Uid, FriendList),
            %%亲密度对玩家属性加成
            team_close_status(NewState, 1),
			            
            {reply, {1, self(), length(NewState#team.member)}, NewState}
    end;


%% 获取队伍信息
handle_call('GET_TEAM_INFO', _From, State) ->
    {reply, State, State};

%% 获取队伍信息（获取场景队伍信息使用）
handle_call('GET_SCENE_TEAM_INFO', _From, State) ->
	Num = length(State#team.member),
	Auto = State#team.auto_access,
    {reply, {Num, Auto}, State};

%% 修改队伍的分配方式
handle_call({'CHANGE_ALLOT_MODE', T, Uid}, _From, State) ->
    Result =        
        if
            Uid == State#team.leaderid ->
                NewState = State#team{allot = T},
                1;
            true ->
                NewState = State,
                0
        end,
    {reply, Result, NewState};

%% 委任队长
%% TOId 委任者ID
%% FromId 卸任者ID
%% FromScene 卸任者所在的场景
%% FromX 卸任者所在的X坐标
%% FromY 卸任者所在的Y坐标
handle_call({'CHANGE_LEADER', ToId, FromId, FromScene, FromX, FromY}, {From, _}, State) ->
    case From =:= State#team.leaderpid of
        %% 非队长无法委任队长
		false -> 
            {reply, not_leader, State};
        true ->
            case lists:keyfind(ToId, 2, State#team.member) of
                false -> 
                    {reply, not_team_member, State};
                Mb ->
					case misc:is_process_alive(Mb#mb.pid) of
						true ->
                    		NewState = State#team{
								leaderid = Mb#mb.id, 
								leaderpid = Mb#mb.pid, 
								leadername = Mb#mb.nickname,
								teamname = Mb#mb.nickname ++ "的队伍"
							},
             				gen_server:cast(Mb#mb.pid, {'SET_PLAYER', [{leader, 1}]}),
                    		%% 告诉场景, 队长更改
							%% 原队长周围人员
                    		lib_team:send_leaderid_area_scene(State#team.leaderid, 2, FromId, FromScene, FromX, FromY),
							%% 新队长周围人员
                    		lib_team:send_leaderid_area_scene(Mb#mb.id, 1, FromId, FromScene, FromX, FromY),			
                    		%%通知所有队员队长更改
                    		{ok, BinData} = pt_24:write(24012, [Mb#mb.id, State#team.auto_access]),
                    		send_team(NewState, BinData),
							%%队伍招募
							if State#team.team_type=/= 0->
								   gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'change_team_name',[self(),State#team.team_type,Mb#mb.nickname,Mb#mb.id,Mb#mb.lv,length(NewState#team.member)]});
							   true->skip
							end,
                    		{reply, 1, NewState};
						_ ->
							{reply, 0, State}
					end
            end
    end;


%% 获取副本pid
handle_call(get_dungeon, _From, State) ->
    {reply, State#team.dungeon_pid, State};

%% 创建队伍的副本服务
handle_call({create_dungeon, From, SceneId, PlayerInfo}, _From, State) ->
    case misc:is_process_alive(State#team.dungeon_pid) andalso State#team.dungeon_scene_res_id == SceneId  of
        true -> %%  非队长的队员加入副本
            mod_dungeon:join(State#team.dungeon_pid, PlayerInfo),
            {reply, {ok, State#team.dungeon_pid}, State}; 
        false ->
            [_Sceneid, Id, Pid, Pid_dungeon] = PlayerInfo,
            case Id =:= State#team.leaderid of %% 判断是否队长		[2010.12.01策划要求：非队长 也可创建副本] [2011.3.22策划要求：队长 才可创建副本]
                true ->
					Dungeon_true =
						case is_pid(State#team.dungeon_pid) of
							false ->
								false;
							true ->
								check_dungeon(State#team.member, Id)
						end,
					if
						Dungeon_true andalso State#team.dungeon_scene_res_id =/= undefined ->	%% 队伍有副本存在，不能再创建新副本
						   	{reply, {fail, <<"队伍已有其它副本存在，不能再创建新副本!">>}, State};
					   	Dungeon_true andalso State#team.fst_pid =/= [] ->
						   	{reply, {fail, <<"队伍已有封神台存在，不能再创建新副本!">>}, State};
					   	true ->
						   	{ok, Dungeon_pid} = mod_dungeon:start(self(), From, SceneId, [{Id, Pid, Pid_dungeon}]),
						   	Dungeon_scid = SceneId rem 10000,
						   	{ok,TeamBinData_BC} = pt_24:write(24030, Dungeon_scid),
						   	case Dungeon_scid of
							   	911 ->
									deliver_other_member(Id, TeamBinData_BC, SceneId, State);
							   	_ ->
									send_to_other_member(Id, TeamBinData_BC, State)
						   	end,
							%%队伍招募
							if State#team.team_type =/= 0->
								   gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_team_info',[self()]});
							   true->skip
							end,
							{reply, {ok, Dungeon_pid}, State#team{
													dungeon_pid = Dungeon_pid,
													dungeon_scene_res_id = SceneId}}
					end;
               false ->
                    {reply, {fail, <<"队长才能创建新副本!">>}, State}
            end
    end;

%% 创建队伍的封神台服务
handle_call({create_fst, From, SceneId, PlayerInfo}, _From, State) ->
	Fst_pid_list = State#team.fst_pid,
	[Fst_alive, Fst_pid_team] = 
		case lists:keysearch(SceneId, 1, Fst_pid_list) of
			{value,{SceneId, Fst_pid_tmp}} ->
				[misc:is_process_alive(Fst_pid_tmp), Fst_pid_tmp];
			_ ->
				[false, []]
		end,
    case Fst_alive of
        true -> %%  加入副本
            case mod_fst:join(Fst_pid_team, PlayerInfo) of
				true ->
					%%诛仙台人数限制为最多3为玩家
					if SceneId >1045 ->
						   if
							   length(State#team.member) >= 1 andalso length(State#team.member) < 4 ->
								   {reply, {ok, Fst_pid_team}, State};
							   true ->
								   [_Sceneid, Id, _Pid, _Pid_dungeon] = PlayerInfo,
								   gen_server:cast(State#team.dungeon_pid, {'RM_PLAYER', Id}),
								   {reply, {fail, <<"诛仙台组队模式只支持1到3位玩家,队伍人数过多！">>}, State}
						   end;
					   true->
						   {reply, {ok, Fst_pid_team}, State}
					   end;
				false->
            		{reply, {fail, <<"系统繁忙，请重试!">>}, State}
			end;
        false ->
            [Sceneid, Id, Pid, Pid_fst] = PlayerInfo,
			Dungeon_true =
				case is_pid(State#team.dungeon_pid) of
					false ->
						false;
					true ->
						check_dungeon(State#team.member, Id)
				end,
			if
				Dungeon_true andalso State#team.dungeon_scene_res_id =/= undefined andalso State#team.fst_pid =:= [] andalso SceneId<1046->	%% 队伍有副本存在，不能再创建新副本
					{reply, {fail, <<"队伍已有其它副本存在，不能再进入封神台!">>}, State};
				Dungeon_true andalso State#team.dungeon_scene_res_id =/= undefined andalso State#team.fst_pid =:= [] andalso SceneId>=1046->	%% 队伍有副本存在，不能再创建新副本
					{reply, {fail, <<"队伍已有其它副本存在，不能再进入诛仙台!">>}, State};
				SceneId>1045 andalso length(State#team.member) > 3->
					   {reply, {fail, <<"诛仙台组队模式只支持1到3位玩家！">>}, State};
				true ->
					{ok, Fst_pid} = mod_fst:start(self(), From, SceneId, [{Id, Pid, Pid_fst}],State#team.member),	
					F = fun(Mpid) ->
								gen_server:cast(Mpid, {'SET_PLAYER_FST', Sceneid, Fst_pid})
						end,
					[F(Mb#mb.pid) || Mb <- State#team.member],	%% 通知其它队员加入副本
					case SceneId rem 100 of
						1 ->
							{ok,TeamBinData_BC} = pt_24:write(24030,SceneId rem 10000),
							send_to_other_member(Id, TeamBinData_BC, State);
						46->
							{ok,TeamBinData_BC} = pt_24:write(24030,SceneId rem 10000),
							send_to_other_member(Id, TeamBinData_BC, State);
						_ ->
							ok
					end,
						Fst_pid_team_list = State#team.fst_pid,
						Fst_pid_team_list1 = lists:keydelete(SceneId, 1, Fst_pid_team_list),
						Fst_pid_team_list2 = lists:keymerge(1, Fst_pid_team_list1, [{SceneId, Fst_pid}]),
					%%队伍招募
					if State#team.team_type =/= 0->
						   gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_team_info',[self()]});
					   true->skip
					end,
                    	{reply, {ok, Fst_pid}, State#team{fst_pid = Fst_pid_team_list2, dungeon_pid = Fst_pid}}
			end 
%%                 false ->
%%                     {reply, {fail, <<"你不是队长不能创建副本!">>}, State}
%%             end
    end;

%% 创建队伍的副本服务
handle_call({create_td, From, SceneId, PlayerInfo}, _From, State) ->
    case misc:is_process_alive(State#team.dungeon_pid) andalso State#team.dungeon_scene_res_id == SceneId  of
        true -> %%  非队长的队员加入镇妖台
            case mod_td:join(State#team.dungeon_pid, PlayerInfo) of
				true ->
					if
						length(State#team.member) >= 1 andalso length(State#team.member) < 4 ->
							{reply, {ok, State#team.dungeon_pid}, State};
						true ->
							[_Sceneid, Id, _Pid, _Pid_dungeon] = PlayerInfo,
							gen_server:cast(State#team.dungeon_pid, {'RM_PLAYER', Id}),
							{reply, {fail, <<"多人镇妖台的队伍人数必须是 1 到 3 ！">>}, State}
					end;
				_ ->
					{reply, {fail, <<"超过60秒，无法进入镇妖台（多人）！">>}, State}
			end;
        false ->
            [_Sceneid, Id, Pid, Pid_dungeon] = PlayerInfo,
            case Id =:= State#team.leaderid of
                true ->
					if
						length(State#team.member) >= 1 andalso length(State#team.member) < 4 ->
							Dungeon_true =
								case is_pid(State#team.dungeon_pid) of
									false ->
										false;
									true ->
										check_dungeon(State#team.member, Id)
								end,
							if
								Dungeon_true andalso State#team.dungeon_scene_res_id =/= undefined ->	%% 队伍有副本存在，不能再创建新副本
%% 							?WARNING_MSG("team_create_dungeon_1_/~p/~n",[[State#team.dungeon_pid, State#team.dungeon_scene_res_id, SceneId, PlayerInfo]]),
						   			{reply, {fail, <<"队伍已有其它副本存在，不能再创建新镇妖台!">>}, State};
					   			Dungeon_true andalso State#team.fst_pid =/= [] ->
						   			{reply, {fail, <<"队伍已有封神台/诛仙台存在，不能再创建新镇妖台!">>}, State};
					   			true ->
						   			{ok, Dungeon_pid} = mod_td:start(self(), From, SceneId, [{Id, Pid, Pid_dungeon}],0),
						   			{ok,TeamBinData_BC} = pt_24:write(24030, SceneId rem 10000),
						   			send_to_other_member(Id, TeamBinData_BC, State),
									%%队伍招募
									if State#team.team_type =/= 0->
										   gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_team_info',[self()]});
									   true->skip
									end,
                    				{reply, {ok, Dungeon_pid}, State#team{
																dungeon_pid = Dungeon_pid,
																dungeon_scene_res_id = SceneId}}
							end;
						true ->
							{reply, {fail, <<"队伍人数必须是 1 到 3 才能创建新镇妖台！">>}, State}
					end;
               false ->
                    {reply, {fail, <<"队长才能创建新镇妖台!">>}, State}
            end
    end;

%% 创建队伍的试炼副本服务
handle_call({create_training, From, SceneId, PlayerInfo}, _From, State) ->
    case misc:is_process_alive(State#team.dungeon_pid) andalso State#team.dungeon_scene_res_id == SceneId  of
        true -> %% 已经有副本进程  非队长的队员加入试炼副本
            case mod_training:join(State#team.dungeon_pid, PlayerInfo) of
				true ->
					{reply, {ok, State#team.dungeon_pid}, State};
				_ ->
					{reply, {fail, <<"加入修炼副本失败！">>}, State}
			end;
        false ->
            [Id, Pid,Lv] = PlayerInfo,
            case Id =:= State#team.leaderid of
                true -> %%如果是队长
					if
						length(State#team.member) >= 1 ->
							Dungeon_true =
								case is_pid(State#team.dungeon_pid) of
									false ->
										false;
									true ->
										check_dungeon(State#team.member, Id)
								end,
							if
								Dungeon_true andalso State#team.dungeon_scene_res_id =/= undefined ->	%% 队伍有副本存在，不能再创建新副本
						   			{reply, {fail, <<"队伍已有其它副本存在，不能再创建试炼副本!">>}, State};
					   			Dungeon_true andalso State#team.fst_pid =/= [] ->
						   			{reply, {fail, <<"队伍已有封神台/诛仙台存在，不能再创建试炼副本!">>}, State};
					   			true ->
						   			case mod_training:start(self(), From, SceneId, {Id, Pid, Lv}) of
										{ok, Dungeon_pid}  ->
						   					{ok,TeamBinData_BC} = pt_24:write(24030, SceneId rem 10000),
						   					send_to_other_member(Id, TeamBinData_BC, State),
											%%队伍招募
											if State#team.team_type =/= 0->
						   							gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_team_info',[self()]});
					   							true->skip
											end,
                    						{reply, {ok, Dungeon_pid}, State#team{dungeon_pid = Dungeon_pid,dungeon_scene_res_id = SceneId}};
										_Err ->
											{reply,{<<"队伍创建试炼副本失败!">>},State}
									end
							end;
						true ->
							{reply, {fail, <<"队伍人数错误，不能创建试炼副本!">>}, State}
					end;
               false ->
                    {reply, {fail, <<"队长才能创建试炼副本!">>}, State}
            end
    end;

%% 创建队伍的幻魔穴服务
handle_call({create_cave, From, SceneId, PlayerInfo}, _From, State) ->
    case misc:is_process_alive(State#team.dungeon_pid) andalso State#team.dungeon_scene_res_id == SceneId of
        true -> %%  非队长的队员加入副本
            mod_cave:join(State#team.dungeon_pid, PlayerInfo),
            {reply, {ok, State#team.dungeon_pid}, State}; 
        false ->
            [Id, Pid, Pid_dungeon] = PlayerInfo,
            case Id =:= State#team.leaderid of %% 判断是否队长
                true ->
					IsTeamMemberInCave =
						case is_pid(State#team.dungeon_pid) of
							false ->
								false;
							true ->
								check_dungeon(State#team.member, Id)
						end,
					if
						IsTeamMemberInCave andalso State#team.dungeon_scene_res_id =/= undefined ->	%% 队伍有副本存在，不能再创建新副本
						   	{reply, {fail, <<"队伍已有其它副本存在，不能再创建新副本!">>}, State};
					   	IsTeamMemberInCave andalso State#team.fst_pid =/= [] ->
						   	{reply, {fail, <<"队伍已有封神台/诛仙台存在，不能再创建新副本!">>}, State};
					   	true ->
						   	{ok, DungeonPid} = mod_cave:start(self(), From, SceneId, [{Id, Pid, Pid_dungeon}]),
						   	Dungeon_scid = SceneId rem 10000,
						   	{ok,TeamBinData_BC} = pt_24:write(24030, Dungeon_scid),
						   	case Dungeon_scid of
							   	911 ->
									deliver_other_member(Id, TeamBinData_BC, SceneId, State);
							   	_ ->
									send_to_other_member(Id, TeamBinData_BC, State)
						   	end,
							NewState = State#team{
								dungeon_pid = DungeonPid,
								dungeon_scene_res_id = SceneId
							},
							%%队伍招募
							if State#team.team_type =/= 0->
							  	 gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_team_info',[self()]});
					  		 true->skip
							end,
                    		{reply, {ok, DungeonPid}, NewState}
					end;
               false ->
                    {reply, {fail, <<"队长才能创建新副本!">>}, State}
            end
    end;

%%创建夫妻副本
handle_call({create_couple_dungeon,From, SceneId,CoupleName, PlayerInfo},_From,State)->
	if length(State#team.member) /= 2 ->
		   {reply, {fail, <<"进入夫妻副本的队伍只允许夫妻二人!">>}, State};
	   true->
		   %%判断是否夫妻
		   case is_couple(State#team.member,tool:to_list(CoupleName)) of
			   false->
				   {reply, {fail, <<"进入夫妻副本的队伍只允许夫妻二人!">>}, State};
			   true->
				   case misc:is_process_alive(State#team.dungeon_pid) andalso State#team.dungeon_scene_res_id == SceneId of
					   true -> 
						   %%  非队长的队员加入副本
						   mod_couple_dungeon:join(State#team.dungeon_pid, PlayerInfo),
						   {reply, {ok, State#team.dungeon_pid}, State};
					   false ->
						   [_,Id, Pid, Pid_dungeon] = PlayerInfo,
						   case Id =:= State#team.leaderid of %% 判断是否队长
							   true ->
								   IsTeamMemberInCave =
									   case is_pid(State#team.dungeon_pid) of
										   false ->
											   false;
										   true ->
											   check_dungeon(State#team.member, Id)
									   end,
								   if
									   IsTeamMemberInCave andalso State#team.dungeon_scene_res_id =/= undefined ->	%% 队伍有副本存在，不能再创建新副本
										   {reply, {fail, <<"队伍已有其它副本存在，不能再创建夫妻副本!">>}, State};
									   IsTeamMemberInCave andalso State#team.fst_pid =/= [] ->
										   {reply, {fail, <<"队伍已有封神台/诛仙台存在，不能再创建夫妻副本!">>}, State};
									   true ->
										   {ok, DungeonPid} = mod_couple_dungeon:start(self(), From, SceneId, [{Id, Pid, Pid_dungeon}]),
										   Dungeon_scid = SceneId rem 10000,
										   {ok,TeamBinData_BC} = pt_24:write(24030, Dungeon_scid),
										   case Dungeon_scid of
											   911 ->
												   deliver_other_member(Id, TeamBinData_BC, SceneId, State);
											   _ ->
												   send_to_other_member(Id, TeamBinData_BC, State)
										   end,
										   NewState = State#team{
																 dungeon_pid = DungeonPid,
																 dungeon_scene_res_id = SceneId
																},
										   {reply, {ok, DungeonPid}, NewState}
								   end;
							   false ->
								   {reply, {fail, <<"队长才能创建夫妻副本!">>}, State}
						   end
				   end
		   end
	end;

%% 队员离开封神台
handle_call({'MEMBER_FST_QUIT',[Pid,Scene]},_From, TeamInfo) ->
	Member = TeamInfo#team.member,
	case check_member_fst_quit(Member,Pid,Scene,0) of
		{error,_}->
			{reply,error,TeamInfo};
		{ok,All_out}->
			case All_out of
				Val when Val =:= 0 orelse Val =:= 1 ->
					F = fun(ScInfo) ->
							{_Scid, P} = ScInfo,
							mod_fst:close_fst(P)
    					end,
					[F(Sc_pid_info)|| Sc_pid_info <- TeamInfo#team.fst_pid],
					{reply, ok,TeamInfo#team{dungeon_pid = undefined, fst_pid = []}};
				_ ->
					{reply,ok, TeamInfo}
			end
	end;

handle_call(_R, _From, State) ->
    {reply, _R, State}.


%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 解散队伍
handle_cast('DISBAND', State) ->
    {ok, BinData} = pt_24:write(24017, []),
    F = fun(Member) ->
		mod_delayer:update_delayer_info(Member#mb.id, undefined),
       	gen_server:cast(Member#mb.pid, {'SET_PLAYER', [{pid_team, undefined}, {leader, 0}]}),
		if
			Member#mb.pid_send =/= undefined ->
				lib_send:send_to_sid(Member#mb.pid_send, BinData);
			true ->
				skip
		end
   	end,
    [F(M)|| M <- State#team.member],
	%%队伍招募
	if State#team.team_type =/= 0->
		   gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_team_info',[self()]});
	   true->skip
	end,
    {stop, normal, State};

%% 更新队伍成员的血蓝数值信息
handle_cast({'UPDATE_TEAM_PLAYER_INFO', Data}, State) ->
    {ok, BinData} = pt_24:write(24021, Data),
	send_team(State, BinData),
    {noreply, State};

%% 修改队伍的组队方式
handle_cast({'CHANGE_ACCESS_MODE', AutoAccess, PlayerId, PidSend}, State) ->
    NewState =        
        if
            PlayerId =:= State#team.leaderid ->
				{ok, BinData} = pt_24:write(24052, [1, AutoAccess]),
				lib_send:send_to_sid(PidSend, BinData),
				%% 队伍招募
				if 
					State#team.team_type =/= 0->
						gen_server:cast(mod_team_raise:get_mod_team_raise_pid(), {'update_team_auto', [self(), State#team.team_type, AutoAccess]});
					true ->
						skip
				end,
            	State#team{
					auto_access = AutoAccess
				};
            true ->
				{ok, BinData} = pt_24:write(24052, [0, AutoAccess]),
				lib_send:send_to_sid(PidSend, BinData),
      			State
        end,
	{noreply, NewState};

%% 踢出队伍
handle_cast({'KICK_OUT', Uid, LeaderId, LeaderScid, PidSend}, State) ->
    case lists:keyfind(Uid, #mb.id, State#team.member) of
        false ->
            {ok, BinData} = pt_24:write(24009, 0),
            lib_send:send_to_sid(PidSend, BinData),
            {noreply, State};
        Mb ->
            Team_dungeon =
                case lib_player:get_online_info_fields(Uid, [scene]) of
                    [] ->
                        false;
                    [SceneId] ->
                        (lib_scene:is_dungeon_scene(SceneId) andalso lib_scene:is_dungeon_scene(LeaderScid)) orelse lib_scene:is_td_scene(SceneId)
                end,
            case Team_dungeon of
                false ->
                    mod_delayer:update_delayer_info(Uid, undefined),
					NewMb = member_delete(Uid, State#team.member),
                    %%亲密度处理
                    NewClose = lists:filter(fun({{IdA,IdB},_Close})-> IdA =/= Uid andalso IdB =/= Uid end, State#team.close),
                    NewCloseRela = [{{IdA,IdB},_R} ||{{IdA,IdB},_R} <- State#team.close_rela,IdA == Uid orelse IdB == Uid],
                    CloseState = State#team{member = NewMb,close = NewClose,close_rela=NewCloseRela},
                    team_close_cut(Uid,NewMb),
                    [DungeonPid, FstPid] =
                        if
                            is_pid(CloseState#team.dungeon_pid) ->  %% 先传出副本
                                ScId = CloseState#team.dungeon_scene_res_id,
                                case ScId =:= 998 orelse ScId =:=999 of
                                    true ->
                                        mod_td:quit(CloseState#team.dungeon_pid, Uid, 1),
                                        mod_td:clear(CloseState#team.dungeon_pid);
                                    false ->
                                        case ScId == 901 of
                                            true ->
                                                mod_training:quit(CloseState#team.dungeon_pid, Uid, 1);
                                            false ->
                                                mod_dungeon:quit(CloseState#team.dungeon_pid, Uid, 1),
                                                mod_dungeon:clear(CloseState#team.dungeon_pid)
                                        end
                                end,
                                case catch gen:call(Mb#mb.pid, '$gen_call', 'FST_OUTTEAM', 2000) of
                                    {'EXIT', _} ->
                                        [CloseState#team.dungeon_pid, CloseState#team.fst_pid];
                                    {ok, out_team} ->
                                        member_fst_leave_team(CloseState, Uid, LeaderId, LeaderScid);
                                    _ ->
                                        [CloseState#team.dungeon_pid, CloseState#team.fst_pid]
                                end;
                       	true -> [CloseState#team.dungeon_pid, CloseState#team.fst_pid]
                    end,
                    gen_server:cast(Mb#mb.pid, {'SET_PLAYER', [{pid_dungeon,undefined},{pid_team, undefined},{pid_fst,[]},{leader, 0}]}),					
                    {ok, BinData} = pt_24:write(24011, Mb#mb.id),
                    send_team(State, BinData),
                    {ok, BinData1} = pt_11:write(11080,io_lib:format("~s被队长请出队伍",[Mb#mb.nickname])),
                    send_team(CloseState, BinData1),
                    %% 更新队伍成员位置信息
                    {ok, BinData24022} = pt_24:write(24022, [Uid, 0, 0, 0]),
					send_team(CloseState, BinData24022),
                    %% 队伍招募信息处理
                    if 
                        State#team.team_type =/= 0->
                            gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'update_team_member',[self(),CloseState#team.team_type,Uid,length(CloseState#team.member)]});
                        true->
                            skip
                    end,
                    NewState = CloseState#team{
                        dungeon_pid = DungeonPid, 
                        fst_pid = FstPid
                    },
                    {ok, BinData24009} = pt_24:write(24009, 1),
                    lib_send:send_to_sid(PidSend, BinData24009),
                    {noreply, NewState};
                true ->
                    {ok, BinData} = pt_24:write(24009, 4),
                    lib_send:send_to_sid(PidSend, BinData),
                    {noreply, State}
            end
    end;


%% 封神台闯关播报
handle_cast({'BC_FST_KILL_BOSS_TEAM', Loc, Monname}, State) ->
%%     mod_scene:leave_scene(Status#player.id, Status#player.scene, 
%% 						  Status#player.other#player_other.pid_scene,
%% 						  Status#player.x, Status#player.y),
	case length(State#team.member) of
		1 ->
			case State#team.member of
				[R] ->
					gen_server:cast(R#mb.pid, {'BC_FST_KILL_BOSS', Loc, Monname}),
					{noreply, State};
				_ ->
					{noreply, State}
			end;
		_ ->
			Member = State#team.member,
			ConTent_PL = lists:foldl(fun(R, Sum) ->
											 case R#mb.pid of
												undefined ->
													Sum;
												_ ->
%% 													case lib_player:get_online_info_fields(R#mb.pid, [id, nickname, career, sex, realm]) of
%% 														[] -> Sum;
%% 														[PlayerId, Nickname, Career, Sex, Realm] ->
															NameColor = data_agent:get_realm_color(R#mb.realm),
															Sum++io_lib:format("【<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'><u>~s</u></font></a>】",[R#mb.id, R#mb.nickname, R#mb.career, R#mb.sex, NameColor, R#mb.nickname])
%% 														_ -> Sum
%% 													end
											 end
									 end,
									 [], Member),
			if 
				Loc =< 45 ->
				   ConTent = io_lib:format("~s杀入封神台第<font color='#FFFF32'>~p</font>层，将<font color='#8800FF'> ~s </font>围殴致死，顺利通关。",[ConTent_PL, Loc, Monname]),
				   lib_chat:broadcast_sys_msg(2, ConTent);
				Loc-45>=12->
					ConTent = io_lib:format("~s杀入诛仙台第<font color='#FFFF32'>~p</font>层，将<font color='#8800FF'> ~s </font>围殴致死，顺利通关。",[ConTent_PL, Loc-45, Monname]),
					lib_chat:broadcast_sys_msg(2, ConTent);
			   true->skip
			end,
    		{noreply, State}
	end;

%% 封神台闯关播报
handle_cast({'SET_FST_GOD_TEAM', Loc, Thru_time, Action}, State) ->
%%     mod_scene:leave_scene(Status#player.id, Status#player.scene, 
%% 						  Status#player.other#player_other.pid_scene,
%% 						  Status#player.x, Status#player.y),
	case length(State#team.member) of
		1 ->
			case State#team.member of
				[R] ->
					gen_server:cast(R#mb.pid, {'SET_FST_GOD', Loc, Thru_time, Action, true}),
					{noreply, State};
				_ ->
					{noreply, State}
			end;
		_ ->
			Member = State#team.member,
			ConTent_PL = lists:foldl(fun(R, Sum) ->
											case R#mb.pid of
												undefined ->
													Sum;
												_ ->
													if Loc < 46  ->
														case db_agent:ver_gods(Loc, R#mb.id) of
															[] ->
																case lib_player:get_online_info_fields(R#mb.pid, [scene]) of
																	[] -> Sum;
																	[Scene] ->
																		case lib_scene:is_fst_scene(Scene) of
																			true->
																				NameColor = data_agent:get_realm_color(R#mb.realm),
																				gen_server:cast(R#mb.pid, {'SET_FST_GOD', Loc, Thru_time, add_checked, false}),
																				Sum++io_lib:format("【<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'><u>~s</u></font></a>】",[R#mb.id, R#mb.nickname, R#mb.career, R#mb.sex, NameColor, R#mb.nickname]);
																			false->
																				Sum
																		end;
																	_ -> Sum
																end;
															_ ->
																%%30的封神台霸主，其他玩家符合条件登上的话，会清除掉原来的所有霸主；所以要把该队伍的所有玩家都写入霸主榜
																if Loc >=30->
																	   case lib_player:get_online_info_fields(R#mb.pid, [scene]) of
																		   [] -> Sum;
																		   [Scene] ->
																			   case lib_scene:is_fst_scene(Scene) of
																				   true->
																					   NameColor = data_agent:get_realm_color(R#mb.realm),
																					   gen_server:cast(R#mb.pid, {'SET_FST_GOD', Loc, Thru_time, add_checked, false}),
																					   Sum++io_lib:format("【<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'><u>~s</u></font></a>】",[R#mb.id, R#mb.nickname, R#mb.career, R#mb.sex, NameColor, R#mb.nickname]);
																					false->
																						Sum
																			   end;
																		   _ -> Sum
																	   end;
																   true->
																		Sum
																end
														end;
													   true->
														   case db_agent:ver_gods_zxt(Loc-45, R#mb.id) of
																[] ->
																	case lib_player:get_online_info_fields(R#mb.pid, [scene]) of
																		[] -> Sum;
																		[Scene] ->
																			case lib_scene:is_zxt_scene(Scene) of
																				true->
																					NameColor = data_agent:get_realm_color(R#mb.realm),
																					gen_server:cast(R#mb.pid, {'SET_FST_GOD', Loc, Thru_time, add_checked, false}),
																					Sum++io_lib:format("【<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'><u>~s</u></font></a>】",[R#mb.id, R#mb.nickname, R#mb.career, R#mb.sex, NameColor, R#mb.nickname]);
																				false->
																					Sum
																			end;
																		_ -> Sum
																	end;
																_ ->
																	%%18层以上的诛仙台霸主，其他玩家符合条件登上的话，会清除掉原来的所有霸主；所以要把该队伍的所有玩家都写入霸主榜
																	if Loc-45 >= 20->
																		   case lib_player:get_online_info_fields(R#mb.pid, [scene]) of
																			   [] -> Sum;
																			   [Scene] ->
																				   case lib_scene:is_zxt_scene(Scene) of
																					   true->
																						   gen_server:cast(R#mb.pid, {'SET_FST_GOD', Loc, Thru_time, add_checked, false}),
																						   NameColor = data_agent:get_realm_color(R#mb.realm),
																						   Sum++io_lib:format("【<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'><u>~s</u></font></a>】",[R#mb.id, R#mb.nickname, R#mb.career, R#mb.sex, NameColor, R#mb.nickname]);
																					   false->
																						   Sum
																				   end;
																				_ -> Sum
																			end;
																	   true->
																			Sum
																	end
															end
													end
											end
									 end,
								[], Member),
			case ConTent_PL of
				[] ->
					ok;
				_ ->
					if
						Loc >= 14 andalso Loc < 46 ->
							ConTent = io_lib:format("恭喜~s以掩耳不及迅雷之势打通封神台第<font color='#FFFF32'>~p</font>层，登上<font color='#8800FF'> 霸主 </font>宝座。",[ConTent_PL, Loc]),
							lib_chat:broadcast_sys_msg(2, ConTent);
%% 							case Loc >= 45 of
%% 								true ->
%% 									%%通知旧的称号刷新
%% 									lib_title:change_sever_titles(fst, Ids);
%% 								false ->
%% 									skip
%% 							end;
						Loc-45>=12->
							ConTent = io_lib:format("恭喜~s以掩耳不及迅雷之势打通诛仙台第<font color='#FFFF32'>~p</font>层，登上<font color='#8800FF'> 霸主 </font>宝座。",[ConTent_PL, Loc-45]),
							lib_chat:broadcast_sys_msg(2, ConTent);
%% 							case (Loc-45) >= 30 of
%% 								true ->
%% 									%%通知旧的称号刷新
%% 									lib_title:change_sever_titles(zxt, Ids);
%% 								false ->
%% 									skip
%% 							end;
						true ->
							ok
					end,
					if Loc<46->db_agent:clear_gods(Loc, Thru_time);
					   Loc>=46 andalso Loc=<65->
						   db_agent:clear_gods_zxt(Loc-45, Thru_time);
					   true->skip
					end
			end,
    		{noreply, State}
	end;

%%更新队伍中保存的亲密度
handle_cast({'ADD_TEAM_CLOSE', IdA, IdB, NewRela}, State) ->
	TempClose = lists:keydelete({IdA,IdB}, 1, State#team.close),
	TempClose1 = lists:keydelete({IdB,IdA}, 1, TempClose),
	NewCloses = TempClose1 ++ [{{IdA,IdB},NewRela#ets_rela.close}] ++ [{{IdB,IdA},NewRela#ets_rela.close}],
	TempRela = 
		case lists:keyfind({IdA,IdB}, 1, State#team.close_rela) of
			false -> lists:keydelete({IdB,IdA}, 1, State#team.close_rela);
			_ ->lists:keydelete({IdA,IdB}, 1, State#team.close_rela)
		end,
	NewRela1 = TempRela ++ [{{IdA,IdB},NewRela}],					
	NewState = State#team{close = NewCloses, close_rela = NewRela1},
	%%即时更新亲密度到队伍头像
	pack_close(NewState#team.member, NewState#team.close),
	{noreply, NewState};


%% 队长回应加入队伍申请
%% LeaderPidSend 队长的发送Pid
handle_cast({'JOIN_TEAM_RESPONSE', Uid, LeaderPidSend}, State) ->
	%% 队伍是否满人
	if
  		length(State#team.member) >= ?TEAM_MEMBER_MAX ->
			{ok, BinData} = pt_24:write(24002, 2),
           	lib_send:send_to_uid(Uid, BinData),
			{noreply, State};
      	true ->
            %% 检查申请人是否在线	
            case lib_player:get_player_pid(Uid) of
                [] ->
					{ok, BinData} = pt_24:write(24004, 0),
                  	lib_send:send_to_sid(LeaderPidSend, BinData),
					{noreply, State};
                Pid ->
                    case catch gen_server:call(Pid, {relaship, Uid, self()}) of
                        [List, Nickname, SceneId, X, Y, Lv, Realm, SendPid, Career, Sex, HpLim, MpLim] ->
                            mod_delayer:update_delayer_info(Uid, self()),
                            %% 檫黑板
                            mod_delayer:delete_blackboard_info(Uid),
							Member = #mb{
								id = Uid, 
								pid = Pid, 
								nickname = Nickname, 
								pid_send = SendPid, 
								realm = Realm,
								lv = Lv,
								career = Career,
								sex = Sex,
								hp_lim = HpLim,
								mp_lim = MpLim,
								state = 1
							},
                            NewMemberList = [Member | State#team.member],
                            %% 亲密度处理
                            State1 = State#team{member = NewMemberList},
                            NewTeam = join_team_close(State1,Uid,List),
                            %% 对其他队员进行队伍信息广播
                            team_close_status(NewTeam, 1),							
							%% 广播队伍信息
							Data = [
        						NewTeam#team.leaderid,
        						NewTeam#team.teamname,
								NewTeam#team.team_type,
        						pack_member(NewTeam#team.member, NewTeam#team.close)
    						],
    						{ok, BinData24010} = pt_24:write(24010, Data),
                            {ok, BinData11080} = pt_11:write(11080, io_lib:format("~s加入了队伍",[Nickname])),
                            %% 更新队伍队员位置信息
                            {ok, BinData24022} = pt_24:write(24022, [Uid, X, Y, SceneId]),
							F = fun(M) ->
								if
									M#mb.id =/= Uid ->
										gen_server:cast(M#mb.pid, {'MEMBER_JOIN_TEAM', SendPid, BinData24010, BinData11080, BinData24022});
									true ->
										lib_send:send_to_sid(SendPid, BinData24010),
										lib_send:send_to_sid(SendPid, BinData11080),
										lib_send:send_to_sid(SendPid, BinData24022)
								end
    						end,
    						[F(M)|| M <- NewTeam#team.member],
							
							TeamRaiseMsg = 
                            	if 
                                	State#team.team_type =/= 0->
                                  		{'update_team_member', [self(), State#team.team_type, Uid, length(NewMemberList)]};
                                	true->
                                   		{'del_member', [Uid]}
                            	end,
							gen_server:cast(mod_team_raise:get_mod_team_raise_pid(), TeamRaiseMsg),
							
							{ok, BinData24004} = pt_24:write(24004, 1),
                          	lib_send:send_to_sid(LeaderPidSend, BinData24004),
                         	{ok, BinData24002} = pt_24:write(24002, 1),
                          	lib_send:send_to_sid(SendPid, BinData24002),
							{noreply, NewTeam};
						%% 申请人加入其他队伍
						have_team ->
							{ok, BinData} = pt_24:write(24004, 2),
                          	lib_send:send_to_sid(LeaderPidSend, BinData),
							{noreply, State};
                        _ ->
							{ok, BinData} = pt_24:write(24004, 0),
                  			lib_send:send_to_sid(LeaderPidSend, BinData),
							{noreply, State}
                    end
            end
	end;

%% 被邀请人回应加入队伍请求
handle_cast({'INVITE_RES', PlayerId, SendPid}, State) ->
	send_team_info(State),
	get_teammate_position(State#team.member, PlayerId, SendPid),
	{noreply, State};

		
%% 队员下线
handle_cast({'MARK_LEAVES', PlayerId, Nick, Career, Lv, Hp, Hp_lim, Mp, Mp_lim, Sex, SceneId}, State) ->
	%% 单人镇妖塔不对队伍处理
	case lib_scene:is_td_scene(SceneId) andalso length(State#team.member) == 1 of
		true ->
			{noreply, State};
		false ->
            Mb = member_delete(PlayerId, State#team.member),
            NewClose = lists:filter(fun({{IdA,IdB},_Close})-> IdA =/= PlayerId andalso IdB =/= PlayerId end, State#team.close),
			NewCloseRela = lists:filter(fun({{IdA,IdB},_R})-> IdA =/= PlayerId andalso IdB =/= PlayerId end, State#team.close_rela),           
            team_close_cut(PlayerId,Mb),
			%% 在线成员
            OnlineMb = lists:filter(fun(R)-> R#mb.state == 1 end, Mb),
            NewMb = [#mb{id = PlayerId, pid = undefined, nickname = Nick, state = 0, 
                               career = Career, lv = Lv, hp = Hp, hp_lim = Hp_lim, 
                               mp = Mp, mp_lim = Mp_lim, sex = Sex, pid_send = undefined} | Mb],
            if
                OnlineMb =:= [] ->
					if State#team.team_type=/= 0->
						   gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_team_info',[self()]});
					   true->skip
					end,
                    {stop, normal, State};
                State#team.leaderid =:= PlayerId ->
                    [H | _T] = OnlineMb,
                    NewState = State#team{
						leaderid = H#mb.id,
                      	leaderpid = H#mb.pid,
                    	leadername = H#mb.nickname,
                     	teamname = io_lib:format("~s的队伍",[H#mb.nickname]),
                      	member = NewMb,
                     	close = NewClose,
                    	close_rela = NewCloseRela 
                 	},
                    gen_server:cast(H#mb.pid, {'SET_PLAYER', [{leader, 1}]}),
                    lib_team:send_leaderid_area_scene(H#mb.id, 1, PlayerId, 200, 1, 1), %%告诉场景
                    send_team_info(NewState),
                    {ok, BinData} = pt_24:write(24023, [0, PlayerId]),
                    send_team(NewState, BinData),
					%%队伍招募
					if State#team.team_type=/= 0->
						   gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'change_team_name',[self(),State#team.team_type,H#mb.nickname,H#mb.id,H#mb.lv,length(NewState#team.member)]});
					   true->skip
					end,
                    {noreply, NewState};
                true ->
                    NewState = State#team{member = NewMb,close = NewClose,close_rela=NewCloseRela},
                    {ok, BinData} = pt_24:write(24023, [0, PlayerId]),
                    send_team(NewState, BinData),
                    {noreply, NewState}
            end
	end;

%% 邀请加入组队
%% PlayerId 邀请人ID
%% NickName 邀请人名字
%% Uid 被邀请人
handle_cast({'INVITE_REQ', PlayerId, NickName, Lv, Uid, PidSend, Type}, State) ->
	%% 是否队长
	case PlayerId =:= State#team.leaderid of
   		true ->
            %% 检查队伍人数			
            case length(State#team.member) >= ?TEAM_MEMBER_MAX of
                true ->
					{ok, BinData} = pt_24:write(24006, 3),
             		lib_send:send_to_sid(PidSend, BinData);
                false ->
					%% 检查被邀请人是否在线					 
                    case lib_player:get_online_info_fields(Uid, [pid_team, pid_send, status, scene]) of
                  		[] ->
							{ok, BinData} = pt_24:write(24006, 5),
                            lib_send:send_to_sid(PidSend, BinData);
                     	[PidTeam, SendPid, Sta, SceneId] ->
                            %% 战场状态不能组队
                            case lib_arena:is_arena_scene(SceneId) orelse SceneId =:= ?SKY_RUSH_SCENE_ID of
                                false ->
                                    %% 氏族副本状态不能组队
                                    case lib_box_scene:is_box_scene_idsp_for_team(SceneId, Uid) of
                                        false ->
											%% 被邀请人是否在副本里
                                            case 
													lib_scene:is_dungeon_scene(SceneId) 
													orelse lib_scene:get_scene_id_from_scene_unique_id(SceneId) =:= ?DUNGEON_SINGLE_SCENE_ID 
													orelse lib_scene:is_std_scene(SceneId) 
											of	
												true ->		
													{ok, BinData} = pt_24:write(24006, 9),
                            						lib_send:send_to_sid(PidSend, BinData);
                                                false ->
                                                    case Sta =:= 7 of
                                                        %% 被邀请人凝神修练中
														true ->
															{ok, BinData} = pt_24:write(24006, 10),
                            								lib_send:send_to_sid(PidSend, BinData);
                                                        false ->
                                                            case is_pid(PidTeam) of
                                                                true ->	%% 检查被邀请人是否加入了队伍
                                                                    case PidTeam == self() of
                                                                        true ->
																			{ok, BinData} = pt_24:write(24006, 1),
                            												lib_send:send_to_sid(PidSend, BinData);
                                                                        _ ->
																			{ok, BinData} = pt_24:write(24006, 2),
                            												lib_send:send_to_sid(PidSend, BinData)
                                                                    end;
                                                                false -> %% 被邀请人是否已经在我们的队伍中
                                                                    case lists:keyfind(Uid, 2, State#team.member) of
                                                                        false ->
																			{ok, BinData} = pt_24:write(24007, [PlayerId, NickName, Lv, State#team.teamname, Type]),
																			lib_send:send_to_sid(SendPid, BinData),
																			{ok, MsgBinData} = pt_11:write(11080, "邀请入队请求已发出，等待对方回应"),
    																		lib_send:send_to_sid(PidSend, MsgBinData);
                                                                        _ ->
																			{ok, BinData} = pt_24:write(24006, 1),
                            												lib_send:send_to_sid(PidSend, BinData)
                                                                    end
                                                            end
                                                    end
                                            end;
                                        true ->
											{ok, BinData} = pt_24:write(24000, [6, [], 1]),
                            				lib_send:send_to_sid(PidSend, BinData)
                                    end;
                                true ->
									{ok, BinData} = pt_24:write(24006, 11),
                            		lib_send:send_to_sid(PidSend, BinData)
                            end
                     end
            end;
		false ->
			{ok, BinData} = pt_24:write(24006, 4),
    		lib_send:send_to_sid(PidSend, BinData)
    end,
	{noreply, State};
	
%% 队伍聊天
handle_cast({'TEAM_CHAT', BinData}, State) ->
    send_team(State, BinData),
    {noreply, State};

%% 查看队伍信息
handle_cast({'SEND_TEAM_INFO', PidSend}, State) ->
    Data = [
		State#team.leaderid, 
		length(State#team.member),
		State#team.leadername, 
		State#team.teamname, 
		State#team.auto_access
	],
    {ok, BinData} = pt_24:write(24016, Data),
	lib_send:send_to_sid(PidSend, BinData),
    {noreply, State};

%% 队员下线后再登录
handle_cast({'RE_JOIN_TEAM', FriendList, PlayerId, SceneId, X, Y, SendPid}, State) ->
	NewClose = lists:filter(fun({{IdA,IdB},_Close})-> IdA =/= PlayerId andalso IdB =/= PlayerId end, State#team.close),
	NewRelas = lists:filter(fun({{IdA,IdB},_R})-> IdA =/= PlayerId andalso IdB =/= PlayerId end, State#team.close_rela),
    NewTeam = join_team_close(State#team{close = NewClose, close_rela = NewRelas}, PlayerId, FriendList),
	team_close_status(NewTeam,1),
	
	%% 向队伍所有成员发送队伍信息
	send_team_info(NewTeam),
	
	%% 更新队伍队员位置信息
  	{ok, TeamBinData24022} = pt_24:write(24022, [PlayerId, X, Y, SceneId]),
    send_team(NewTeam, TeamBinData24022),
	
	%% 队员上线通知
  	{ok, BinData24023} = pt_24:write(24023, [1, PlayerId]),
  	send_team(NewTeam, BinData24023),

	%% 获取队员位置信息
	get_teammate_position(State#team.member, PlayerId, SendPid),
	case length(NewTeam#team.member) == 1 andalso lib_scene:is_td_scene(SceneId) of
		true ->
			lib_team:send_leaderid_area_scene(NewTeam#team.leaderid, 1, SceneId, X, Y);
		false ->
			skip
	end,
    {noreply, NewTeam};

%% 广播给队员
handle_cast({'SEND_TO_MEMBER', Bin}, State) ->
    send_team(State, Bin),
    {noreply, State};

%% 广播给其他队员
handle_cast({'SEND_TO_OTHER_MEMBER', SelfId, Bin}, State) ->
	send_to_other_member(SelfId, Bin, State),
    {noreply, State};

%% 共享组队打怪经验
%% Exp 怪的经验
handle_cast({'SHARE_TEAM_EXP', Data}, Team) ->
    %% 队员个数
	[_Rid, _MonExp, _MonSprit, _MonHExp, _MonHSpr, _MonId, 
							SceneId, _Rx, _Ry, _Rlv, _Stype, MonType, _MonId2] = Data,
	TeamNum = length(Team#team.member),
	F = fun(Member) ->
  		case is_pid(Member#mb.pid) of
			true ->
				{ExpParam,_MpParam,_HpParam,_Ap,_MaxAttackParam,_MaxClose,_IdA,_IdB} = team_max_close(Team,Member#mb.id),
				gen_server:cast(Member#mb.pid, {'SHARE_TEAM_EXP', [{TeamNum,ExpParam} | Data]});
            _ ->
           		skip
        end
    end,
	NewCloseRela =
		case SceneId > 900 orelse lists:member(SceneId,data_agent:get_hook_scene_list()) of
			true ->
				%% 组队好友获得亲密度
				F2 = fun(Rela) ->
					{{IdA,IdB},R} = Rela,
					%% 独立的函数，返回最新的close_rela
					lib_relationship:add_mon_close(pk_mon, IdA, IdB, R, [MonType, self()])
				end,
				[F2(Rela) || Rela <- Team#team.close_rela];
			false ->
				Team#team.close_rela
		end,
	NewTeam = Team#team{
		close_rela = NewCloseRela
	},
    [F(M) || M <- NewTeam#team.member],
    {noreply, NewTeam};

%% 清除队伍副本
handle_cast({clear_dungeon}, State) ->
	NewState = State#team{dungeon_pid = undefined, 
						  dungeon_scene_res_id = undefined},
    {noreply, NewState};

%% 清除队伍封神台
handle_cast({clear_fst, Scid}, State) ->
	Fst_pid_list = State#team.fst_pid,
	Fst_pid_list1 = lists:keydelete(Scid, 1, Fst_pid_list),
	NewState = State#team{fst_pid = Fst_pid_list1},
    {noreply, NewState};

%% 同步队友位置信息
handle_cast({'SYNC_TEAMMATE_POSITION', PlayerId, X, Y, SceneId}, State) ->
	{ok, BinData} = pt_24:write(24022, [PlayerId, X, Y, SceneId]),
	send_to_other_member(PlayerId, BinData, State),
    {noreply, State};

%%招募公告
handle_cast({raise_msg, [Status, Type]},State)->
	if Type =/= 0->
		   if State#team.leaderid =:= Status#player.id ->
				  gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'raise_msg',[Status,self(),State,Type]}),
				  NewState=State#team{team_type=Type};
			  true->NewState=State
		   end;
	   true->NewState=State
	end,
	{noreply,NewState};

%% 集合队伍
handle_cast({'raise_call', [Status, Type]}, State)->
	case length(State#team.member) > 1 of
		true ->
			{PType,NpcId} = get_raise_place(Type),
			{ok, BinData} = pt_24:write(24029, [Type, PType, NpcId, Status#player.nickname]),
			F = fun(M) ->
						if
							M#mb.pid_send /= undefined ->
								lib_send:send_to_sid(M#mb.pid_send, BinData);
							true ->
								lib_send:send_to_uid(M#mb.id, BinData)
						end
				end,
			[F(M) || M <- State#team.member, M#mb.id =/= Status#player.id],
			NewState = State#team{team_type = Type},
			gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'ADD_TO_TEAM_RAISE',[Status,self(),NewState,Type]});
		false ->
			NewState = State
	end,
	{noreply,NewState};

%% 队员离开封神台
handle_cast({'MEMBER_FST_QUIT',[Pid,Scene]}, TeamInfo) ->
	Member = TeamInfo#team.member,
	case check_member_fst_quit(Member,Pid,Scene,0) of
		{error,_}->
			{noreply,TeamInfo};
		{ok,All_out}->
			case All_out of
				Val when Val =:= 0 orelse Val =:= 1 ->
					F = fun(ScInfo) ->
							{_Scid, P} = ScInfo,
							mod_fst:close_fst(P)
    					end,
					[F(Sc_pid_info)|| Sc_pid_info <- TeamInfo#team.fst_pid],
					{noreply,TeamInfo#team{dungeon_pid = undefined, fst_pid = []}};
				_ ->
					{noreply,TeamInfo}
			end
	end;


handle_cast(_R, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info({team_info_out_put}, State) ->
%%?DEBUG("team_info_out_put_______/~p ~n", [[State#team.dungeon_pid, State#team.dungeon_scene_res_id, State#team.fst_pid]]),
	erlang:send_after(10 * 1000, self(), {team_info_out_put}),
	{noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_R, _State) ->
	%%?DEBUG("____________________________________terminate_____________________________________________",[]),
	misc:delete_monitor_pid(self()),
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra)->
    {ok, State}.

%%=========================================================================
%% 业务处理函数
%%=========================================================================
%% 组装队员列表
pack_member(MemberList, CloseList) when is_list(MemberList) ->
	F = fun(Member) ->
		%% 组装此队员与其他队员之间的亲密度(不能放自己的)
		Closes = [{PlayerId,Close} || {{IdA,PlayerId},Close} <- CloseList, IdA == Member#mb.id],
		[Hp, Mp] =
            if
                Member#mb.pid =:= undefined orelse Member#mb.state =:= 0 ->
                    [Member#mb.hp_lim, Member#mb.mp_lim];
                true ->
                    case lib_player:get_online_info_fields(Member#mb.pid, [hp, mp]) of 
                        [] ->
                            [Member#mb.hp_lim, Member#mb.mp_lim];
                        Ret ->
                            Ret
                    end
            end,
		[Member#mb.id, Member#mb.lv, Member#mb.career, Member#mb.realm, Member#mb.nickname, 0, Hp, Member#mb.hp_lim, Mp, Member#mb.mp_lim, Member#mb.sex, Closes]
    end,
    [F(Member)|| Member <- MemberList].

%% 即时更新亲密度到队伍头像
pack_close(MemberList,CloseList) ->
	F = fun(Mb) -> 
		Closes = [{PlayerId,Close} || {{IdA,PlayerId},Close} <- CloseList, IdA == Mb#mb.id],
		{ok,BinData} = pt_24:write(24024, [Closes]),
		lib_send:send_to_sid(Mb#mb.pid_send, BinData)
	end,
	[F(Member)|| Member <- MemberList, Member#mb.pid_send /= undefined].


%% 向队伍所有成员发送队伍信息
%% TeamState 队伍信息
send_team_info(TeamState) ->
    Data = [
        TeamState#team.leaderid,
        TeamState#team.teamname,
		TeamState#team.team_type,
        pack_member(TeamState#team.member, TeamState#team.close)
    ],
    {ok, BinData} = pt_24:write(24010, Data),
    send_team(TeamState, BinData).


%% 向所有队员发送信息
send_team(TeamState, BinData) ->
	Members = lists:filter(fun(_e) -> _e /= [] end, TeamState#team.member),
    [lib_send:send_to_sid(M#mb.pid_send, BinData) || M <- Members, M#mb.pid_send /= undefined].


%% 向其他队员发送信息
send_to_other_member(PlayerId, BinData, TeamState) ->
	if
		length(TeamState#team.member) > 1 ->
    		[lib_send:send_to_sid(M#mb.pid_send, BinData) || M <- TeamState#team.member, M#mb.id =/= PlayerId, M#mb.pid_send /= undefined];
		true ->
			skip
	end.


%%直接将对方传进副本
deliver_other_member(SelfId, Bin, SceneId, State) ->
	case length(State#team.member) > 1 of
		true ->
			F = fun(Memberpid) ->
				case is_pid(Memberpid) of
					true ->
						gen_server:cast(Memberpid, {'DELIVER_TEAM', Bin, SceneId});
					_ ->
						skip
				end
    		end,
    		[F(M#mb.pid) || M <- State#team.member, M#mb.id =/= SelfId];
		false ->
			skip
	end.


member_fst_leave_team(TeamInfo, FromId) ->
	Member = TeamInfo#team.member,
%% ?DEBUG("FST_PPPPPP____~p___/",[Member]),
	All_out = lists:foldl(fun(R, Sum) ->
								  case [R#mb.id, R#mb.pid] of
									  [_, undefined] ->
										  Sum;
									  [FromId, _] ->
										  Sum;
									  _ ->
										  case lib_player:get_online_info_fields(R#mb.pid, [scene]) of
											  [] -> Sum;
											  [SceneID] ->
												if
													SceneID rem 10000 > 1000 ->
														Sum + 1;
													true ->
														Sum
												end;
											_ -> Sum
										  end
								  end
						  end,
						  0, Member),
%% ?DEBUG("FST_PPPPPP____~p___/",[All_out]),
	case All_out of
		0 ->
			F = fun(ScInfo) ->
					{_Scid, P} = ScInfo,
%% 			?DEBUG("FST_PPPPPP____~p___/",[P]),
					mod_fst:close_fst(P)
    			end,
			[F(Sc_pid_info)|| Sc_pid_info <- TeamInfo#team.fst_pid],
			[undefined, []];
		_ ->
			[TeamInfo#team.dungeon_pid, TeamInfo#team.fst_pid]
	end.

member_fst_leave_team(TeamInfo, FromId, LeaderId, LeaderScId) ->
	Member = TeamInfo#team.member,
%% ?DEBUG("FST_PPPPPP____~p___/",[Member]),
	All_out = 
		if
			LeaderScId rem 10000 > 1000 ->
				1;
			true ->
				lists:foldl(fun(R, Sum) ->
								  case [R#mb.id, R#mb.pid] of
									  [_, undefined] ->
										  Sum;
									  [FromId, _] ->
										  Sum;
									  [LeaderId, _] ->
										  Sum;
									  _ ->
										  case lib_player:get_online_info_fields(R#mb.pid, [scene]) of
											  [] -> Sum;
											  [SceneID] ->
												if
													SceneID rem 10000 > 1000 ->
														Sum + 1;
													true ->
														Sum
												end;
											_ -> Sum
										  end
								  end
						  end,
						  0, Member)
		end,
	case All_out of
		0 ->
			F = fun(ScInfo) ->
					{_Scid, P} = ScInfo,
					mod_fst:close_fst(P)
    			end,
			[F(Sc_pid_info)|| Sc_pid_info <- TeamInfo#team.fst_pid],
			[undefined, []];
		_ ->
			[TeamInfo#team.dungeon_pid, TeamInfo#team.fst_pid]
	end.

check_dungeon(Member, Uid) ->
	Fun = fun(R, Sum) ->
		case [R#mb.id, R#mb.pid] of
			[_, undefined] ->
				Sum;
			[Uid, _] ->
				Sum;
			_ ->
				Scid = lib_player:get_online_info_fields(R#mb.id, [scene]),
				case Scid of
					[] -> Sum;
					[SceneID] ->
						if
							SceneID rem 10000 > 910 ->
								Sum + 1;
							true ->
								Sum
						end;
					_ -> Sum
				end
		end
	end,
	AnyInDungeon = lists:foldl(Fun, 0, Member),
	if
		AnyInDungeon > 0 ->
			true;
		true ->
			false
	end.

%%玩家入队时获取亲密度，为#team.close和#team.close_rela两个列表填好数据
join_team_close(Team, PlayerId, FriendList) ->
    Members = Team#team.member,
	case Members =:= [] of
		true -> 
			Team;      
		false ->
			Closes = Team#team.close,
			F = fun(Tid) ->
						case Tid =:= PlayerId of
							true -> 
								[];
							false ->
								%%匹配PlayerId的好友列表
								case match_key(Tid,FriendList) of                 %%是否好友
									false ->
										%%为#team.close准备填充数据
										R = #ets_rela{id=0, pid=0, close=0},
										{PlayerId,Tid,R};
									Rela ->
										{Rela#ets_rela.pid,Rela#ets_rela.rid,Rela}      
								end
						end
				end,
		   CList = [F(M#mb.id) || M<-Members],
		   %%取出有好友关系的
		   NewRela =  [{{IdA,IdB},R} || {IdA,IdB,R}<-CList, R#ets_rela.id =/= 0 ],
		   OldRela = Team#team.close_rela,
		   %%为#team.close_rela填充数据
		   ComRela = lists:filter(fun(R) -> R =/= [] end, OldRela ++ NewRela),
		   %为#team.close填充数据
		   CList0 = lists:filter(fun(C) -> C =/= [] end, CList),
		   CList1 = [{{Pid,Rid},R#ets_rela.close} || {Pid,Rid,R} <-CList0, Pid == PlayerId],
		   %%逆序
		   F3 = fun({{Tid,RoleId},Close}) -> {{RoleId,Tid},Close} end,
		   CList2 = lists:map(F3,CList1),
		   %%原来的close + PlayerId产生的close + PlayerId产生的close的(Id)逆序
		   New = Closes ++ CList1 ++ CList2,
		   Team#team{close_rela = ComRela,close = New}
	end.

match_key(_Key,[]) ->
	false;
match_key(Key,[Rela | Relas]) ->
	if Rela#ets_rela.rid == Key ->
		   Rela;
	   true ->
		   match_key(Key,Relas)
	end.
		   
%%找出最大亲密值
team_max_close(TeamStatus,MemberId) ->
	CloseList = [ {Close,Id1,Id2} || {{Id1,Id2},Close} <- TeamStatus#team.close, Id1 == MemberId],
	CloseList2 = lists:filter(fun(E) -> E /= skip andalso E /= [] end, CloseList),
	CloseList3 = lists:usort(CloseList2),
	if CloseList3 == [] ->                           %%与队伍成员都不是好友，没有任何亲密度
		   {1,0,0,0,0,0,0,0};
	   true ->
		   {MaxClose,IdA,IdB} = lists:last(CloseList3),
		   CloseLevel = lib_relationship:get_close_level(MaxClose),
		   {ExpParam,MpParam,HpParam,Ap,MaxAttackParam} = lib_relationship:get_close_res(CloseLevel),
		   {ExpParam,MpParam,HpParam,Ap,MaxAttackParam,MaxClose,IdA,IdB}
	end.

%%  cast到玩家进程，改变其属性
send_pid_info(Uid,ParamList) ->
	case lib_player:get_player_pid(Uid) of
		[]->
			skip;
		Pid ->
			 Pid ! ({'SET_TEAM_CLOSE_INFO', ParamList})
	end.

%%判断队员是否要覆盖亲密度加成
cover_close(IdA,IdB,MaxClose,CloseLevel,Params) ->
	 %%判断  IdB 玩家有无加成过
	{_ExpParam,MpParam,HpParam,Ap,MaxAttackParam,MaxClose,IdA,IdB} = Params,
	case get({team,IdB}) of
		undefined ->
			put({team,IdB},{IdA,MaxClose}),
			%%对 IdB 玩家加成属性
			send_pid_info(IdB,[CloseLevel,MpParam,HpParam,Ap,MaxAttackParam,1]);
		BMaxClose ->
			if BMaxClose >= MaxClose ->
				   skip;
			   true ->
				   %%覆盖 IdB 的亲密度加成
				   %%取出旧的加成系数
				   BCloseLevel= lib_relationship:get_close_level(BMaxClose),
				   put({team,IdB},{IdA,MaxClose}),
				   {_BExpParam,BMpParam,BHpParam,BAp,BMaxAttackParam} = lib_relationship:get_close_res(BCloseLevel),
				   %%新加成系数减去旧的加成系数
				   send_pid_info(IdB,[CloseLevel,MpParam-BMpParam,HpParam-BHpParam,Ap-BAp,MaxAttackParam-BMaxAttackParam,1])
			end
	end.			
	
%% 组队时亲密度对玩家属性的加成
team_close_status(TeamStatus,1) ->
	Members = lists:delete([],TeamStatus#team.member),
	F = fun(Mb) -> 
        {_ExpParam, MpParam, HpParam, Ap, MaxAttackParam, MaxClose, IdA, IdB} = team_max_close(TeamStatus,Mb#mb.id),
        case MaxClose =:= 0 of
            true -> 
                skip;
            false ->
                CloseLevel = lib_relationship:get_close_level(MaxClose),
                case get({team,IdA}) of
              		%%该队员还没有任何加成
                   	undefined -> 
                  		put({team,IdA},{IdB,MaxClose}),
                       	%%对  IdA 玩家加成属性
                       	send_pid_info(IdA,[CloseLevel,MpParam,HpParam,Ap,MaxAttackParam,1]),
                       	cover_close(IdA,IdB,MaxClose,CloseLevel,{_ExpParam,MpParam,HpParam,Ap,MaxAttackParam,MaxClose,IdA,IdB});
                 	{_Oid,AMaxClose} ->
                    	if 
							AMaxClose >= MaxClose ->
                           		skip;
                            true->
                                %% 取出旧的加成系数
                                ACloseLevel= lib_relationship:get_close_level(AMaxClose),
                                {_AExpParam,AMpParam,AHpParam,AAp,AMaxAttackParam} = lib_relationship:get_close_res(ACloseLevel),
                                put({team,IdA},{IdB,MaxClose}),
                               	%% 覆盖 IdA 的亲密度加成
                                %% 新加成系数减去旧的加成系数
                                send_pid_info(IdA,[CloseLevel,MpParam-AMpParam,HpParam-AHpParam,Ap-AAp,MaxAttackParam-AMaxAttackParam,1]),
                                cover_close(IdA,IdB,MaxClose,CloseLevel,{_ExpParam,MpParam,HpParam,Ap,MaxAttackParam,MaxClose,IdA,IdB})
                        end
               	end
        end
	end,
	lists:map(F, Members).								 							 								

%%扣除属性加成
team_close_cut(Uid,Members) ->
	%%对自己做处理
	case get({team,Uid}) of
		undefined ->
			skip;
		%%关联的Oid放到下面的 F 函数 统一处理
		{_Oid,UMaxClose} ->
			 UCloseLevel = lib_relationship:get_close_level(UMaxClose),
			 {_UExpParam,UMpParam,UHpParam,UAp,UMaxAttackParam} = lib_relationship:get_close_res(UCloseLevel),
			 send_pid_info(Uid,[0,UMpParam,UHpParam,UAp,UMaxAttackParam,0])
	end,
	put({team,Uid},undefined),
	%%对关联队员处理
	F = fun(Mid) ->
				case get({team,Mid}) of 
					undefined ->
						skip;
					{Tid,TClose} ->
						if Tid =:= Uid ->
							   put({team,Mid},undefined),
							   TCloseLevel = lib_relationship:get_close_level(TClose),
							   {_ExpParam,TMpParam,THpParam,TAp,TMaxAttackParam} = lib_relationship:get_close_res(TCloseLevel),
							   %%扣除关联队员属性
							   send_pid_info(Mid,[0,TMpParam,THpParam,TAp,TMaxAttackParam,0]);
						   true ->
							   skip
						end
				end
		end,
	
	[F(M#mb.id) || M <- Members].																

%%玩家退出封神台，检查封神台玩家状态
check_member_fst_quit([],_Pid,_Scene,Sum)->{ok,Sum};
check_member_fst_quit([R|Member],Pid,Scene,Sum)->
	case R#mb.pid of
		undefined ->
			check_member_fst_quit(Member,Pid,Scene,Sum);
		Pid1->
			if Pid1=:=Pid->
				   if Scene rem 10000 > 1000 ->check_member_fst_quit(Member,Pid,Scene,Sum+1);
					  true ->check_member_fst_quit(Member,Pid,Scene,Sum)
				   end;
			   true->
				   case lib_player:get_online_info_fields(R#mb.pid, [scene]) of
					   [] -> {error,Sum};
					   [SceneID] ->
						   if
							   SceneID rem 10000 > 1000 ->check_member_fst_quit(Member,Pid,Scene,Sum+1);
							   true ->check_member_fst_quit(Member,Pid,Scene,Sum)
						   end;
					   _ -> check_member_fst_quit(Member,Pid,Scene,Sum)
				   end
			end
	end.

%% 获取队员位置信息
get_teammate_position(Member, PlayerId, SendPid) ->
   	[gen_server:cast(M#mb.pid, {'MEMBER_JOIN_TEAM', SendPid}) || M <- Member, M#mb.id =/= PlayerId, M#mb.pid =/= undefined].

%%获取队伍集合NPCid
get_raise_place(Type)->
	 case Type of
		 1->{1,20910};
		 2->{1,20800};
		 3->{1,20204};
		 4->{1,20912};
		 5->{1,10309};
		 6->{1,20106};
		 7->{1,20229};
		 8->{1,20249};
		 _->{1,21012}
	 end.

%%删除队员
member_delete(Id,Rlist) ->
	F_del = fun(Mb) ->
					Mb#mb.id /= Id
			end,
	lists:filter(F_del, Rlist).


%%检查是否夫妻
is_couple([],_Name)->false;
is_couple([M|Member],Name)->
	case M#mb.nickname ==Name of
		true-> true;
		false->
			is_couple(Member,Name)
	end.