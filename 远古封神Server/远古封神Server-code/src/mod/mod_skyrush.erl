%%% -------------------------------------------------------------------
%%% Author  : Xianrong.Mai
%%% Description :神岛空战的场景处理
%%%
%%% Created : 2011-4-9
%%% -------------------------------------------------------------------
-module(mod_skyrush).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("guild_info.hrl").

-define(ENTER_SKY_RUSH_NOTICE_TIME, 5000).
-define(ENTER_SKY_RUSH_NOTICE_START, 5*60*1000).


-define(GREEN_FLAGS_MAX, 6).%%绿旗最大数
-define(BLUE_FLAGS_MAX, 3).%%蓝旗最大数
-define(PURPLE_FLAGS_REFLESH_BASE, 20).%%紫旗刷新基数
%% --------------------------------------------------------------------
%% External exports
-export([get_skyrush_pid/0,
		 get_applied_guilds/0,
		 init_skyrush/0,
		 apply_skyrush/1,
		 enter_sky_scene/1,
		 kill_sky_bossmon/2,
		 kill_sky_littlemon/2,
		 submit_feats/4,
		 pickup_fn/3,
		 hold_point/2,
		 get_skyrush_rank/1,
		 get_sky_award/1,
		 get_sky_award_and_members/1,
		 assign_goods_man/4,
		 assign_goods_auto/1,
		 check_sign_up/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).


%% ====================================================================
%% External functions
%% ====================================================================
%% -----------------------------------------------------------------
%% 39001 查看已报名氏族
%% -----------------------------------------------------------------
get_applied_guilds() ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_skyrush, get_applied_guilds, 
						 []})	of
			 error -> 
				 %% ?DEBUG("39001 get_applied_guilds error",[]),
				 [];
			Data ->
				%% ?DEBUG("39001 get_applied_guilds succeed:[~p]",[Data]),
				Data
		end		
	catch
		_:_Reason -> 
			%% ?DEBUG("39001 get_applied_guilds fail for the reason:[~p]",[_Reason]),
			[]
	end.

%% -----------------------------------------------------------------
%% 39002 报名空岛神战
%% -----------------------------------------------------------------
apply_skyrush(Status) ->
	%%因为涉及到并发问题，此操作专门使用Id号为0的进程执行
	ProcessName = misc:create_process_name(guild_p, [25]),
	GuildPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->
						Pid;
					false ->
						mod_guild:start_mod_guild(ProcessName)
				end;
			_ ->
				mod_guild:start_mod_guild(ProcessName)
		end,
	try 
		case gen_server:call(GuildPid, 
						{apply_call, lib_skyrush, apply_skyrush, 
						 	[Status#player.id,Status#player.guild_id, Status#player.guild_position]}) of
			 error -> 
				 0;
			 Data -> 
				 Data
		end			
	catch
		_:_Reason -> 
			0
	end.

%% -----------------------------------------------------------------
%% 39003 进入空岛神战
%% -----------------------------------------------------------------
enter_sky_scene(Status) ->
	lib_skyrush:enter_sky_scene(Status).

%% -----------------------------------------------------------------
%% 39011 交战旗或魔核
%% -----------------------------------------------------------------
submit_feats(Status, FeatsType, Color, Point) ->
	case FeatsType >= 0 andalso FeatsType =< 1 
		andalso Color >= 1 andalso Color =< 4 
%% 		andalso Point >= 1 andalso Point =< 3 of%%屏蔽高级据点
		andalso (Point =:= 1 orelse Point =:= 3) of
		true ->
	#player{id = PlayerId,
			x = X,
			y = Y,
			nickname = PlayerName,
			guild_id = GuildId,
			carry_mark = CarryMark,
			other = Other} = Status,
	#player_other{pid_scene = PidScene,
				  pid_send = PidSend} = Other,
	GetColor = %%求出玩家记录的旗或者魔核信息
		case FeatsType of
			0 ->
				CarryMark - 7;
			1 ->
				CarryMark - 11
		end,
%% 	io:format("GetColor:~p, FeatsType:~p, Color:~p, Point:~p, X:~p, Y:~p\n", [GetColor, FeatsType, Color, Point, X, Y]),
	case GetColor =:= Color of
		true ->%%判断正确性
			case catch(gen_server:call(PidScene, {'SUBMIT_FEATS',
												  PidSend, Point, X, Y, FeatsType, PlayerId, PlayerName, GuildId, Color})) of
				{ok, 1} ->
					NewStatus = Status#player{carry_mark = 0},
					{1, NewStatus};
				{ok, Res} ->
					{Res, Status};
				_Error ->
					{0, Status}
			end;
		false when CarryMark  =:= 0 ->
			{2,Status};%%头上没有魔核或者旗
		false ->
			{0, Status}
	end;
		false when Color =:= 0->
			{2,Status};%%头上没有魔核或者旗
		false ->
			{0, Status}
	end.

%% -----------------------------------------------------------------
%% 39012 拾取战旗
%% -----------------------------------------------------------------
pickup_fn(Status, X, Y) ->
	#player{id = PlayerId,
			x = PX,
			y = PY,
			carry_mark = CarryMark,
			other = Other} = Status,
	PidScene = Other#player_other.pid_scene,
	AbX = abs(PX - X),
	AbY = abs(PY - Y),
	if
		(CarryMark >= 8 andalso CarryMark =< 15) =:= true ->
			[3, 0, Status];
		AbX > ?COORD_DIST_LIMIT orelse AbY > ?COORD_DIST_LIMIT ->
			[2, 0, Status];
		true ->
			case catch(gen_server:call(PidScene, {'PICK_UP_FN',X, Y, PlayerId})) of
				{ok, 1, Type} ->
					NewType = Type + 7,
					NewStatus = Status#player{carry_mark = NewType},
					[1, Type, NewStatus];
				{ok, Res, _Type} ->
					[Res, 0, Status];
				_Error ->
					[0, 0, Status]
			end
	end.
	
%% -----------------------------------------------------------------
%% 39016 占据据点
%% -----------------------------------------------------------------
hold_point(Status, Type) ->
	#player{id = PlayerId,
			guild_id = GuildId,
			guild_name = GuildName,
			other = Other} = Status,
	#player_other{pid_scene = PidScene} = Other,
	Param = [Type, PlayerId, GuildId, GuildName],
	case catch(gen_server:call(PidScene, {'HOLE_POINT', Param})) of
		{ok, Reply} ->
			[Reply];
		_ ->
			[0]
	end.
	
