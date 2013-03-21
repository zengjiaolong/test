%%% -------------------------------------------------------------------
%%% Author  : xianrongMai
%%% Description :神魔乱斗的怪物控制器
%%%
%%% Created : 2011-11-28
%%% -------------------------------------------------------------------
-module(mod_warfare_mon).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("guild_info.hrl").

-define(REFLESH_ATTACK_TIMESTAMP, 10000).		%%神魔乱斗伤害值刷新时间戳(ms)

%% --------------------------------------------------------------------
%% External exports
-export([
		 get_warfare_mon/0,				%%获取神魔乱斗的怪物控制器进场Pid
		 init_warfare_mon/0,			%%初始化神魔乱斗的怪物控制器
		 get_warfare_mon_info/0			%%获取进程状态信息
		]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%%怪物刷新顺序和数量{怪物Id, 刷新数量, 刷新等待时间(s)}
-define(MON_F5_LIST, [{43101, 100, 60}, {43101, 100, 60}, {43101, 100, 60}, 
					  {43102, 100, 60}, {43102, 100, 60}, {43102, 100, 60}, 
					  {43103, 100, 60}, {43103, 100, 60}, {43103, 100, 60},
					  {43104, 1, 60}, 
					  {43105, 1, 60}]).	
-define(PLUTO_EXIST_TIME, 5*60).				%%冥王之灵存活的时间(5分钟)
-define(ATTACK_GROUP_NUM, 10).					%%向客户端发送伤害列表的玩家个数
%%绑定铜刷新坐标X,Y范围
-define(BCOIN_X_LIMIT, [2, 35]).
-define(BCOIN_Y_LIMIT, [15, 66]).
%%神魔乱斗碰撞铜币的奖励数值
-define(TRANSLATE_BCOIN_AWARD, 500).

%%测试数据===============================
%% 怪物刷新顺序和数量{怪物Id, 刷新数量, 刷新等待时间(s)}
%% -define(MON_F5_LIST, [{43101, 20, 60}, 
%% 					  {43102, 20, 60}, {43103, 20, 60}, 
%% 					  {43101, 20, 60}, {43101, 20, 60}, {43101, 20, 60}, 
%% 					  {43101, 20, 60}, {43101, 20, 60}, {43101, 20, 60}, 
%% 					  {43101, 5, 60}, {43101, 5, 60}, {43101, 5, 60}, 
%% 					  {43101, 5, 60}, {43101, 5, 60}, {43101, 5, 60}, 
%% 					  {43101, 5, 60}, {43101, 5, 60}, {43101, 5, 60}, 
%% 					  {43101, 5, 60}, {43101, 5, 60}, {43101, 5, 60}, 
%% 					  {43101, 5, 60}, {43101, 5, 60}, {43101, 5, 60}, 
%% 					  {43102, 5, 60}, {43102, 5, 60}, {43102, 5, 60}, 
%% 					  {43103, 5, 60}, {43103, 5, 60}, {43103, 5, 60},
%% 					  {43104, 1, 60}, 
%% 					  {43105, 1, 60}]).
%%测试数据===============================


-record(k_p, {id = 0,			%%玩家Id
			  name = "",		%%姓名
			  lv = 0,			%%玩家等级
			  realm = 0,		%%部落
			  career = 0,		%%职业
			  sex = 0,			%%性别
			  gid = 0,			%%氏族Id
			  gname	= "",		%%氏族名字
			  pid = undefined	%%玩家进程Pid
			 }).

-record(state, {
				attack = {0,0,[]},			%%伤害列表, {是否要计算伤害(1:计算伤害,0:不计算了),总伤害值(伤害基数), 伤害成员了列表}
				over = 0,					%%活动结束了，屏蔽所有的定时器
				end_time = 0,				%%冥王之灵的时间到期时间
				kill_mems = [],				%%参与击杀boss并且有可能拿到冥王之灵的玩家列表, #k_p{}
				plutos = [],				%%目前拿到冥王之灵的玩家Id列表	#k_p{}
				mon_mp_add = [],			%%不同的怪物的增加血量级数
				f5_time = 0,				%%最近一次的怪物刷新时间
				mlist = ?MON_F5_LIST,		%%当前还剩余的可以刷洗的怪物数据
				max_lv = 0,					%%当前服务器最高等级	
				bcoin = 0,					%%当前的绑定铜是否可以碰撞，0：不是碰撞的时间，碰撞无效，1：可以碰撞了，哟，有可能得到绑定铜
				bcoin_list = [], 				%%当前的绑定铜的位置列表{Key, IsGot, {X, Y}} IsGot:0,没有被碰撞的，可以来领取绑定铜的;1,已经被碰撞过了的，绑定铜已经被领取了的
				drop_id = 0   
			}).

%% ====================================================================
%% External functions
%% ====================================================================


%% ====================================================================
%% Server functions
%% ====================================================================
%%初始化神魔乱斗的怪物控制器
init_warfare_mon() ->
	gen_server:start(?MODULE, [], []).


%%获取神魔乱斗的pid
get_warfare_mon() ->
	ProcessName = mod_warfare_mon,
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
%% 			?DEBUG("THE PROCESS IS BUILD", []),
			{ok, Pid};
		_Other ->
%% 			?DEBUG("OMG THE PROCESS IS NOT BUILD, ~p", [_Other]),
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
%% 	?DEBUG("init the warfare mon", []),
	process_flag(trap_exit, true),
	Self = self(),
	%% 初始战场
	SceneProcessName = mod_warfare_mon,
	case misc:register(global, SceneProcessName, Self) of
		yes ->
%% 			?DEBUG("ok!", []),
			%%获取当前服务器的最高等级
			MaxLv = get_max_level(),
			%% 获取最新的神魔乱斗中怪物的血量和攻击增量级数
			MonMpAdd = lib_warfare:get_mon_warfare(),
			NState = #state{max_lv = MaxLv,
							mon_mp_add = MonMpAdd},