%% -----------------------------------------------------------------
%% 39021 积分排行
%% -----------------------------------------------------------------
get_skyrush_rank(Status) ->
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
						  {apply_cast, lib_skyrush, get_skyrush_rank, 
						   [Status#player.other#player_other.pid_send]}).

%% -----------------------------------------------------------------
%% 39025 氏族战奖励
%% -----------------------------------------------------------------
get_sky_award(Status) ->
	try
		case gen_server:call(mod_guild:get_mod_guild_pid(),
							 {apply_call, lib_skyrush, get_sky_award, 
							  [Status#player.id, Status#player.guild_id]}) of
			error ->
				[0, 0, 0];
			Data ->
				Data
		end
	catch
		_:_Reason ->
			?WARNING_MSG("39025 get_sky_award fail for the reason:[~p]",[_Reason]),
			[0, 0, 0]
	end.

%% -----------------------------------------------------------------
%% 39029查询氏族战是否报名
%% -----------------------------------------------------------------
check_sign_up(Status)->
	gen_server:cast(mod_guild:get_mod_guild_pid(),
							 {apply_cast, lib_skyrush, check_sign_up, 
							  [Status#player.guild_id, Status#player.other#player_other.pid_send, Status#player.lv]}).

%%杀死boss怪
kill_sky_bossmon(Player, Minfo) ->
	#player{id = PlayerId,
			nickname = PlayerName,
			guild_id = GuildId,
			career = Career,
			sex = Sex,
			x = X,
			y = Y,
			carry_mark = CarryMark,
			other = Other
			} =Player,
	#player_other{pid = PlayerPid,
				  pid_scene = PidScene,
				  pid_send = PidSend} = Other,
	#ets_mon{mid = MonId,
			 name = MonName} = Minfo,
	gen_server:cast(PidScene, 
					{kill_sky_bossmon, PidSend, PlayerPid, GuildId, PlayerId, X, Y, MonId, MonName, PlayerName, Career, Sex, CarryMark}).
%%杀小怪
kill_sky_littlemon(Player, Minfo) ->
	#player{id = PlayerId,
			nickname = PlayerName,
			x = X,
			y = Y,
			career = Career,
			sex = Sex,
			carry_mark = CarryMark,
			other = Other} = Player,
	#player_other{pid = PlayerPid,
				  pid_scene = PidScene} = Other,
	#ets_mon{name = MonName} = Minfo,
	gen_server:cast(PidScene, {kill_sky_littlemon, PlayerId, X, Y, PlayerPid, MonName, PlayerName, Career, Sex, CarryMark}).

%% ====================================================================
%% Server functions
%% ====================================================================
init_skyrush() ->
	 gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
%% 	gen_server:start(?MODULE, [], []).

get_skyrush_pid() ->
	ProcessName = misc:create_process_name(scene_p, [?SKY_RUSH_SCENE_ID, 0]),
	case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
%% 				io:format("the process is built:~p\n", [Pid]),
				{ok, Pid};
			_OtherPid ->
%% 				io:format("OMG, the process is no built:~p\n", [_OtherPid]),
				{error}
	end.
%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([]) ->
	process_flag(trap_exit, true),
	Self = self(),
	%% 初始战场
	SceneProcessName = misc:create_process_name(scene_p, [?SKY_RUSH_SCENE_ID, 0]),
%% 	?DEBUG("init the skyrush process", []),
	case misc:register(unique, SceneProcessName, Self) of
		yes ->
%% 			?DEBUG("OK!!!!!!!!!!!", []),
			%% 复制场景
			lib_scene:copy_scene(?SKY_RUSH_SCENE_ID, ?SKY_RUSH_SCENE_ID),
			misc:write_monitor_pid(Self, ?MODULE, {?SKY_RUSH_SCENE_ID}),
			ets:new(?G_FEATS_ELEM, [{keypos, #g_feats_elem.guild_id}, named_table, public, set,?ETSRC, ?ETSWC]),
			ets:new(?MEM_FEATS_ELEM, [{keypos, #mem_feats_elem.player_id}, named_table, public, set,?ETSRC, ?ETSWC]),
			%%初始化氏族功勋
			lib_skyrush:init_guild_feats(),
			erlang:send_after(?ENTER_SKY_RUSH_NOTICE_TIME, self(), {'ENTER_SKY_RUSH_NOTICE', 1}),
			%%产生种子
			{MegaSecs, Secs, MicroSecs} = now(),
%% 			?DEBUG("{~p, ~p,~p,~p}", [ProcessId, MegaSecs+ProcessId, Secs+ProcessId*10, MicroSecs+ProcessId*100]),
			random:seed({MegaSecs, Secs, MicroSecs}),
			%%开始结束战斗的定时器
			NowSec = util:get_today_current_second(),
			[_WeekDate, _SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
			ReTime = SKY_RUSH_END_TIME - NowSec,
			erlang:send_after(ReTime * 1000, self(), {'END_SKY_RUSH'}),
	
			SkyRush = #skyrush{},
			{ok, SkyRush};
		_ ->
%% 			?DEBUG("end!!!!1", []),
			{stop, normal, #skyrush{}}
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
%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
	%% ?DEBUG("****************apply_call_apply_call:[~p,~p]*********", [Module, Method]),
	Reply = 
		case (catch apply(Module, Method, Args)) of
			{'EXIT', Info} ->
				?WARNING_MSG("apply_call_apply_call: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
				error;
			DataRet -> DataRet
		end,
	{reply, Reply, State};

%% 获取掉落物自增ID
handle_call({'GET_DROP_ID', DropNum}, _From, State) ->
	DropId = State#skyrush.drop_id + DropNum + 1,
	NewDropId = 
		if
   			DropId > ?MON_LIMIT_NUM ->
				1;
	   		true ->
				DropId
        end,
	NewState = State#skyrush{
		drop_id = NewDropId
	},
    {reply, State#skyrush.drop_id, NewState};


%% -----------------------------------------------------------------
%% 39011 交战旗或魔核
%% -----------------------------------------------------------------
handle_call({'SUBMIT_FEATS',PidSend, Point, X, Y, FeatsType, PlayerId, PlayerName, Guild, Color}, _From, State) ->
	{Reply, NewState} = lib_skyrush:submit_feats(PidSend, Point, X, Y, FeatsType, PlayerId, PlayerName, Guild, Color, State),
	{reply, {ok, Reply}, NewState};

%% -----------------------------------------------------------------
%% 39012 拾取战旗
%% -----------------------------------------------------------------
handle_call({'PICK_UP_FN',X, Y, PlayerId}, _From, State) ->
	{Reply, Type, NewState} = lib_skyrush:pickup_fn(X, Y, PlayerId, State),
	{reply, {ok, Reply, Type}, NewState};
	
%% -----------------------------------------------------------------
%% 39016 占据据点
%% -----------------------------------------------------------------
handle_call({'HOLE_POINT', Param}, _From, State) ->
	[Type, PlayerId, GuildId, GuildName] = Param,
	{BossNum, _BossInfo} = State#skyrush.boss_num,
	case BossNum > 0 of 
		true ->
			{Reply, NewState} = {5, State};
		false ->
			{Reply, NewState} = 
				case Type of
					1 ->
						#skyrush{point_l = {GuildIdGet, _LNameGet},
								 point_l_read = GetList} = State,
						if 
							GuildId =:= GuildIdGet ->
								{3, State};
							true ->
								NewState0 = State#skyrush{point_l_read = [{10, PlayerId, GuildId, GuildName} | GetList]},
								{1, NewState0}
						end;
					2 ->
						#skyrush{point_h = {GuildIdGet, _HNameGet},
								 point_h_read = GetList} = State,
						if 
							GuildId =:= GuildIdGet ->
								{3, State};
							true ->
								NewState0 = State#skyrush{point_h_read = [{10, PlayerId, GuildId, GuildName} | GetList]},
								{1, NewState0}
						end
				end
	end,
	{reply, {ok, Reply}, NewState};





%%开旗1
handle_call({'ONE_GET_AREA_FLAG', PlayerId}, _From, State) ->
%% 	io:format("'ONE_GET_AREA_FLAG'\n"),
	{Exist, Players} = State#skyrush.one_exist_flags,
	case Exist of
		1 ->%%白色
			NewPlayers = 
				case lists:keyfind(PlayerId, 2, Players) of
					false ->
						Reply = 1,
						[{5, PlayerId}| Players];
					_ ->
						Reply = 1,
						lists:keyreplace(PlayerId, 2, Players, {5, PlayerId})
				end;
		4 ->%%紫色
			NewPlayers = 
				case lists:keyfind(PlayerId, 2, Players) of
					false ->
						Reply = 1,
						[{5, PlayerId}| Players];
					_ ->
						Reply = 1,
						lists:keyreplace(PlayerId, 2, Players, {5, PlayerId})
				end;
		_ ->
			Reply = 0,
			NewPlayers = Players
	end,
	NewState = State#skyrush{one_exist_flags = {Exist, NewPlayers}},
	{reply, {ok, Reply}, NewState};
%%开旗2
handle_call({'TWO_GET_AREA_FLAG', PlayerId}, _From, State) ->
%% 	io:format("'TWO_GET_AREA_FLAG'\n"),
	{Exist, Players} = State#skyrush.two_exist_flags,
	case Exist of
		2 ->%%绿色
			NewPlayers = 
				case lists:keyfind(PlayerId, 2, Players) of
					false ->
						Reply = 1,
						[{5, PlayerId}| Players];
					_ ->
						Reply = 1,
						lists:keyreplace(PlayerId, 2, Players, {5, PlayerId})
				end;

		_ ->
			Reply = 0,
			NewPlayers = Players
	end,
	NewState = State#skyrush{two_exist_flags = {Exist, NewPlayers}},
	{reply, {ok, Reply}, NewState};
%%开旗3
handle_call({'THREE_GET_AREA_FLAG', PlayerId}, _From, State) ->
%% 	io:format("'THREE_GET_AREA_FLAG'\n"),
	{Exist, Players} = State#skyrush.three_exist_flags,
	case Exist of
		3 ->%%蓝色
			NewPlayers = 
				case lists:keyfind(PlayerId, 2, Players) of
					false ->
						Reply = 1,
						[{5, PlayerId}| Players];
					_ ->
						Reply = 1,
						lists:keyreplace(PlayerId, 2, Players, {5, PlayerId})
				end;
		_ ->
			Reply = 0,
			NewPlayers = Players
	end,
	NewState = State#skyrush{three_exist_flags = {Exist, NewPlayers}},
	{reply, {ok, Reply}, NewState};

%%专门用来测试,获取氏族战进程信息
handle_call({'GET_THE_STATE'}, _From, State) ->
	{reply, State, State};

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
%% 	%% ?DEBUG("mod_scene_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_skyrush_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%% -----------------------------------------------------------------
%% 39007 战场信息
%% -----------------------------------------------------------------
handle_cast({'GET_SKYRUSH_INFO', PlayerId, PlayerName, GuildId, PidSend}, State) ->
	lib_skyrush:player_goto_sky(PlayerId, PlayerName, GuildId),
	GFeats = ets:tab2list(?G_FEATS_ELEM),
	MFeats = ets:tab2list(?MEM_FEATS_ELEM),
	GFeatsList = lists:map(fun(Elem) ->
								   #g_feats_elem{guild_name = GuildName,
												 guild_feats = GFeat} = Elem,
								   {0, GFeat, GuildName}
						   end, GFeats),
	ResList = lists:foldl(fun(ElemM, AccIn) ->
								  #mem_feats_elem{player_name = PlayerNameM,
												  feats = FeatM} = ElemM,
								  Result = {1, FeatM, PlayerNameM},
								  [Result|AccIn]
						  end, GFeatsList, MFeats),
	{_BossNum, [{_Boss1,BossOne},{_Boss2, BossTwo},{_Boss3, BossThree}]} = State#skyrush.boss_num,
	{PointL, LName} = State#skyrush.point_l,
	{PointH, HName} = State#skyrush.point_h,
	{OneColor, _APlayers} = State#skyrush.one_exist_flags,
	{TwoColor, _BPlayers} = State#skyrush.two_exist_flags,
	{ThreeColor, _CPlayers} = State#skyrush.three_exist_flags,
	%%配置表
	NowSec = util:get_today_current_second(),
	[_WeekDate, _SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	RemainTime = SKY_RUSH_END_TIME - NowSec,
	{ok, Data39019} = pt_39:write(39019, [BossOne, BossTwo, BossThree, PointL, LName, PointH, HName, OneColor, TwoColor, ThreeColor, RemainTime]),
	{ok, Data39007} = pt_39:write(39007, [0, ResList]),
%% 	io:format("the result is:~p\n", [Data39007]),
	lib_send:send_to_sid(PidSend, Data39007),
	lib_send:send_to_sid(PidSend, Data39019),
	{noreply, State};
	

%%杀死boss怪
handle_cast({kill_sky_bossmon, PidSend, PlayerPid, GuildId, PlayerId, X, Y, MonId, MonName, PlayerName, Career, Sex, CarryMark}, State) ->
	%%结束战斗,屏蔽消息
	NowSec = util:get_today_current_second(),
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	case NowSec >= SKY_RUSH_START_TIME + 5*60 andalso NowSec =< SKY_RUSH_END_TIME of
		true  ->
	{BossNum, _BossInfo} = State#skyrush.boss_num,
	if BossNum >= 1 ->
		   NewState1 = lib_skyrush:kill_sky_bossmon([PidSend, PlayerPid, GuildId, PlayerId, X, Y, MonId, MonName, PlayerName, Career, Sex, CarryMark, State]),
		   {NewBossNum,_NewBossInfo} = NewState1#skyrush.boss_num,
		   case NewBossNum =:= 0 of
			   true ->
				   lib_skyrush:send_skyrush_notice(4, []),
				   lib_skyrush:reflesh_flags(),
				   NewState = NewState1#skyrush{one_exist_flags = {1,[]},
												two_exist_flags ={2,[]},
												three_exist_flags = {3,[]}},
				   %%开启旗的定时器
				   erlang:send_after(1000, self(), {'ONE_EXIST_FLAGS'}),
				   erlang:send_after(1000, self(), {'TWO_EXIST_FLAGS'}),
				   erlang:send_after(1000, self(), {'THREE_EXIST_FLAGS'}),
				   %%定时刷新错误的数据
				   erlang:send_after(3000, self(), {'REFLESH_STATE'}),
				 
%% 				   io:format("<--39020-->\n"),
				   %%据点开启广播
				   {ok, Data39020} = pt_39:write(39020, []),
				   spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39020) end),
				   %%开启据点的刷新
%% 				   erlang:send_after(1000, self(), {'POINT_L_READ'}),
%% 				   erlang:send_after(1000, self(), {'POINT_H_READ'}),
				   %%开启旗消失定时器
%% 				   erlang:send_after(1000, self(),{'CLEAN_DROP_FLAGS'}),
				   erlang:send_after(1000, self(),{'FLESH_POINT_AND_CLEAN_DROP_FLAGS'}),
				   %%刷小怪(10秒)
				   erlang:send_after(?LMON_REFLESH_TIME, self(), {'INIT_LITTLT_MON'});
			   false ->
				   NewState = NewState1
		   end;
	   true ->
		   NewState = State#skyrush{boss_num = {0, [{43001, 0}, {43002, 0}, {43003, 0}]}}
	end,
	{noreply, NewState};
		false ->
			{noreply, State}
	end;

%%杀死小怪
handle_cast({kill_sky_littlemon, PlayerId, X, Y, PlayerPid, MonName, PlayerName, Career, Sex, CarryMark}, State) ->
	%%结束战斗,屏蔽消息
	NowSec = util:get_today_current_second(),
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	case NowSec >= SKY_RUSH_START_TIME + 5*60 andalso NowSec =< SKY_RUSH_END_TIME of
		true  ->
			NewState = 
				lib_skyrush:kill_sky_littlemon([PlayerId, X, Y, PlayerPid, MonName, PlayerName,
												Career, Sex, CarryMark, State]),
			{noreply, NewState};
		false ->
			{noreply, State}
	end;
	
%%玩家下线
handle_cast({'PLAYER_LOGOUT_SKY', CarryMark, PlayerId}, State) ->
	%%io:format("11111111111111111\n"),
	 NewState = 
	case CarryMark of
		8 ->
			{Num, FlNus} = State#skyrush.white_flags,
			case lists:keyfind(PlayerId, #fns_elem.player_id, FlNus) of
				false ->
					State;
				_Tuple ->
					NewFlNus = lists:keydelete(PlayerId, #fns_elem.player_id, FlNus),
					State#skyrush{white_flags = {Num -1, NewFlNus}}
			end;
		9 ->
			{Num, FlNus} = State#skyrush.green_flags,
			case lists:keyfind(PlayerId, #fns_elem.player_id, FlNus) of
				false ->
					State;
				_Tuple ->
					NewFlNus = lists:keydelete(PlayerId, #fns_elem.player_id, FlNus),
					State#skyrush{green_flags = {Num -1, NewFlNus}}
			end;
		10 ->
			{Num, FlNus} = State#skyrush.blue_flags,
			case lists:keyfind(PlayerId, #fns_elem.player_id, FlNus) of
				false ->
					State;
				_Tuple ->
		%%			io:format("123213123\n"),
					NewFlNus = lists:keydelete(PlayerId, #fns_elem.player_id, FlNus),
					State#skyrush{blue_flags = {Num -1, NewFlNus}}
			end;
		11 ->
			{Num, FlNus} = State#skyrush.purple_flags,
			case lists:keyfind(PlayerId, #fns_elem.player_id, FlNus) of
				false ->
					State;
				_Tuple ->
					NewFlNus = lists:keydelete(PlayerId, #fns_elem.player_id, FlNus),
					State#skyrush{purple_flags = {Num -1, NewFlNus}}
			end;
		12 ->
			{Num, FlNus} = State#skyrush.white_nuts,
			case lists:keyfind(PlayerId, #fns_elem.player_id, FlNus) of
				false ->
					State;
				_Tuple ->
					NewFlNus = lists:keydelete(PlayerId, #fns_elem.player_id, FlNus),
					State#skyrush{white_nuts = {Num -1, NewFlNus}}
			end;
		13 ->
			{Num, FlNus} = State#skyrush.green_nuts,
			case lists:keyfind(PlayerId, #fns_elem.player_id, FlNus) of
				false ->
					State;
				_Tuple ->
					NewFlNus = lists:keydelete(PlayerId, #fns_elem.player_id, FlNus),
					State#skyrush{green_nuts = {Num -1, NewFlNus}}
			end;
		14 ->
			{Num, FlNus} = State#skyrush.blue_nuts,
			case lists:keyfind(PlayerId, #fns_elem.player_id, FlNus) of
				false ->
					State;
				_Tuple ->
					NewFlNus = lists:keydelete(PlayerId, #fns_elem.player_id, FlNus),
					State#skyrush{blue_nuts = {Num -1, NewFlNus}}
			end;
		15 ->
			{Num, FlNus} = State#skyrush.purple_nuts,
			case lists:keyfind(PlayerId, #fns_elem.player_id, FlNus) of
				false ->
					State;
				_Tuple ->
					NewFlNus = lists:keydelete(PlayerId, #fns_elem.player_id, FlNus),
					State#skyrush{purple_nuts = {Num -1, NewFlNus}}
			end;
		16 ->%%开旗
			{OneColor, OnePlayer} = State#skyrush.one_exist_flags,
			{TwoColor, TwoPlayer} = State#skyrush.two_exist_flags,
			{ThreeColor, ThreePlayer} = State#skyrush.three_exist_flags,
			One = lists:keydelete(PlayerId, 2, OnePlayer),
			Two = lists:keydelete(PlayerId, 2, TwoPlayer),
			Three = lists:keydelete(PlayerId, 2, ThreePlayer),
			State#skyrush{one_exist_flags = {OneColor, One},
						  two_exist_flags = {TwoColor, Two},
						  three_exist_flags = {ThreeColor, Three}};
		17 ->
			PontlList = State#skyrush.point_l_read,
			PointhList = State#skyrush.point_h_read,
			L = lists:keydelete(PlayerId, 2, PontlList),
			H = lists:keydelete(PlayerId, 2, PointhList),
			State#skyrush{point_l_read = L,
						  point_h_read = H}
	end,
	{noreply, NewState};
	

%%打断开旗或据点
handle_cast({'DISCARD_FLAGS_BATTLE', {TypeA, PidSendA, AId, AX, AY}, {TypeB, PidSendB, BId, BX, BY}}, State) ->
	if
		AId =:= 0 ->
			NewStateA = State;
		true ->
			case TypeA of
				16 ->%%旗
%% 					io:format("A discard flags\n"),
					{_OColorA, OneListA} = State#skyrush.one_exist_flags,
					{_TColorA, TwoListA} = State#skyrush.two_exist_flags,
					{_HColorA, ThreeListA} = State#skyrush.three_exist_flags,
					NOneListA = lists:keydelete(AId, 2, OneListA),
					NTwoListA = lists:keydelete(AId, 2, TwoListA),
					NThreeListA = lists:keydelete(AId, 2, ThreeListA),
					NewStateA = State#skyrush{one_exist_flags = {_OColorA, NOneListA},
											  two_exist_flags = {_TColorA, NTwoListA},
											  three_exist_flags = {_HColorA, NThreeListA}},
					{ok, AData39018} = pt_39:write(39018, []),
%% 					mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, AX, AY, AData39018);
					lib_send:send_to_sid(PidSendA, AData39018),
					%%广播头上的东西
					{ok,BinData12041} = pt_12:write(12041, [AId, 0]),
					mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, AX, AY, BinData12041);
				17 ->%%据点
					PointLReadA = State#skyrush.point_l_read,
					PointHReadA = State#skyrush.point_h_read,
					NewPointLReadA = lists:keydelete(AId, 2, PointLReadA),
					NewPointHReadA = lists:keydelete(AId, 2, PointHReadA),
%% 					io:format("A discard pointL:~p>>~p;;~p\n", [AId, PointLReadA, NewPointLReadA]),
%% 					io:format("A discard pointH:~p>>~p;;~p\n", [AId, PointHReadA, NewPointHReadA]),
					NewStateA = State#skyrush{point_l_read = NewPointLReadA,
											  point_h_read = NewPointHReadA},
					{ok, AData39017} = pt_39:write(39017, []),
%% 					mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, AX, AY, AData39017)
					lib_send:send_to_sid(PidSendA, AData39017),
					%%广播头上的东西
					{ok,BinData12041} = pt_12:write(12041, [AId, 0]),
					mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, AX, AY, BinData12041)
			end
					
			
	end,
	if 
		BId =:= 0 ->
			NewStateB = NewStateA;
		true ->
			case TypeB of
				16 ->%%旗
%% 					io:format("B discard flags\n"),
					{_OColorB, OneListB} = NewStateA#skyrush.one_exist_flags,
					{_TColorB, TwoListB} = NewStateA#skyrush.two_exist_flags,
					{_HColorB, ThreeListB} = NewStateA#skyrush.three_exist_flags,
					NOneListB = lists:keydelete(BId, 2, OneListB),
					NTwoListB = lists:keydelete(BId, 2, TwoListB),
					NThreeListB = lists:keydelete(BId, 2, ThreeListB),
					NewStateB = NewStateA#skyrush{one_exist_flags = {_OColorB, NOneListB},
												  two_exist_flags = {_TColorB, NTwoListB},
												  three_exist_flags = {_HColorB, NThreeListB}},
					{ok, BData39018} = pt_39:write(39018, []),
%% 					mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, BX, BY, BData39018);
					lib_send:send_to_sid(PidSendB, BData39018),
					%%广播头上的东西
					{ok,BBinData12041} = pt_12:write(12041, [BId, 0]),
					mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, BX, BY, BBinData12041);
				17 ->%%据点
					PointLReadB = NewStateA#skyrush.point_l_read,
					PointHReadB = NewStateA#skyrush.point_h_read,
					NewPointLReadB = lists:keydelete(BId, 2, PointLReadB),
					NewPointHReadB = lists:keydelete(BId, 2, PointHReadB),
%% 					io:format("B discard pointL:~p>>~p;;~p\n", [BId, PointLReadB, NewPointLReadB]),
%% 					io:format("B discard pointH:~p>>~p;;~p\n", [BId, PointHReadB, NewPointHReadB]),
					NewStateB = NewStateA#skyrush{point_l_read = NewPointLReadB,
												  point_h_read = NewPointHReadB},
					{ok, BData39017} = pt_39:write(39017, []),
%% 					mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, BX, BY, BData39017)
					lib_send:send_to_sid(PidSendB, BData39017),
					%%广播头上的东西
					{ok, BBinData12041} = pt_12:write(12041, [BId, 0]),
					mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, BX, BY, BBinData12041)
			end
	end, 
	{noreply, NewStateB};

handle_cast({'DROP_FNS_FOR_DIE', PlayerId, Param2, Type, Color, X, Y, Pid, AerId}, State) ->
	NewState = lib_skyrush:change_fns_player(PlayerId, Param2, Type, Color, X, Y, Pid, AerId, State),
	{noreply, NewState};
	
handle_cast({'UPDATE_SKYRUSH_KILLDIE', PlayerId, AerId}, State) ->
	lib_skyrush:add_kill_die_num(PlayerId, AerId),
	{noreply, State};
handle_cast({'SKY_DIE_RESET', PlayerId, AerId, Type}, State) ->
	case Type of
		16 ->%%旗
%% 					io:format("A discard flags\n"),
			{_OColorA, OneListA} = State#skyrush.one_exist_flags,
			{_TColorA, TwoListA} = State#skyrush.two_exist_flags,
			{_HColorA, ThreeListA} = State#skyrush.three_exist_flags,
			NOneListA = lists:keydelete(PlayerId, 2, OneListA),
			NTwoListA = lists:keydelete(PlayerId, 2, TwoListA),
			NThreeListA = lists:keydelete(PlayerId, 2, ThreeListA),
			NewStateA = State#skyrush{one_exist_flags = {_OColorA, NOneListA},
									  two_exist_flags = {_TColorA, NTwoListA},
									  three_exist_flags = {_HColorA, NThreeListA}};
%% 			{ok, AData39018} = pt_39:write(39018, []),
%% 					mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, AX, AY, AData39018);
%% 			lib_send:send_to_sid(PidSendA, AData39018),
			%%广播头上的东西
%% 			{ok,BinData12041} = pt_12:write(12041, [PlayerId, 0]),
%% 			mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, AX, AY, BinData12041);
		17 ->%%据点
			PointLReadA = State#skyrush.point_l_read,
			PointHReadA = State#skyrush.point_h_read,
			NewPointLReadA = lists:keydelete(PlayerId, 2, PointLReadA),
			NewPointHReadA = lists:keydelete(PlayerId, 2, PointHReadA),
%% 					io:format("A discard pointL:~p>>~p;;~p\n", [AId, PointLReadA, NewPointLReadA]),
%% 					io:format("A discard pointH:~p>>~p;;~p\n", [AId, PointHReadA, NewPointHReadA]),
			NewStateA = State#skyrush{point_l_read = NewPointLReadA,
									  point_h_read = NewPointHReadA}
%% 			{ok, AData39017} = pt_39:write(39017, []),
%% 					mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, AX, AY, AData39017)
%% 			lib_send:send_to_sid(PidSendA, AData39017),
			%%广播头上的东西
%% 			{ok,BinData12041} = pt_12:write(12041, [PlayerId, 0]),
%% 			mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, AX, AY, BinData12041)
	end,
	lib_skyrush:add_kill_die_num(PlayerId, AerId),
	{noreply, NewStateA};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%%开始空岛通知
handle_info({'ENTER_SKY_RUSH_NOTICE', Type}, State) ->
	case Type of
		1 ->%%通告5分钟开始神岛空战
			lib_skyrush:send_skyrush_notice(1, []),
			
			%%全部广播，倒计时
			RemainTime = 5*60 - 5,
			{ok, BinData39023} = pt_39:write(39023, [RemainTime]),
			lib_send:send_to_all(BinData39023),
			
			erlang:send_after(?ENTER_SKY_RUSH_NOTICE_START, self(), {'ENTER_SKY_RUSH_NOTICE', 2});
		2 ->%%通告神岛空战开始了
			lib_skyrush:send_skyrush_notice(2, []),
			%%通知所有在线的玩家进入神岛
			%%获取整个参战的氏族列表Id
			case lib_skyrush:ets_get_sky_gids() of
				[] ->
					skip;
				Gids ->%%通知
					gen_server:cast(mod_guild:get_mod_guild_pid(), 
									{apply_cast, lib_skyrush, notice_all_sky_player, 
									 [Gids]})
			end;
		_ ->
			skip
	end,
	{noreply, State};

%%小怪物出动
handle_info({'INIT_LITTLT_MON'}, State) ->
	%%配置表
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	NowSec = util:get_today_current_second(),
	case NowSec >= SKY_RUSH_START_TIME andalso NowSec < SKY_RUSH_END_TIME of
		true ->%%只有在战场里面的时候，才会刷小怪
%% 			io:format("INIT_LITTLT_MON\n"),
			mod_skyrush_mon:init_skyrush_mon();
		false ->
			skip
	end,
	{noreply, State};

handle_info({'ONE_EXIST_FLAGS'}, State) ->
	%%配置表
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	NowSec = util:get_today_current_second(),
	case NowSec >= SKY_RUSH_START_TIME andalso NowSec < SKY_RUSH_END_TIME of
		true ->
	#skyrush{one_exist_flags = {Color, Players},
			 count = Num} = State,
%% 	io:format("one Players:~p\n", [Players]),
	NewPlayers = lists:map(fun(Elem) ->
								  {Time, PlayerId} = Elem,
								  {Time -1, PlayerId}
						  end, Players),
	case lists:keyfind(0, 1, NewPlayers) of
		false ->
			NewState = State#skyrush{one_exist_flags = {Color, NewPlayers}},
%% 			io:format("no player one\n"),
			erlang:send_after(1000, self(), {'ONE_EXIST_FLAGS'});
		{_Time, PlayerId} ->
			%%全场景通告取到旗了
%% 			io:format("get the flag one:~p\n", [PlayerId]),
			%%通知玩家carry_mark状态的改变
			lib_skyrush:update_player_flags_state(PlayerId, Color),
%% 			{ok, Data39010} = pt_39:write(39010, [PlayerId, 0, Color]),
%% 			spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39010) end),
			%%通告旗消失
			{ok, Data39015} = pt_39:write(39015, [Color, 1, PlayerId]),
			spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39015) end),
			%%复位玩家数据
			lib_skyrush:reset_player_flags(PlayerId, NewPlayers),
			NewNum = Num + 1,
			NewState0 =
				case Color of
					1 ->
						{FlagsNum, Flags} = State#skyrush.white_flags,
						State#skyrush{white_flags = {FlagsNum+1, [#fns_elem{player_id = PlayerId,
																			type = Color}| Flags]}};
					4 ->
						{FlagsNum, Flags} = State#skyrush.purple_flags,
						State#skyrush{purple_flags = {FlagsNum+1, [#fns_elem{player_id = PlayerId,
																			type = Color}| Flags]}}
				end,
			case (NewNum rem ?PURPLE_FLAGS_REFLESH_BASE =:= 0) orelse NewState0#skyrush.purple_reflesh =:= 1 of
				true ->
					NewState = NewState0#skyrush{count = NewNum,
												 purple_reflesh = 0,
												 one_exist_flags = {0, []}},
					erlang:send_after(5000, self(), {'REFLESH_FLAG', 1, 4});
				false ->
					NewState = NewState0#skyrush{count = NewNum,
												 one_exist_flags = {0, []}},
					erlang:send_after(5000, self(), {'REFLESH_FLAG', 1, 1})
			end
	end,
	{noreply, NewState};
		false ->
			{noreply, State}
	end;

handle_info({'TWO_EXIST_FLAGS'}, State) ->
	%%配置表
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	NowSec = util:get_today_current_second(),
	case NowSec >= SKY_RUSH_START_TIME andalso NowSec < SKY_RUSH_END_TIME of
		true ->
			#skyrush{two_exist_flags = {Color, Players},
%% 					 green_flags = {GFNum, _FPlayers},
					 count = Num} = State,
					NewPlayers = lists:map(fun(Elem) ->
												   {Time, PlayerId} = Elem,
												   {Time -1, PlayerId}
										   end, Players),
					case lists:keyfind(0, 1, NewPlayers) of
						false ->
							NewState = State#skyrush{two_exist_flags = {Color, NewPlayers}},
%% 			io:format("no player two\n"),
							erlang:send_after(1000, self(), {'TWO_EXIST_FLAGS'});
						{_Time, PlayerId} ->
							%%全场景通告取到旗了
%% 			io:format("get the flag two:~p\n", [PlayerId]),
							%%通知玩家carry_mark状态的改变
							lib_skyrush:update_player_flags_state(PlayerId, Color),
%% 			{ok, Data39010} = pt_39:write(39010, [PlayerId, 0, Color]),
%% 			spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39010) end),
							%%通告旗消失
							{ok, Data39015} = pt_39:write(39015, [Color, 2, PlayerId]),
							spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39015) end),
							%%复位玩家数据
							lib_skyrush:reset_player_flags(PlayerId, NewPlayers),
							NewNum = Num + 1,
							{FlagsNum, Flags} = State#skyrush.green_flags,
							NewState0 = State#skyrush{green_flags = {FlagsNum+1, [#fns_elem{player_id = PlayerId,
																							type = Color}| Flags]}},
							case (NewNum rem ?PURPLE_FLAGS_REFLESH_BASE) =:= 0 of
								true ->%%做出紫旗的标志位
									NewState = NewState0#skyrush{count = NewNum,
																 purple_reflesh = 1,
																 two_exist_flags = {0, []}};
								false ->
									NewState = NewState0#skyrush{count = NewNum,
																 two_exist_flags = {0, []}}
							end,
							erlang:send_after(5000, self(), {'REFLESH_FLAG', 2, 2})
					end,
			{noreply, NewState};
		false ->
			{noreply, State}
	end;