%% 			?DEBUG("MaxLv:~p, MonMpAdd:~p", [MaxLv, MonMpAdd]),
			%%5秒之后开始刷新怪物
			erlang:send_after(5000, Self, {'REFRESH_MON', 43101, 0, []}),
%% 			?DEBUG("send after", []),
			NowSec = util:get_today_current_second(),
			%%神魔乱斗时间time
			{_Start, End} = lib_warfare:get_warfare_time(),
			RTime = abs(End - NowSec),
			%%全服广播
			{ok, BinData39101} = pt_39:write(39101, [RTime]),
			SysEndTime = RTime - 310,
			%%做最后五分钟的时间纠正
			case SysEndTime > 0 of
				true ->
					spawn(fun() -> timer:apply_after(SysEndTime*1000, lib_warfare, broadcast_warfare_time, [300]) end);
				false ->
					skip
			end,
			%%到时候要请场景怪物
			erlang:send_after(RTime*1000, self(), {'CLEAR_WARFARE_MON'}),
			%%全服广播
			lib_send:send_to_all(BinData39101),
			{ok, NState};
		_ ->
%% 			?DEBUG("FAIL OMG!", []),
			{stop, normal, []}
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
	DropId = State#state.drop_id + DropNum + 1,
	NewDropId = 
		if
   			DropId > ?MON_LIMIT_NUM ->
				1;
	   		true ->
				DropId
        end,
	NewState = State#state{
		drop_id = NewDropId
	},
    {reply, State#state.drop_id, NewState};

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

handle_cast({'WARFARE_MON_INFO'}, State) ->
	io:format("The State is :~p\n", [State]),
	{noreply, State};

%%怪物控制器接受信息，处理冥王之灵的交接
handle_cast({'PLUTO_ADMIN_CHANGED', DPid, DPName, DGName, DGid, APid, AerId, AerName}, State) ->
	%% 	?DEBUG("PLUTO_ADMIN_CHANGED:DPid:~p, DGid:~p", [DPid, DGid]),
	case State#state.over =/= 0 of
		true ->%%不等于0，屏蔽所有的定时器
			{noreply, State};
		false ->
			Plutos = lists:keydelete(DPid, #k_p.id, State#state.plutos),
			case lists:keyfind(AerId, #k_p.id, Plutos) of
				false ->%%是没有的
					case (catch gen_server:call(APid, {'GOT_WARFARE_PLUTO'})) of
						{'EXIT', Info} ->
							?WARNING_MSG("PLUTO_ADMIN_CHANGED fail because of ~p",[Info]),
							%%场景广播
							lib_warfare:world_brodcast(9, {0, "", AerName, DGid, DGName, DPName}),
							%%给予新的玩家
							NKP = lists:keydelete(DPid, #k_p.id, State#state.kill_mems),
							NPlutos = travel_give_plutos(NKP, Plutos),
							%% 					 %%更新新的拥有冥王之灵的玩家列表
							NState = State#state{plutos = NPlutos};
						{HadPluto, Param} ->
%% 							?DEBUG("HadPluto result is :~p, Param:~p", [HadPluto, Param]),
							case HadPluto of
								0 ->%%死亡了或者不在这个场景，不给了
									{NPid, NPName, NGName, NGid} = Param,
									%%场景广播
									lib_warfare:world_brodcast(9, {NGid, NGName, NPName, DGid, DGName, DPName}),
									%%给予新的玩家
									NKP0 = lists:keydelete(NPid, #k_p.id, State#state.kill_mems),
									NKP = lists:keydelete(DPid, #k_p.id, NKP0),
									NPlutos = travel_give_plutos(NKP, Plutos),
									%% 					 %%更新新的拥有冥王之灵的玩家列表
									NState = State#state{plutos = NPlutos};
								1 ->%%呵呵，没有的，现在拿到了
									{NPid, NPName, NLv, NRealm, NCareer, NSex, NGid, NGName, NPPid} = Param,
									%%场景广播
									lib_warfare:world_brodcast(7, {NGid, NGName, NPName, DGid, DGName, DPName}),
									NKP = #k_p{id = NPid,			%%玩家Id
											   name = NPName,		%%姓名
											   lv = NLv,
											   realm = NRealm,		%%部落
											   career = NCareer,		%%职业
											   sex = NSex,			%%性别
											   gid = NGid,			%%氏族Id
											   gname	= NGName,		%%氏族名字
											   pid = NPPid	%%玩家进程Pid
											  },
									%%更新新的拥有冥王之灵的玩家列表
									NState = State#state{plutos = [NKP|Plutos]};
								2 ->
									{NPid, NPName, NLv, NRealm, NCareer, NSex, NGid, NGName, NPPid} = Param,
									%%场景广播
									lib_warfare:world_brodcast(7, {NGid, NGName, NPName, DGid, DGName, DPName}),
									NKP = #k_p{id = NPid,			%%玩家Id
											   name = NPName,		%%姓名
											   lv = NLv,
											   realm = NRealm,		%%部落
											   career = NCareer,		%%职业
											   sex = NSex,			%%性别
											   gid = NGid,			%%氏族Id
											   gname	= NGName,		%%氏族名字
											   pid = NPPid	%%玩家进程Pid
											  },
									%%更新新的拥有冥王之灵的玩家列表
									NState = State#state{plutos = [NKP|Plutos]}
							end
					end;
				_ ->
%% 					?DEBUG("has the pluto yet!,AerId:~p, DPid:~p", [AerId, DPid]),
					%%场景广播
					lib_warfare:world_brodcast(9, {0, "", AerName, DGid, DGName, DPName}),
					%%给予新的玩家
					NKP0 = lists:keydelete(AerId, #k_p.id, State#state.kill_mems),
					NKP = lists:keydelete(DPid, #k_p.id, NKP0),
					NPlutos = travel_give_plutos(NKP, Plutos),
					%% 					 %%更新新的拥有冥王之灵的玩家列表
					NState = State#state{plutos = NPlutos}
			end,
			%%向客户端通知冥王之灵的新的拥有者
			RTime = abs(NState#state.end_time - util:unixtime()),
			send_pluto_pinfo(NState#state.plutos, RTime),
			{noreply, NState}
	end;

%%玩家下线
handle_cast({'PLUTO_OWN_OFFLINE', PlayerId}, State) ->
%% 	?DEBUG("PLUTO_OWN_OFFLINE:~p", [PlayerId]),
	case State#state.over =/= 0 of
		true ->%%不等于0，屏蔽所有的定时器
			{noreply, State};
		false ->
	#state{kill_mems = KP,
		   plutos = Plutos} = State,
	NKP = lists:keydelete(PlayerId, #k_p.id, KP),
	DPlutos = lists:keydelete(PlayerId, #k_p.id, Plutos),
	%%给予新的玩家
	NPlutos = travel_give_plutos(NKP, DPlutos),
	NState = State#state{kill_mems = NKP,
						 plutos = NPlutos},
	NowTime = util:unixtime(),
	Diff = State#state.end_time - NowTime,
	case Diff > 0 of
		true ->
			%%向客户端发送冥王之灵的拥有者名单
			send_pluto_pinfo(NState#state.plutos, Diff);
		false ->
			%%向客户端发送冥王之灵的拥有者名单
			send_pluto_pinfo(NState#state.plutos, 1)
	end,
	{noreply, NState}
	end;

%%玩家进入神魔乱斗的场景
handle_cast({'PLAYER_ENTER_WARFARE', PidSend}, State) ->
	case State#state.over =/= 0 of
		true ->%%不等于0，屏蔽所有的定时器
			{noreply, State};
		false ->
			NowTime = util:unixtime(),
			#state{end_time = EndTime,
				   attack = {AType, AttSum, List},
				   bcoin = BCoin,
				   bcoin_list = BCoinList} = State,
			case AttSum =/= 0 andalso (EndTime =:= 0 orelse EndTime > NowTime) of
				true ->%%需要发伤害值列表
					%%获取需要广播的数据
					{SubList, NList} = sort_player_attacks(List),
					%%向客户端推送伤害列表信息
					{ok, BinData39105} = pt_39:write(39105, [AttSum, SubList]),
					lib_send:send_to_sid(PidSend, BinData39105),
					NState = State#state{attack = {AType, AttSum, NList}};
				false ->
					NState = State
			end,
			case EndTime of
				0 ->
					skip;
				_ ->
					Diff = EndTime - NowTime,
					case Diff > 0 of
						true ->
							%%向客户端发送冥王之灵的拥有者名单
							PlutoNames = [Elem#k_p.name|| Elem <- State#state.plutos],
							{ok, BinData39103} = pt_39:write(39103, [Diff, PlutoNames]),
							lib_send:send_to_sid(PidSend, BinData39103);
						false ->
							skip
					end
			end,
			%%判断是否需要发送绑定铜的位置
			case BCoin =:= 1 of
				true ->
					{ok, BinData39107} = pt_39:write(39107, [BCoinList]),
					lib_send:send_to_sid(PidSend, BinData39107);
				false ->
					skip
			end,
	{noreply, NState}
	end;

handle_cast({'TRANSLATE_BCOIN', PlayerId, Pid, PidSend, Key, PX, PY}, State) ->
	case State#state.over =/= 0 of
		true ->%%不等于0，屏蔽所有的定时器
			{noreply, State};
		false ->
			#state{bcoin = BCoin,
				   bcoin_list = BCoinList} = State,
			case BCoin =:= 1 of
				true ->
					BCoinNumLimit = length(BCoinList),
					case Key > 0 andalso Key =< BCoinNumLimit of
						false ->%%值太大了吧
							{ok, BinData39108} = pt_39:write(39108, [4, 0]),
							lib_send:send_to_sid(PidSend, BinData39108),
							{noreply, State};
						true ->
							{_Key, IsGot, {BX, BY}} = lists:nth(Key, BCoinList),
							case IsGot of
								0 ->%%哟，居然可以拿得到，good
									ABX = abs(PX-BX),
									ABY = abs(PY-BY),
									case ABX =< 1 andalso ABY =< 1 of
										true ->
											%%通知个人，得到绑定铜啦
											gen_server:cast(Pid, {'TRANSLATE_BCOIN_SUCCEED', ?TRANSLATE_BCOIN_AWARD}),
											%%全场景的绑定铜更新
											{ok, BinData39109} = pt_39:write(39109, [Key, PlayerId]),
											spawn(fun() -> mod_scene_agent:send_to_scene(?WARFARE_SCENE_ID, BinData39109) end),
											NBCoinList = tool:replace(BCoinList, Key, {Key, 1, {BX,BY}}),
											NState = State#state{bcoin_list = NBCoinList},
											{noreply, NState};
										false ->%%距离还是不够，太远了
											{ok, BinData39108} = pt_39:write(39108, [5, 0]),
											lib_send:send_to_sid(PidSend, BinData39108),
											{noreply, State}
									end;
								_ ->
									{ok, BinData39108} = pt_39:write(39108, [2, 0]),
									lib_send:send_to_sid(PidSend, BinData39108),
									{noreply, State}
							end
					end;
				false ->%%不是碰撞的时间，这个消息无效的
					{ok, BinData39108} = pt_39:write(39108, [3, 0]),
					lib_send:send_to_sid(PidSend, BinData39108),
					{noreply, State}
			end
	end;

handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 通知怪物被削了，数量减少Num只
handle_info({'REFRESH_MON', DieMonId, Num, KillMems}, State) ->
	case State#state.over =/= 0 of
		true ->%%不等于0，屏蔽所有的定时器
			{noreply, State};
		false ->
			%% 	?DEBUG("REFRESH_MON:~p", [{DieMonId, Num, KillMems}]),
			MList = State#state.mlist,
			case MList of
				[] ->
					{noreply, State};
				[{MonId, RNum, F5Time}|Rest] ->%%{怪物Id, 刷新数量, 刷新次数, 刷新等待时间(s)}
					case MonId =:= DieMonId of
						false ->%%这个消息传送错了，哎
							{noreply, State};
						true ->
							case Num of
								0 ->%%第一次刷怪
									%% 							?DEBUG("first refresh mon", []),
									erlang:send_after(F5Time*1000, self(), {'MON_LANDING'}),
									{noreply, State};
								1 ->
									%% 							?DEBUG("kill mon", []),
									NewRNum = RNum - Num,
									case NewRNum =< 0 of
										true ->%%怪物已经刷完了
											%% 									?DEBUG("kill mon num < 0 and rest is :~p", [Rest]),
											case Rest of
												[] ->%%最后一个怪也没了, 最后一个怪是冥王，现在要开始处理冥王之灵的归属了
													%%怪物死亡的时候广播
													lib_warfare:mon_bekill_broadcast(MonId),
													{_S, _A, Attacks} = State#state.attack,
													{GM, KM} = give_pluto_first(KillMems, Attacks),
													%%全服广播+玩家头顶图标通知
													broadcast_got_pluto(GM),
													%%向客户端通知冥王之灵的新的拥有者
													%%冥王之灵的到期时间
													PlutoEndTime = util:unixtime()+ ?PLUTO_EXIST_TIME,
													send_pluto_pinfo(GM, ?PLUTO_EXIST_TIME),
													%%判断是否需要增加下一波怪物的血量
													#state{mon_mp_add = MonMpAdd} = State,
													NMonMpAdd = check_increase_monmp(MonId, State#state.f5_time, MonMpAdd),
													NState = State#state{attack = {0, _A, Attacks},%%更新不需要再向客户端发送伤害列表,%%设置为1
																		 end_time = PlutoEndTime, 	%%冥王之灵的到期时间
																		 kill_mems = KM,			%%参与击杀boss并且有可能拿到冥王之灵的玩家列表, k_p
																		 plutos = GM,				%%目前拿到冥王之灵的玩家Id列表
																		 mon_mp_add = NMonMpAdd,
																		 mlist = []
																		},
													%%?PLUTO_EXIST_TIME秒之后，进行冥王之灵的最终分配
													%%5秒之后开启冥王之灵获得者的轮询
%% 													erlang:send_after(5000, self(), {'REFLESH_PLUTO_PLAYER'}),
													erlang:send_after(?PLUTO_EXIST_TIME*1000, self(), {'END_PLUTO_AWARD'}),
													{noreply, NState};
												_ ->
													%%怪物死亡的时候广播
													lib_warfare:mon_bekill_broadcast(MonId),
													%%判断是否需要增加下一波怪物的血量
													MonMpAdd = State#state.mon_mp_add,
													NMonMpAdd = check_increase_monmp(MonId, State#state.f5_time, MonMpAdd),
													[{_RMonId, _RNum, RF5Time}|_] = Rest,
													erlang:send_after(RF5Time*1000, self(), {'MON_LANDING'}),
													Nstate = State#state{mon_mp_add = NMonMpAdd,
																		 mlist = Rest},
													BCoinState = %%判断是需要出绑定铜
														case length(Rest) >= 1 of
															true ->%%还未到最后一个怪
																BCoinList = make_random_bcoin_coord(?BCOIN_NUM_LIMIT, []),
																%全场景的绑定铜更新
																{ok, BinData39107} = pt_39:write(39107, [BCoinList]),
																spawn(fun() -> mod_scene_agent:send_to_scene(?WARFARE_SCENE_ID, BinData39107) end),
																Nstate#state{bcoin = 1,
																			bcoin_list = BCoinList};
															false ->
																Nstate
														end,
													{noreply, BCoinState}
											end;
										false ->
%% 											?DEBUG("kill mon the rest is :~p", [NewRNum]),
											%%怪物都还未全部死，不用刷新的怪物
											NMList = [{MonId, NewRNum, F5Time}|Rest],
											Nstate = State#state{mlist = NMList},
											{noreply, Nstate}
									end
							end
					end
			end
	end;
				
									 
											
%% 怪物空降											
handle_info({'MON_LANDING'}, State) ->
	case State#state.over =/= 0 of
		true ->%%不等于0，屏蔽所有的定时器
			{noreply, State};
		false ->
	[{MonId, RNum, _F5Time}|_Rest] = State#state.mlist,
	%%广播
	lib_warfare:mon_refresh_broadcast(MonId),
	%%获取血量和攻击增加的级数
	MonAdd = 
		case lists:keyfind(MonId, 1, State#state.mon_mp_add) of
			false ->
				0;
			{_MonId, Add} ->
				Add
		end,
	%%刷怪
	lib_warfare:mon_loading({MonId, RNum}, MonAdd, State#state.max_lv),
	%%修改怪物刷新时间
	NowTime = util:unixtime(),
%% 	NMList = [{MonId, RNum, F5Time}|Rest],
	F5State = State#state{f5_time = NowTime},
	%%判断是否需要开启伤害值统计,并计算相关的初始化数据
	NState = check_attack_count(F5State, MonId, State#state.mon_mp_add),
	%%绑定铜的状态更新更新
	NewState = 
		case NState#state.bcoin =:= 1 of
			true ->
				%%广播绑定铜的消失
				{ok, BinData39110} = pt_39:write(39110, []),
				spawn(fun() -> mod_scene_agent:send_to_scene(?WARFARE_SCENE_ID, BinData39110) end),
				NState#state{bcoin = 0,
							 bcoin_list = []};
			false ->
				NState#state{bcoin = 0,
							 bcoin_list = []}
		end,
	{noreply, NewState}
	end;
			
handle_info({'REFLESH_ATTACK_LIST'}, State) ->
	case State#state.over =/= 0 of
		true ->%%不等于0，屏蔽所有的定时器
			{noreply, State};
		false ->
%% 			?DEBUG("REFLESH_ATTACK_LIST", []),
			{Type, AttSum, List} = State#state.attack,
			%%获取需要广播的数据
			{SubList, NList} = sort_player_attacks(List),
			%%广播
			broadcast_player_attacks(AttSum, SubList),
			Nstate = State#state{attack = {Type, AttSum, NList}},
			case Type of
				1 ->%%继续定时刷新
					erlang:send_after(?REFLESH_ATTACK_TIMESTAMP, self(), {'REFLESH_ATTACK_LIST'});
				_ ->
					skip
			end,
			{noreply, Nstate}
	end;

handle_info({'UPDATE_PLAYER_ATTACK', Pid, PName, Att}, State) ->
	case State#state.over =/= 0 of
		true ->%%不等于0，屏蔽所有的定时器
%% 			?DEBUG("over is :~p", [State#state.over]),
			{noreply, State};
		false ->
			{Type, AttSum, List} = State#state.attack,
%% 			?DEBUG("UPDATE_PLAYER_ATTACK,Pid:~p, Att:~p, and Type is :~p", [Pid, Att, Type]),
			case Type of
				1 ->%%ok，这个可以加
					NList = 
						case lists:keyfind(Pid, 1, List) of
							false ->
								[{Pid, PName, Att}|List];
							{_Pid, _PName, OldAtt} ->
								NAtt = Att + OldAtt,
								lists:keyreplace(Pid, 1, List, {Pid, PName, NAtt})
						end,
					NState = State#state{attack = {Type, AttSum, NList}},
					{noreply, NState};
				_ ->
					{noreply, State}
			end
	end;
					
handle_info({'REFLESH_PLUTO_PLAYER'}, State) ->
	case State#state.over =/= 0 of
		true ->%%不等于0，屏蔽所有的定时器
			{noreply, State};
		false ->
			NowTime = util:unixtime(),
			Diff = State#state.end_time - NowTime,
			case Diff > 0 of
				true ->
					{IsFresh, NState} = 
						lists:foldl(fun(Elem, {EIsFresh, EState}) ->
											#state{kill_mems = EKP,
												   plutos = EPlutos} = EState,
											#k_p{id = EPlayerId} = Elem,
											case lib_player:get_online_info_fields(EPlayerId, [scene, carry_mark, hp, pid]) of
												[EScene, ECarryMark, EHP, EPid] ->
													case EScene =:= ?WARFARE_SCENE_ID andalso ECarryMark =:= 27 andalso EHP > 0 of
														true ->
															{EIsFresh, EState};
														false ->
															NEKP = lists:keydelete(EPlayerId, #k_p.id, EKP),
															DEPlutos = lists:keydelete(EPlayerId, #k_p.id, EPlutos),
															%%给予新的玩家
															NEPlutos = travel_give_plutos(NEKP, DEPlutos),
															NEState = EState#state{kill_mems = NEKP,
																				   plutos = NEPlutos},
															gen_server:cast(EPid, {'PLUTO_SYSTEM_CHANGE'}),
															{1, NEState}
													end;
												_Other ->
													NEKP = lists:keydelete(EPlayerId, #k_p.id, EKP),
													DEPlutos = lists:keydelete(EPlayerId, #k_p.id, EPlutos),
													%%给予新的玩家
													NEPlutos = travel_give_plutos(NEKP, DEPlutos),
													NEState = EState#state{kill_mems = NEKP,
																		   plutos = NEPlutos},
													{1, NEState}
											end
									end, {0, State}, State#state.plutos),
					case IsFresh of
						1 ->
							%%向客户端发送冥王之灵的拥有者名单
							send_pluto_pinfo(NState#state.plutos, Diff);
						_ ->%%不用做操作
							skip
					end,
					erlang:send_after(5000, self(), {'REFLESH_PLUTO_PLAYER'}),
%% 					?DEBUG("REFLESH_PLUTO_PLAYER:~p", [NState#state.plutos]),
					{noreply, NState};
				false ->
					{noreply, State}
			end
	end;
		
handle_info({'END_PLUTO_AWARD'}, State) ->
	case State#state.over =/= 0 of
		true ->%%不等于0，屏蔽所有的定时器
			{noreply, State};
		false ->
	Plutos = State#state.plutos,
	%%{Gid, GName, PlayerId, PlayerName, Career, Sex}
	{Param, SGInfo} = 
		lists:foldl(fun(Elem, AccIn) ->
							{A,B} = AccIn,
							#k_p{id = EPid,			%%玩家Id
								 name = EPName,	%%姓名
								 realm = _ERealm,		%%部落
								 career = ECareer,		%%职业
								 sex = ESex,			%%性别
								 gid = EGid,			%%氏族Id
								 gname	= EGName,		%%氏族名字
								 lv = ELv,				%%玩家等级
								 pid = _EPPid	%%玩家进程Pid
								} = Elem,
							%%得到冥王之灵的玩家将会收到一封奖励的信件
							lib_warfare:pluto_award_mail(EPName),
							NB = 
								case lists:keyfind(EGid, 1, B) of
									false ->
										{AddExp, AddSpri} = {erlang:trunc((ELv * ?ADD_EXP) / 2), erlang:trunc((ELv * ?ADD_SPRI) / 2)},
										[{EGid, [EPid], {AddExp, AddSpri}}|B];
									{_EGid, PList, {FAddExp, FAddSpri}} ->
										{AddExp, AddSpri} = {erlang:trunc((ELv * ?ADD_EXP) / 2), erlang:trunc((ELv * ?ADD_SPRI) / 2)},
										Add = 
											case AddExp > FAddExp of
												true ->
													{AddExp, AddSpri};
												false ->
													{FAddExp, FAddSpri}
											end,
										lists:keyreplace(EGid, 1, B, {EGid, [EPid|PList], Add})
								end,
							{[{EGid, EGName,EPid,EPName,ECareer,ESex}|A],NB}
					end, {[], []}, Plutos),
	%%世界广播
	case Param of
		[] ->
			skip;
		_ ->
			lib_warfare:world_brodcast(4, Param)
	end,
	%%给在神魔乱斗场景上的玩家发经验和灵力奖励
	lib_warfare:warfare_award(SGInfo),
%% 	%%把进程结束掉
%% 	erlang:send_after(300000, self(), {'END_SELF'}),
	{noreply, State}
	end;



handle_info({'CLEAR_WARFARE_MON'}, State) ->
%% 	?DEBUG("CLEAR_WARFARE_MON", []),
%% 	case State#state.end_time of
%% 		0 ->
			ScenePid = mod_scene:get_scene_pid(?WARFARE_SCENE_ID, undefined, undefined),
			%%通知场景进程清理怪物啦
			gen_server:cast(ScenePid, {apply_cast, mod_mon_create, clear_scene_mon, [?WARFARE_SCENE_ID]}),
			%%把所有的人都传出来
			mod_scene_agent:send_to_scene_for_event(?WARFARE_SCENE_ID, {'SEND_OUT_WARFARE'}),
			%%把进程结束掉
			erlang:send_after(300000, self(), {'END_SELF'}),
%% 		_ ->
%% 			skip
%% 	end,
	%%这个期间，屏蔽所有的定时器，over = 1,
	NState = State#state{over = 1},
	{noreply, NState};

handle_info({'END_SELF'}, State) ->
	ScenePid = mod_scene:get_scene_pid(?WARFARE_SCENE_ID, undefined, undefined),
	%%通知场景进程清理怪物啦
	gen_server:cast(ScenePid, {apply_cast, mod_mon_create, clear_scene_mon, [?WARFARE_SCENE_ID]}),
	{stop, normal, State};

handle_info(_Info, State) ->
%% 	?DEBUG("handle info:~p", [_Info]),
    {noreply, State}.
%%获取已经出现过的血量增长级数
%% 			WinNum = get_mon_increase(),
%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
	case _Reason of
		normal ->
			skip;
		_ ->
			?WARNING_MSG("warfare mon process  terminate: Reason ~p\n State ~p\n", [_Reason, _State])
	end,
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%全服广播+玩家头顶图标通知
broadcast_got_pluto(GM) ->
	Param = make_broadcast_param(GM),
	%%世界广播
	lib_warfare:world_brodcast(3, Param).

%% {Gid, GName, PlayerId, PlayerName, Career, Sex}
make_broadcast_param(GM) ->
	F = fun(FElem) ->
				#k_p{id = Pid,
					 name = PName,
					 career = Career,
					 sex = Sex,
					 gid = Gid,
					 gname = GName,
					 pid = PPid} = FElem,
				gen_server:cast(PPid, {'GIVE_WARFARE_PLUTO'}),
				{Gid, GName, Pid, PName, Career, Sex}
		end,
	[F(Elem)|| Elem <- GM].

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------
%%获取当前服务器的最高等级
get_max_level() ->
	case db_agent:get_max_level() of
		null ->
			37;
		Lv when Lv < 37 ->
			37;
		OtherLv ->
			OtherLv
	end.
%%判断是否需要增加下一波怪物的血量
check_increase_monmp(MonId, F5Time, MonMpAdd) ->
%% 	ok.
	NowTime = util:unixtime(),
	Diff = NowTime - F5Time,
	%%小怪
	IsLMon = lists:member(MonId, [43101, 43102, 43103]),
	%%boss级怪物1
	IsBossOne = MonId =:= 43104,
	%%boss级怪物2
	IsBossTwo = MonId =:= 43105,
	Time =
		if
			IsLMon =:= true ->%%小怪
				120;
			IsBossOne =:= true ->%%boss级怪物1
				300;
			IsBossTwo =:= true ->%%boss级怪物2
				300;
			true ->
				9999999999
		end,
%% 	?DEBUG("NowTime:~p, F5Time:~p, Diff:~p", [NowTime, F5Time, Diff]),
	case Diff =< Time of
		true ->
			case lists:keyfind(MonId, 1, MonMpAdd) of
				false ->
					Add = 1,
					add_mon_mpadd(MonId),
					[{MonId, Add}|MonMpAdd];
				{_MonId, OAdd} ->
					NAdd = OAdd+1,
					update_mon_mpadd(MonId),
					lists:keyreplace(MonId, 1, MonMpAdd, {MonId, NAdd})
			end;
		false ->
			MonMpAdd
	end.
%%添加一条新的神魔乱斗中怪物的血量和攻击增量级数
add_mon_mpadd(MonId) ->
	db_agent:insert_mon_warfare(MonId).
%% 获取最新的神魔乱斗中怪物的血量和攻击增量级数
update_mon_mpadd(MonId) ->
	ValueList = [{add, 1, add}],
	WhereList = [{mon_id, MonId}],
	db_agent:update_mon_warfare(ValueList, WhereList).

give_pluto_first(KillMems, Attacks) ->
	%%获取伤害值前十名的人名列表
	{SortAttacks, _NList} = sort_player_attacks(Attacks),
	{IsOk, Attack, NewKillMems} = get_attack_pluto(fail, KillMems, SortAttacks, #k_p{}),
	case IsOk of
		ok ->
			{GM,KM} = give_pluto(4, NewKillMems),%%已经给了一个名额，所以只有4个了
			{[Attack|GM], [Attack|KM]};
		fail ->
			give_pluto(5, KillMems)%%没给过名额，所以全部一次性的给5个
	end.
get_attack_pluto(ok, KillMems, _Attacks, AttPluto) ->
	{ok, AttPluto, KillMems};
get_attack_pluto(fail, KillMems, [], _OAttPluto) ->
	{fail, _OAttPluto, KillMems};
get_attack_pluto(_IsOk, KillMems, [Attack|Rest], _OAttPluto) ->
	{Pid, _PName, _AttNum} =  Attack,
	case lists:keyfind(Pid, 1, KillMems) of
		false ->
			case lib_player:get_player_pid(Pid) of
				[] ->
					get_attack_pluto(fail, KillMems, Rest, _OAttPluto);
				PPid when is_pid(PPid) ->
					case catch(gen_server:call(PPid, {'PLAYER', [nickname,level,realm,career,sex,guild_id,guild_name]})) of
						[PName, PLv, Realm, Career, Sex, Gid, GName] ->
							AttPluto = #k_p{id = Pid,			%%玩家Id
											name = PName,	%%姓名
											lv = PLv,		%%等级
											realm = Realm,		%%部落
											career = Career,		%%职业
											sex = Sex,			%%性别
											gid = Gid,			%%氏族Id
											gname	= GName,		%%氏族名字
											pid = PPid	%%玩家进程Pid
										   },
							NKillMems = lists:keydelete(Pid, 1, KillMems),
							get_attack_pluto(ok, NKillMems, Rest, AttPluto);
						_ ->
							get_attack_pluto(fail, KillMems, Rest, _OAttPluto)
					end;
				_Other ->
					get_attack_pluto(fail, KillMems, Rest, _OAttPluto)
			end;
		{_Pid, PName, PLv, Realm, Career, Sex, Gid, GName, PPid} ->
			AttPluto = #k_p{id = Pid,			%%玩家Id
							name = PName,	%%姓名
							lv = PLv,		%%等级
							realm = Realm,		%%部落
							career = Career,		%%职业
							sex = Sex,			%%性别
							gid = Gid,			%%氏族Id
							gname	= GName,		%%氏族名字
							pid = PPid	%%玩家进程Pid
						   },
			NKillMems = lists:keydelete(Pid, 1, KillMems),
			get_attack_pluto(ok, NKillMems, Rest, AttPluto)
	end.				
					
	
%% PlutoNum的值直能是4或者5，不能是其他值，谨慎！
give_pluto(PlutoNum, KillMems) ->
	KM = 
		lists:map(fun(Elem) ->
						  {Pid, PName, PLv, Realm, Career, Sex, Gid, GName, PPid} = Elem, 
						   #k_p{id = Pid,			%%玩家Id
								name = PName,	%%姓名
								lv = PLv,		%%等级
								realm = Realm,		%%部落
								career = Career,		%%职业
								sex = Sex,			%%性别
								gid = Gid,			%%氏族Id
								gname	= GName,		%%氏族名字
								pid = PPid	%%玩家进程Pid
							   }
				  end, KillMems),
	Len = length(KM),
	if
		Len =< PlutoNum ->
			{KM, KM};
		true ->
			case PlutoNum of
				4 ->%%已经给了一个名额，所以只有4个了
					One = util:rand(1,Len),
					Two = ((One+1) rem Len)+1,
					Three = ((One+2) rem Len)+1,
					Four = ((One+3) rem Len)+1,
					GM = [lists:nth(One, KM),lists:nth(Two, KM),lists:nth(Three, KM),lists:nth(Four, KM)],
					{GM,KM};
				5 ->%%没给过名额，所以全部一次性的给5个
					One = util:rand(1,Len),
					Two = ((One+1) rem Len)+1,
					Three = ((One+2) rem Len)+1,
					Four = ((One+3) rem Len)+1,
					Five = ((One+4) rem Len)+1,
					GM = [lists:nth(One, KM),lists:nth(Two, KM),lists:nth(Three, KM),lists:nth(Four, KM),lists:nth(Five, KM)],
					{GM,KM}
			end
	end.
		

%%向客户端通知冥王之灵的新的拥有者
send_pluto_pinfo(Plutos, RTime) ->
	PlutoNames = [Elem#k_p.name|| Elem <- Plutos],
	{ok, BinData39103} = pt_39:write(39103, [RTime, PlutoNames]),
	%%场景广播
	spawn(fun() -> mod_scene_agent:send_to_scene(?WARFARE_SCENE_ID, BinData39103) end).


travel_give_plutos([], DPLutos) ->
	DPLutos;
travel_give_plutos(KP, DPLutos) ->
	RN = util:rand(1,length(KP)),
	Elem = lists:nth(RN, KP),
	NKP = lists:keydelete(Elem#k_p.id, #k_p.id, KP),
	case lists:keyfind(Elem#k_p.id, #k_p.id, DPLutos) of
		false ->
			case (catch gen_server:call(Elem#k_p.pid, {'GOT_WARFARE_PLUTO'})) of
				{'EXIT', Info} ->
					?WARNING_MSG("PLUTO_ADMIN_CHANGED fail because of ~p",[Info]),
					travel_give_plutos(NKP, DPLutos);
				{HadPluto, Param} ->
					case HadPluto of
						0 ->%%死亡了或者不在这个场景，不给了
							travel_give_plutos(NKP, DPLutos);
						1 ->%%呵呵，没有的，现在拿到了
							{NPid, NPName, NLv, NRealm, NCareer, NSex, NGid, NGName, NPPid} = Param,
							%%场景广播
%% 							{Gid, GName, PName}
							lib_warfare:world_brodcast(8, {NGid, NGName, NPName}),
							NPluto = #k_p{id = NPid,			%%玩家Id
									   name = NPName,		%%姓名
									   lv = NLv,
									   realm = NRealm,		%%部落
									   career = NCareer,		%%职业
									   sex = NSex,			%%性别
									   gid = NGid,			%%氏族Id
									   gname	= NGName,		%%氏族名字
									   pid = NPPid	%%玩家进程Pid
									  },
							NPlutos = [NPluto|DPLutos],
							travel_give_plutos([], NPlutos);
						2 ->
							{NPid, NPName, NLv, NRealm, NCareer, NSex, NGid, NGName, NPPid} = Param,
							%%场景广播
%% 							{Gid, GName, PName}
							lib_warfare:world_brodcast(8, {NGid, NGName, NPName}),
							NPluto = #k_p{id = NPid,			%%玩家Id
									   name = NPName,		%%姓名
									   lv = NLv,
									   realm = NRealm,		%%部落
									   career = NCareer,		%%职业
									   sex = NSex,			%%性别
									   gid = NGid,			%%氏族Id
									   gname	= NGName,		%%氏族名字
									   pid = NPPid	%%玩家进程Pid
									  },
							NPlutos = [NPluto|DPLutos],
							travel_give_plutos([], NPlutos)
					end
			end;
		_ ->
			travel_give_plutos(NKP, DPLutos)
	end.
	
%%判断是否需要开启伤害值统计,并计算相关的初始化数据
check_attack_count(F5State, MonId, MonAdd) ->
	case MonId =:= 43104 of
		true ->%%第一个boss出来了
			case data_agent:mon_get(MonId) of
				[] ->
					F5State;
				Mon39104 ->
					case data_agent:mon_get(43105) of
						[] ->
							F5State;
						Mon39105 ->
							MonAdd43104 = 
								case lists:keyfind(43104, 1, MonAdd) of
									false ->
										0;
									{_MonId43104, Add43104} ->
										Add43104
								end,
							MonAdd43105 = 
								case lists:keyfind(43105, 1, MonAdd) of
									false ->
										0;
									{_MonId43105, Add43105} ->
										Add43105
								end,
							AddHp43104 = erlang:trunc(?BOSS_ADD_HP*MonAdd43104),
							AddHp43105 = erlang:trunc(?BOSS_ADD_HP*MonAdd43105),
							%%计算总的血量
							HpSum = Mon39104#ets_mon.hp_lim + Mon39105#ets_mon.hp_lim + AddHp43104 + AddHp43105,	
							%%初始化伤害列表, {是否要计算伤害(1:计算伤害,0:不计算了),总伤害值(伤害基数), 伤害成员了列表}
							Attack = {1, HpSum, []},%%设置为1
							%%广播
							%%第一次广播，空数据
							broadcast_player_attacks(HpSum, []),
							%%开启刷新玩家伤害值定时器
							erlang:send_after(?REFLESH_ATTACK_TIMESTAMP, self(), {'REFLESH_ATTACK_LIST'}),
							F5State#state{attack = Attack}
					end
			end;
		false ->
			F5State
	end.
%%排序并且获得前N名的数据
sort_player_attacks(List) ->
	NList = 
		lists:sort(fun(A, B) ->
						   {_AId,_AName, AAtt} = A,
						   {_BId,_BName, BAtt} = B,
						   AAtt >= BAtt
				   end, List),
	SubList = lists:sublist(NList, ?ATTACK_GROUP_NUM),
	{SubList, NList}.
%%广播伤害列表
broadcast_player_attacks(AttSum, SubList) ->
	{ok, BinData39105} = pt_39:write(39105, [AttSum, SubList]),
	%%场景广播
	spawn(fun() -> mod_scene_agent:send_to_scene(?WARFARE_SCENE_ID, BinData39105) end).

%%获取进程状态信息
get_warfare_mon_info() ->
	case mod_warfare_mon:get_warfare_mon() of
		{ok, Pid} ->
			gen_server:cast(Pid, {'WARFARE_MON_INFO'});
		_ ->
			io:format("OMG WARFARE_SCENE the process is down", [])
	end.

%%产生KeyMax个相应的绑定铜坐标
make_random_bcoin_coord(0, Result) ->
	Result;
make_random_bcoin_coord(Key, Result)->
	[XMin, XMax] = ?BCOIN_X_LIMIT,
	X = util:rand(XMin, XMax),
	[YMin, YMax] = ?BCOIN_Y_LIMIT,
	Y = util:rand(YMin, YMax),
	NResult = [{Key, 0, {X, Y}}|Result],
	make_random_bcoin_coord(Key-1, NResult).
	