handle_info({'THREE_EXIST_FLAGS'}, State) ->
	%%配置表
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	NowSec = util:get_today_current_second(),
	case NowSec >= SKY_RUSH_START_TIME andalso NowSec < SKY_RUSH_END_TIME of
		true ->
			#skyrush{three_exist_flags = {Color, Players},
%% 					 blue_flags = {GFNum, _FPlayers},
					 count = Num} = State,
					NewPlayers = lists:map(fun(Elem) ->
												   {Time, PlayerId} = Elem,
												   {Time -1, PlayerId}
										   end, Players),
					case lists:keyfind(0, 1, NewPlayers) of
						false ->
							NewState = State#skyrush{three_exist_flags = {Color, NewPlayers}},
%% 			io:format("no player three\n"),
							erlang:send_after(1000, self(), {'THREE_EXIST_FLAGS'});
						{_Time, PlayerId} ->
							%%全场景通告取到旗了
%% 			io:format("get the flag three:~p\n", [PlayerId]),
							%%通知玩家carry_mark状态的改变
							lib_skyrush:update_player_flags_state(PlayerId, Color),
%% 			{ok, Data39010} = pt_39:write(39010, [PlayerId, 0, Color]),
%% 			spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39010) end),
							%%通告旗消失
							{ok, Data39015} = pt_39:write(39015, [Color, 3, PlayerId]),
							spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39015) end),
							%%复位玩家数据
							lib_skyrush:reset_player_flags(PlayerId, NewPlayers),
							NewNum = Num + 1,
							{FlagsNum, Flags} = State#skyrush.blue_flags,
							NewState0 = State#skyrush{blue_flags = {FlagsNum+1, [#fns_elem{player_id = PlayerId,
																						   type = Color}| Flags]}},
							case (NewNum rem ?PURPLE_FLAGS_REFLESH_BASE) =:= 0 of
								true ->%%做出紫旗的标志位
									NewState = NewState0#skyrush{count = NewNum,
																 purple_reflesh = 1,
																 three_exist_flags = {0, []}};
								false ->
									NewState = NewState0#skyrush{count = NewNum,
																 three_exist_flags = {0, []}}
							end,
							erlang:send_after(5000, self(), {'REFLESH_FLAG', 3, 3})
					end,
			{noreply, NewState};
		false ->
			{noreply, State}
	end;
handle_info({'REFLESH_FLAG', Area, Color}, State) ->
	%%配置表
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	NowSec = util:get_today_current_second(),
	case NowSec >= SKY_RUSH_START_TIME andalso NowSec < SKY_RUSH_END_TIME of
		true ->%%做时间控制
	NewState =
		case Area of
		1 ->
			case Color of
				1 ->
					skip;
				4 ->%%刷紫旗
					lib_skyrush:send_skyrush_notice(10, [])
			end,
			[X, Y] = lib_skyrush:get_flags_coord(Area),
			{ok, Data39014} = pt_39:write(39014, [Color, X, Y]),
			%%全场景的人通知
			spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39014) end),
			erlang:send_after(1000, self(), {'ONE_EXIST_FLAGS'}),
			State#skyrush{one_exist_flags = {Color, []}};
		2 ->
			#skyrush{green_flags = {GFNum, _FPlayers}} = State,
			case GFNum >= ?GREEN_FLAGS_MAX of
				false ->
					[X, Y] = lib_skyrush:get_flags_coord(Area),
					{ok, Data39014} = pt_39:write(39014, [Color, X, Y]),
					%%全场景的人通知
					spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39014) end),
					erlang:send_after(1000, self(), {'TWO_EXIST_FLAGS'}),
					State#skyrush{two_exist_flags = {Color, []}};
				true ->
					erlang:send_after(5000, self(), {'REFLESH_FLAG', 2, 2}),
					State
			end;
		3 ->
			#skyrush{blue_flags = {GFNum, _FPlayers}} = State,
			case GFNum >= ?BLUE_FLAGS_MAX of
				false ->
					[X, Y] = lib_skyrush:get_flags_coord(Area),
					{ok, Data39014} = pt_39:write(39014, [Color, X, Y]),
					%%全场景的人通知
					spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39014) end),
					erlang:send_after(1000, self(), {'THREE_EXIST_FLAGS'}),
					State#skyrush{three_exist_flags = {Color, []}};
				true ->
					erlang:send_after(5000, self(), {'REFLESH_FLAG', 3, 3}),
					State
			end
	end,
	{noreply, NewState};
		false ->%%已经结束了，不用刷
			{noreply, State}
	end;


%%据点的刷新和旗消失定时器
handle_info({'FLESH_POINT_AND_CLEAN_DROP_FLAGS'}, State) ->
	%%配置表
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	NowSec = util:get_today_current_second(),
	case NowSec >= SKY_RUSH_START_TIME andalso NowSec < SKY_RUSH_END_TIME of
		true ->
			%%据点刷新
			StateL = lib_skyrush:flesh_point_l(State),
%% 			StateH = lib_skyrush:flesh_point_h(StateL),%%屏蔽高级据点
			%%清理过期丢在地上的战旗			
			NewState = lib_skyrush:flesh_clean_drop_flags(StateL),
			erlang:send_after(1000, self(), {'FLESH_POINT_AND_CLEAN_DROP_FLAGS'}),
			{noreply, NewState};
		false ->
			{noreply, State}
	end;
		
%%定时刷新错误的数据
handle_info({'REFLESH_STATE'}, State) ->
	 #skyrush{white_flags = {WhiteNum, WhiteF},	
			  green_flags = {GreenNum, GreenF},
			  blue_flags = {BlueNum, BlueF},	
			  purple_flags = {PurpleNum, PurpleF}} = State,
	 {NewWNum, NewWF} = lib_skyrush:reflesh_flags_member(WhiteNum, WhiteF),
	 {NewGNum, NewGF} = lib_skyrush:reflesh_flags_member(GreenNum, GreenF),
	 {NewBNum, NewBF} = lib_skyrush:reflesh_flags_member(BlueNum, BlueF),
	 {NewPNum, NewPF} = lib_skyrush:reflesh_flags_member(PurpleNum, PurpleF),
	 NewState = State#skyrush{white_flags = {NewWNum, NewWF},	
							  green_flags = {NewGNum, NewGF},
							  blue_flags = {NewBNum, NewBF},	
							  purple_flags = {NewPNum, NewPF}},
	 erlang:send_after(3000, self(), {'REFLESH_STATE'}),
	 {noreply, NewState};

	
%% -----------------------------------------------------------------
%% 39009 结束神战
%% -----------------------------------------------------------------
handle_info({'END_SKY_RUSH'}, State) ->
	lib_skyrush:handle_skyrush_end(State),
	{ok, Data39009} = pt_39:write(39009, []),%%全场景的人通知
%% 	spawn(fun()->timer:apply_after(120000, mod_scene_agent, send_to_scene,[?SKY_RUSH_SCENE_ID, Data39009]) end)
	spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39009) end),
	%%120秒之后，把所有未出神岛的玩家全部请出战场
	erlang:send_after(120000, self(), {'END_SKY_RUSH', []}),
	{noreply, State};
		
%%时间到了，主动传出战场
handle_info({'END_SKY_RUSH', []}, State) ->
	lib_skyrush:send_outsky(),
	erlang:send_after(60000, self(), {'CLEAN_SKY_RUSH'}),%%为了保证,改成1分钟
	{noreply, State};
%%7秒后清场景
handle_info({'CLEAN_SKY_RUSH'}, State) ->
	%%清表
	ets:delete(?G_FEATS_ELEM),
	ets:delete(?MEM_FEATS_ELEM),
	lib_scene:clear_scene(?SKY_RUSH_SCENE_ID),%%清场景数据
	{stop, normal, State};

	
			
handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(Reason, State) ->
	case Reason of
		normal ->
			skip;
		_ ->
			?WARNING_MSG("skyrush terminate: Reason ~p\n State ~p\n", [Reason, State])
	end,
	ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% 提供氏族战奖励的接口
%% --------------------------------------------------------------------

%% -----------------------------------------------------------------
%% 39026 氏族战奖励	分配上一场空战信息及物品获取物品
%% -----------------------------------------------------------------
get_sky_award_and_members(GuildId) ->
	try
		case gen_server:call(mod_guild:get_mod_guild_pid(),
							 {apply_call, lib_skyrush, get_sky_award_and_members, 
							  [GuildId]}) of
			error -> 
				[[],[]];
			Data ->
				Data
		end
	catch
		_:_Reason ->
			?DEBUG("get_sky_award_and_members fail for the reason:[~p]", [_Reason]),
			[[],[]]
	end.


%% -----------------------------------------------------------------
%% 39027 氏族战奖励	物品分配物品
%% -----------------------------------------------------------------
assign_goods_man(GuildId, PlayerId, GoodsId, Num) ->
	%%因为涉及到并发问题，此操作专门使用Id号为0的进程执行
	ProcessName = misc:create_process_name(guild_p, [0]),
	GuildPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->
						Pid;
					false ->
						mod_guild:start_mod_guild(ProcessName)
				end;
			_ ->
				mod_guild:start_mod_guild(ProcessName)
		end,
	try
		case gen_server:call(GuildPid,
							 {apply_call, lib_skyrush, assign_goods_man,
							  [GuildId, PlayerId, GoodsId, Num]}) of
			error ->
				[0, GoodsId, 0];
			Data ->
				Data
		end
	catch
		_:_Reason ->
			?DEBUG("assign_goods_man fail for the reason:[~p]", [_Reason]),
			[0, GoodsId, 0]
	end.
	
%% -----------------------------------------------------------------
%% 39028 氏族战奖励	物品自动分配
%% -----------------------------------------------------------------
assign_goods_auto(GuildId) ->
	%%因为涉及到并发问题，此操作专门使用Id号为0的进程执行
	ProcessName = misc:create_process_name(guild_p, [0]),
	GuildPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->
						Pid;
					false ->
						mod_guild:start_mod_guild(ProcessName)
				end;
			_ ->
				mod_guild:start_mod_guild(ProcessName)
		end,
	try
		case gen_server:call(GuildPid,
							 {apply_call, lib_skyrush, assign_goods_auto,
							  [GuildId]}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_Reason ->
			?DEBUG("assign_goods_auto fail for the reason:[~p]", [_Reason]),
			0
	end.
	
%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------

