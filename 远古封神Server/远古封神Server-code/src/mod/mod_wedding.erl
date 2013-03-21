%%% -------------------------------------------------------------------
%%% Author  : ZhangChao
%%% Description :
%%%婚宴进程
%%% Created : 2011-11-29
%%% -------------------------------------------------------------------
-module(mod_wedding).
-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%% --------------------------------------------------------------------
%% External exports
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-compile(export_all).
-record(state, {
				is_wedding = 0,		 %%婚宴是否正在举办,0此刻没有举办的婚宴，大于0正在举办的婚宴ID
				wedding = undefined, %%正在进行的婚宴
				bt = 0,              %%0未拜堂，1已拜堂
				before_3 = 0, 			 %%前三分钟开始的广播  ，0未广播，1已广播
				before_1 = 0			 %%前一分钟的广播，0未广播，1已广播
				}).

-define(LOVE_WALL_AWARD_TIME, 86400).		%%表白奖励的时间戳
%% -define(LOVE_WALL_AWARD_TIME, 21*3600+45*60).		%%表白奖励的时间戳(测试用)
%% ====================================================================
%% External functions
%% ====================================================================

start_link() ->      %% 启动服务
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%动态加载婚宴处理进程 
get_mod_wedding_pid() ->
	ProcessName = mod_wedding_process,
	case misc:whereis_name({global, ProcessName}) of
        Pid when is_pid(Pid) ->
            case misc:is_process_alive(Pid) of
                true ->
                    Pid;
                false -> 
                    start_mod_wedding(ProcessName)
            end;
        _ ->
            start_mod_wedding(ProcessName)
	end.

%%启动婚宴模块 (加锁保证全局唯一)
start_mod_wedding(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> 
						Pid;
					false -> 
						start_wedding()
				end;
			_ ->
				start_wedding()
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%启动婚宴模块
start_wedding() ->
	case supervisor:start_child(
       		yg_server_sup, {mod_wedding,
            		{mod_wedding, start_link,[]},
               		permanent, 10000, supervisor, [mod_wedding]}) of
		{ok, Pid} ->
				timer:sleep(1000),
				Pid;
		_Other ->
				undefined
	end.

%%此方法只供init/1调用
init_wedding() ->
	Now = util:unixtime(),
	TodaySecond = util:get_today_current_second(),
%% 	{Today,_Next} = util:get_midnight_seconds(Now),
	%%先处理已过时但未能举办的婚宴(do_wedding = 0)——补偿玩家
	case db_agent:get_expire_wedding(Now) of
		[] -> skip;
		ExList ->
			%%?DEBUG("lIST = ~p",[ExList]),
			%%根据婚宴类型，退回对应的元宝给男方
			F = fun(Winfo) ->
						Gold = Winfo#ets_wedding.gold,
						Time = Winfo#ets_wedding.wedding_start,
						BoyNameList = [Winfo#ets_wedding.boy_name],
						GirlNameList = [Winfo#ets_wedding.girl_name],
						IsExpire = 
							case util:is_same_date(Winfo#ets_wedding.book_time, Now) of
								true -> TodaySecond > Time ;
								false -> true
							end,	
						case IsExpire of
							true ->%%赔偿玩家玩家
								lib_marry:send_mail_to_pay(Gold,BoyNameList,GirlNameList,Winfo#ets_wedding.id);
							false ->
								skip
						end,
						%%通知已被邀请参加婚宴的玩家
						%%男方邀请的玩家
						BoyInvites = 
							case util:string_to_term(tool:to_list(Winfo#ets_wedding.boy_invite)) of
								  undefined ->
									  [];
								  BoyList ->
									  BoyList
							  end,
						GirlInvites = 
							case util:string_to_term(tool:to_list(Winfo#ets_wedding.girl_invite)) of
								undefined ->
									[];
								GirlList ->
									GirlList
							end,
						Invites = BoyInvites ++ GirlInvites,
						lib_marry:send_mail_to_invites(Invites,Winfo#ets_wedding.boy_name,Winfo#ets_wedding.girl_name)
				end,
			%%清除婚宴图标
			lib_marry:notice_all_clear(),
			[F(list_to_tuple([ets_wedding | Winfo])) || Winfo <- ExList]
	end,
	%%加载今天还未举办的婚宴
	%%新建ETS
	ets:new(?ETS_WEDDING, [named_table, public, set, {keypos, #ets_wedding.id},?ETSRC, ?ETSWC]),
	ets:new(?WEDDING_PLAYER,[named_table, public, set, {keypos, #ets_wedding_player.player_id},?ETSRC, ?ETSWC]),
	%%情人节活动，表白表
	ets:new(?ETS_LOVEDAY,[named_table, public, set, {keypos, #ets_loveday.id},?ETSRC, ?ETSWC]),
	%%情人节活动，投票表
	ets:new(?ETS_VOTERS, [named_table, public, set, {keypos, #ets_voters.playerid},?ETSRC, ?ETSWC]),
%% 	%%加载情人节活动投票数据
%% 	lib_activities:get_all_love_data(),
	case db_agent:get_today_wedding(TodaySecond) of
		[]->
			skip;
		DbWeddings when is_list(DbWeddings) ->
			Weddings = [list_to_tuple([ets_wedding | W]) || W <- DbWeddings],
			Fun = fun(Wedding) ->
						  %%处理已邀请的
						  BoyInvites = 
							  case util:string_to_term(tool:to_list(Wedding#ets_wedding.boy_invite)) of
								  undefined ->
									  [];
								  BoyList ->
									  BoyList
							  end,
						  GirlInvites = 
							  case util:string_to_term(tool:to_list(Wedding#ets_wedding.girl_invite)) of
								  undefined ->
									  [];
								  GirlList ->
									  GirlList
							  end,
						  ets:insert(?ETS_WEDDING, Wedding#ets_wedding{boy_invite = BoyInvites, girl_invite = GirlInvites})
				  end,
			[Fun(W) || W <- Weddings,is_record(W,ets_wedding)]
	end.

%%婚宴广播及通知客户端开启入口
broadcast_wedding_msg(S,E,Wedding,TodaySecond,State) ->
	{Message,State1} = 
			%%3分钟前广播
		if TodaySecond >= (S-180) andalso TodaySecond =< (S-170) andalso State#state.before_3 =:= 0 -> 
			   Boy = Wedding#ets_wedding.boy_name,
			   Girl = Wedding#ets_wedding.girl_name,
			   {BoyColor,GirlColor} = lib_marry:realm_color(Wedding#ets_wedding.boy_id,Wedding#ets_wedding.girl_id),
			   Msg = io_lib:format("<font color='~s'>~s</font>与<font color='~s'>~s</font>的婚礼将于3分钟后举行,请被邀请的玩家准备进场",
											 [BoyColor,Boy,GirlColor,Girl]),
			   
			   {Msg,State#state{before_3 = 1}};
		   %%1分钟前广播
		   TodaySecond >= (S - 60) andalso TodaySecond =< (S - 50) andalso State#state.before_1 =:= 0 ->
			   Boy = Wedding#ets_wedding.boy_name,
			   Girl = Wedding#ets_wedding.girl_name,
			   {BoyColor,GirlColor} = lib_marry:realm_color(Wedding#ets_wedding.boy_id,Wedding#ets_wedding.girl_id),
			   Msg = io_lib:format("<font color='~s'>~s</font>与<font color='~s'>~s</font>的婚礼将于1分钟后举行,请被邀请的玩家准备进场",
											 [BoyColor,Boy,GirlColor,Girl]),
			   {Msg,State#state{before_1 = 1}};
		   %%婚宴开启
		   TodaySecond >= S andalso (TodaySecond - S) =< 10 andalso State#state.is_wedding =:= 0 ->	%%确保婚宴入口正式开放
			   lib_marry:notice_all(Wedding),
			   erlang:send_after((E-S)*1000, self(), {'WEDDING_END', ?WEDDING_SCENE_ID}),
			   %%发放烟花
			   lib_marry:send_fireworks(Wedding),
			   {[],State#state{is_wedding = Wedding#ets_wedding.id, wedding = Wedding}};
		   true ->
			   {[],State}
		end,
	case Message of
		[] -> 
			State1;
		_ ->
			lib_chat:broadcast_sys_msg(2, Message),
			State1
	end.
%% ====================================================================
%% Server functions
%% ====================================================================

init([]) ->
	process_flag(trap_exit, true),
	ProcessName = mod_wedding_process,		%%
 	case misc:register(unique, ProcessName, self())of
		yes ->
			lib_scene:copy_scene(?WEDDING_SCENE_ID, ?WEDDING_SCENE_ID),
			lib_scene:copy_scene(?WEDDING_LOVE_SCENE_ID, ?WEDDING_LOVE_SCENE_ID),%%洞房场景
			misc:write_monitor_pid(self(),?MODULE, {}),
			misc:write_system_info(self(), mod_wedding, {}),			
			%% 加载婚宴数据
			init_wedding(),
			%%启动时间检测	
			erlang:send_after(10, self(), {sys}),
			State = #state{is_wedding = 0},
			io:format("9.Init mod_wedding finish!!!!!!!!!!~n"),
			{ok, State};
		_ ->
			{stop,normal,#state{}}
	end.

%% --------------------------------------------------------------------
%% Function: handle_call/3
%% --------------------------------------------------------------------

%%查询提亲信息
handle_call({'PROPOSE_INFO',Sex,PlayerId}, _From, State) ->
	Reply = lib_marry:get_propose_info(Sex,PlayerId),
    {reply, Reply, State};

%%查询婚宴信息
handle_call({'QUERY_WEDDING_INFO',Sex,PlayerId}, _From, State) ->
	Reply =
		%%先判断能不能预订婚宴
		case lib_marry:check_can_book_wedding(Sex,PlayerId) of
			{fail,Error} ->
				%%?DEBUG("ERROR = ~p",[Error]),
				{fail,Error};
			{ok,_Res} ->
				Ms = ets:fun2ms(fun(W)-> W end),
				case ets:select(?ETS_WEDDING,Ms) of
					[] -> {ok,[]};
					Wlist ->{ok,Wlist}
				end	
		end,
	{reply, Reply, State};

%%是否预订了婚宴,并返回已邀请\好友列表
handle_call({'IS_BOOK_WEDDING',Player,FriendIds}, _From, State) ->
	{Can_send,ErrorCode,Rid,W} = 
		if Player#player.scene =:= ?WEDDING_SCENE_ID 
						 orelse Player#player.scene =:= ?WEDDING_LOVE_SCENE_ID ->
			   #state{wedding = Wedding} = State,
			   case Wedding =:= undefined of
				   true ->
					   {false,4,0,undefined};
				   false ->
					   if Player#player.sex =:= 1 ->
							  {Wedding#ets_wedding.boy_id =:= Player#player.id,
							   1,
							   Wedding#ets_wedding.girl_id,
							   Wedding };
						  true ->
							  {Wedding#ets_wedding.girl_id =:= Player#player.id,
							   1,
							   Wedding#ets_wedding.boy_id,
							   Wedding }
					   end
			   end;
		   true ->
			   Ms = 
				   if Player#player.sex =:= 1 ->
						  ets:fun2ms(fun(W) when W#ets_wedding.boy_id =:= Player#player.id -> W end);
					  true ->
						  ets:fun2ms(fun(W) when W#ets_wedding.girl_id =:= Player#player.id -> W end)
				   end,
			   case ets:select(?ETS_WEDDING,Ms) of
				   [] -> {false,2,0,undefined};
				   [Winfo | _O] ->
					    Rid2 =
							if Player#player.sex =:= 1 ->
								   Winfo#ets_wedding.girl_id;
							   true ->
								   Winfo#ets_wedding.boy_id
							end,
						{true,1,Rid2,Winfo}
			   end
		end,
	Reply =
	case Can_send of
		false ->
			{false,ErrorCode}; 
		true->
			case W of
				undefined ->
					{false,2}; %%没有预订婚宴
				_ ->
						Friends =							
							case db_agent:get_player_mult_properties([lv,nickname,online_flag],FriendIds) of
								[] -> [];
								Infos -> [{PlayerId,[_Name,_Lv,_Online]} || {PlayerId,[_Name,_Lv,_Online]} <- Infos, PlayerId =/= Rid ]
							end,
						SingleMax = lib_marry:get_wedding_invites_max(W,Player#player.sex),
						Invites = W#ets_wedding.boy_invite ++ W#ets_wedding.girl_invite,
						Invited_num = 
							case Player#player.sex of
								1 ->
									length(W#ets_wedding.boy_invite);
								_ ->
									length(W#ets_wedding.girl_invite)
							end,
						{true,Invites,Friends,SingleMax,Invited_num}
			end
	end,	
	{reply, Reply, State};

%%进入婚宴前的判断（只做婚宴的相关判断）
handle_call({'CAN_ENTER_WEDDING',PlayerId}, _From, State) ->
	#state{wedding = W} = State,
	Reply =
	if State#state.is_wedding =:= 0 ->
		   {false,2};%%婚宴已结束
	   true ->
		   if PlayerId =:= W#ets_wedding.boy_id ->
				  {true,100,W#ets_wedding.wedding_type}; %%新郎模型
			  PlayerId =:= W#ets_wedding.girl_id ->
				  {true,101,W#ets_wedding.wedding_type}; %%新娘模型
			  true ->
				   Invites = W#ets_wedding.boy_invite ++ W#ets_wedding.girl_invite,
				   case lists:member(PlayerId,Invites) of
					   false -> {false,4};%%不在邀请之列
					   true ->
						   {_Num,S,E} = lists:keyfind(W#ets_wedding.wedding_num, 1, lib_marry:get_wedding_time()),
						   TodaySec = util:get_today_current_second(),
						   if TodaySec < S ->
								  {false,3};%%婚宴未开始
							  TodaySec > E ->
								  {false,2};
							  true ->
								  {true,0,W#ets_wedding.wedding_type}
						   end
				   end
		   end
	end,		
	{reply, Reply, State};

%%判断是否新郎新娘
handle_call({'IS_COUPLE',Player},_From,State) ->
	Reply = is_inner_couple(Player,State),
	{reply, Reply, State};

%%检查双方是否已婚
handle_call({'IS_MARRY',BoyId,GirlId},_From,State) ->
	Ms1 = ets:fun2ms(fun(M1) when M1#ets_marry.boy_id =:= BoyId -> M1 end),
	Ms2 = ets:fun2ms(fun(M2) when M2#ets_marry.girl_id =:= GirlId -> M2 end),
	Bres = 
		case ets:select(?ETS_MARRY, Ms1) of
			[] -> 0;
			_ -> 1
		end,
	Gres = 
		case ets:select(?ETS_MARRY, Ms2) of
			[] -> 0;
			_ -> 1
		end,
	P_Boy_res = 
		case ets:lookup(ets_propose_info,BoyId) of
			[] ->0;
			_ -> 1
		end,
	Ms = ets:fun2ms(fun(P) when P#ets_propose_info.girl_id =:= GirlId -> P end),
	P_Girl_res =
		case ets:select(ets_propose_info, Ms) of
			[]->0;
			_->1
		end,
	Reply = 
		if Bres =:= 0 andalso Gres =:= 0 ->
			   {ok,suc};
		   Bres =:= 1 ->
			   {fail,9};
		   Gres =:= 1 ->
			   {fail,8};
		   P_Boy_res =:= 1 ->
			   {fail,12};
		   P_Girl_res =:= 1 ->
			   {fail,13};
		   true ->
			   {fail,3}
		end,
	{reply, Reply, State};

%%婚宴是否在举办中
handle_call({'IS_WEDDING_ON'},_From,State) ->
	#state{wedding = Wedding, is_wedding = IsWedding} = State,
	Reply = 
		case IsWedding of
			0 ->
				{false,0};
			_ ->
				{true,Wedding}
		end,
	{reply, Reply, State};

%%是否已经拜堂
handle_call({'IS_BT'},_From,State) ->
	Reply = State#state.bt =:= 1,
	{reply, Reply, State};
				
handle_call(_Request, _From, State) ->
	{reply, State, State}.
%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% --------------------------------------------------------------------

%%预订婚宴
handle_cast({'BOOK_WEDDING',Player, Marry, Type, Num}, State) ->
	%%判断条件是否满足
	case lib_marry:check_wedding(Player, Marry,Type, Num) of
		{false,Code} ->
			{ok,BinData} = pt_48:write(48004,Code);
		{true,Marry} ->
			%%更新DB与ETS
			lib_marry:do_wedding(Marry,Type,Num,Player),
			{ok,BinData} = pt_48:write(48004,1)		
	end,	
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	{noreply, State};

%%发送喜帖
handle_cast({'SEND_INV',Ids,Player}, State) ->
	Ms = 
		if Player#player.sex =:= 1 ->
			   ets:fun2ms(fun(M1) when M1#ets_wedding.boy_id =:= Player#player.id -> M1 end);
		   true->
			   ets:fun2ms(fun(M2) when M2#ets_wedding.girl_id =:= Player#player.id -> M2 end)
		end,
	{Can_send,Code,Send_ids,W} = 
		case ets:select(?ETS_WEDDING,Ms) of
			[]->
				{false,3,[],undefined};%%未预定婚宴
			[Winfo|_R] ->
				Max_Num = lib_marry:get_wedding_invites_max(Winfo,Player#player.sex),
				OldInvs = 
					if Player#player.sex =:= 1 ->
						   length(Winfo#ets_wedding.boy_invite);
					   true ->
						   length(Winfo#ets_wedding.girl_invite)
					end,
				ReqInvs = length(Ids),
				if OldInvs >= Max_Num ->
					   {false,2,[],undefined};%%已邀请人数达到上限
				   true ->
					   if (OldInvs+ReqInvs) > Max_Num ->
							  {false,5,[],undefined}; %%选择的人数过多
						  true ->
							  if OldInvs =:= 0 ->
									 {true,0,Ids,Winfo};
								 true ->
									 OldIds = Winfo#ets_wedding.boy_invite ++ Winfo#ets_wedding.girl_invite,
									 Fun = fun(Id) ->
												   case lists:member(Id,OldIds) of
													   true -> skip;
													   false ->
														   Id
												   end
										   end,
									 Ids2 = [Fun(Id) || Id <- Ids],
									 Uids = lists:filter(fun(Id) -> Id =/= skip end, Ids2),
									 {true,0,Uids,Winfo}
							  end
					   end
				end
		end,
	State1 = 
		case Can_send of
			false ->
				{ok,BinData2} = pt_48:write(48006,Code),
				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData2),
				State;
			true ->
				TimeStr = lib_marry:get_date_str(W#ets_wedding.wedding_start),				
				DbData = db_agent:get_player_mult_properties([nickname],Send_ids),
				NickNames = [Nick || {_Id,[Nick]} <- DbData], 
				Title = io_lib:format("婚宴邀请",[]),				
				{Content,NewRecord} = 
					if Player#player.sex =:= 1 ->
						  {	io_lib:format("~s邀请你参加他和~s将于~s举办的婚宴",[Player#player.nickname, W#ets_wedding.girl_name, TimeStr]),
							W#ets_wedding{ boy_invite = lists:append(Send_ids,W#ets_wedding.boy_invite)}
						  };
					   true ->
						   { io_lib:format("~s邀请你参加她和~s将于~s举办的婚宴",[Player#player.nickname,W#ets_wedding.boy_name,TimeStr]),
							 W#ets_wedding{ girl_invite = lists:append(Send_ids,W#ets_wedding.girl_invite)}
						   }
					end,
				Mfun = fun(Nstr,GoodsId,Num) ->
							   mod_mail:send_sys_mail([Nstr], Title, Content, 0, GoodsId, Num, 0, 0, 0)
					   end,
				case State#state.wedding of
					undefined ->
						[Mfun(Name,0,0) || Name <- NickNames];
					_ ->
						%%必须是自己的婚宴正在举办时，所发的请帖才包含烟花
						if Player#player.id =:= State#state.wedding#ets_wedding.boy_id
							 orelse Player#player.id =:= State#state.wedding#ets_wedding.girl_id ->
							   %%要即时发烟花
							   {GoodsId,Num} = lib_marry:get_fireworks_type(State#state.wedding#ets_wedding.wedding_type),
							   [Mfun(Name,GoodsId,Num) || Name <- NickNames];
						   true ->
							   [Mfun(Name,0,0) || Name <- NickNames]
						end
				end,
				if Player#player.sex =:= 1 ->
					   Idterm = util:term_to_string(NewRecord#ets_wedding.boy_invite),
					   db_agent:update_inv_ids(boy_invite,Idterm,W#ets_wedding.id);
				   true ->
					    Idterm = util:term_to_string(NewRecord#ets_wedding.girl_invite),
					    db_agent:update_inv_ids(girl_invite,Idterm,W#ets_wedding.id)
				end,
				ets:insert(?ETS_WEDDING, NewRecord),
				{ok,BinData1} = pt_48:write(48006,1),
				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData1),
				Wg = State#state.wedding,
				if State#state.is_wedding > 0  andalso (Player#player.id =:= Wg#ets_wedding.boy_id orelse 
																								Player#player.id =:= Wg#ets_wedding.girl_id )->
					   State#state{wedding = NewRecord};
				   true ->
					   State
				end	
		end,
	{noreply, State1};

%%购买喜帖
handle_cast({'ADD_INVITES',NeedGold,Player}, State) ->
	Ms = 
		case Player#player.sex of
			1 -> ets:fun2ms(fun(Wi) when Wi#ets_wedding.boy_id =:= Player#player.id -> Wi end );
			2 -> ets:fun2ms(fun(Wi) when Wi#ets_wedding.girl_id =:= Player#player.id -> Wi end )
		end,
	State1 = 
	case ets:select(?ETS_WEDDING,Ms) of
				[] -> State;
				[Winfo|_Rets] ->
					{NewCost, NewInfo, Field} =
						if Player#player.sex =:= 1 ->
							   Cost = Winfo#ets_wedding.boy_cost + NeedGold,
							   {Cost,Winfo#ets_wedding{boy_cost = Cost},boy_cost};
						   true ->
							   Cost = Winfo#ets_wedding.girl_cost + NeedGold,
							   {Cost,Winfo#ets_wedding{girl_cost = Cost},girl_cost}
						end,
					ets:insert(?ETS_WEDDING, NewInfo),
					db_agent:update_invite_cost(NewCost,Winfo#ets_wedding.id,Field),
					InvNum = lib_marry:get_wedding_invites_max(NewInfo,Player#player.sex),
					{ok,BinData} = pt_48:write(48007,{1,InvNum}),
					 %%购买喜帖日志
					spawn(fun()->db_agent:log_wedding_pay_inv(NewInfo#ets_wedding.boy_name,NewInfo#ets_wedding.girl_name,NewInfo#ets_wedding.boy_cost,NewInfo#ets_wedding.girl_cost)end),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					if State#state.is_wedding > 0 ->
						   W = State#state.wedding,
						   case W#ets_wedding.boy_id =:= Player#player.id orelse W#ets_wedding.girl_id =:= Player#player.id of
							   true -> 
								   State#state{wedding = NewInfo};
							   false ->
								   State
						   end;
					   true ->
						   State
					end
	end,
	{noreply, State1};	

%%新郎新娘进入婚宴，模型改变
handle_cast({'ENTER_WEDDING',Player},State) ->
	R = #ets_wedding_player{player_id = Player#player.id},
	%%通知自己，模型改变
	lib_player:send_player_attribute(Player,2),
	%%通知场景，模型改变
	{ok,Data12066} = pt_12:write(12066,[Player#player.id,Player#player.other#player_other.turned]),
	mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, Data12066),
	ets:insert(?WEDDING_PLAYER, R),
	{noreply, State};

%%玩家离开婚宴
handle_cast({'PLAYER_LEAVE',PlayerId},State) ->
	catch ets:delete(?WEDDING_PLAYER, PlayerId),
	{noreply, State};

%%发送玩家的贺礼信息
handle_cast({'SEND_GIFTS',Coin,Gold,Bin,SenderId,SenderName},State) ->
	case ets:tab2list(?WEDDING_PLAYER) of
		[]->skip;
		Plist ->
			Fun = fun(P) ->					
						  lib_send:send_to_uid(P#ets_wedding_player.player_id, Bin)
				  end,
			[Fun(P) || P <- Plist]
	end,
	%%给新郎加钱
	#state{wedding = Wedding} = State,
	#ets_wedding{boy_id = Bid} = Wedding,
	case lib_player:get_player_pid(Bid) of
		[] ->
			%%新郎不在线收不到贺礼
			skip;
		Pid ->
			%%交给新郎玩家自己进程，增加铜币、元宝
			%%内存操作,更新结婚记录中收到的铜币、元宝
			Pid ! {'ADD_WEDDING_GIFT',Coin,Gold,Wedding#ets_wedding.marry_id}
	end,
	%%DB操作,更新结婚记录中收到的铜币、元宝
	spawn(fun()-> db_agent:update_rec(Gold,Coin,Wedding#ets_wedding.marry_id)end),
	Now = util:unixtime(),	
	%%写贺礼日志
	spawn(fun()->db_agent:log_wedding_gift(SenderId,SenderName,Wedding#ets_wedding.boy_name,Now,Gold,Coin) end),
	{noreply,State};

%%拜堂
handle_cast({'REQUEST_WEDDINGS',Player},State) ->
	#state{ wedding = Wedding,is_wedding = IsWedding} = State,
	%%检测身份
	case IsWedding of
		0 ->
			skip;
		_->
			if Player#player.id =:=  Wedding#ets_wedding.boy_id orelse Player#player.id =:=  Wedding#ets_wedding.girl_id ->
				   Rid = 
					   if Player#player.sex =:= 1 ->
							  Wedding#ets_wedding.girl_id;
						  true ->
							  Wedding#ets_wedding.boy_id
					   end,
				   case ets:lookup(?WEDDING_PLAYER, Rid) of
					   []->
						   %%对方不在婚宴场景，失败，返回给发送方
						   {ok,BinData} = pt_48:write(48011,2),
						   lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
					   [Rinfo | _R] ->
						   case  State#state.bt =:= 1 of
							   true ->
								    {ok,BinData} = pt_48:write(48011,4),
									lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
							   false ->
								   %%成功发送，通知对方
								   {ok,BinData} = pt_48:write(48011,1),
								   lib_send:send_to_uid(Rinfo#ets_wedding_player.player_id, BinData)
						   end
				   end;
			   true ->
				   %%身份不符合拜堂
				   {ok,BinData} = pt_48:write(48011,3),
				   lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
			end
	end,				  
	{noreply, State};

%%拜堂的接受方选择:稍等
handle_cast({'BEGIN_WEDDINGS_WAIT',Player},State) ->
	#state{ wedding = Wedding} = State,
	Rid = 
		if Player#player.sex =:= 1 ->
			   Wedding#ets_wedding.girl_id;
		   true ->
			   Wedding#ets_wedding.boy_id
		end,
	case ets:lookup(?WEDDING_PLAYER, Rid) of
		[]->skip;
		[Rinfo | _R] ->
			%%通知对方：稍等
			{ok,BinData} = pt_48:write(48012,1),
			lib_send:send_to_uid(Rinfo#ets_wedding_player.player_id, BinData)
	end,
	{noreply, State};

%%拜堂的接受方选择:开始
handle_cast({'BEGIN_WEDDINGS_NOW',Player},State) ->
	#state{ wedding = Wedding} = State,
	%%是否在场景里
	case lib_marry:is_wedding_scene(Player#player.scene) of
		false ->
			{ok,BinData48013} = pt_48:write(48013,{2,0,<<>>,0,<<>>}),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData48013);
		true ->
			%%有没有在吃饭28
			case Player#player.carry_mark =/= 0 of
				true ->
					{ok,Bin3} = pt_48:write(48013,{3,0,<<>>,0,<<>>}),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin3);
				false ->
					Rid = 
						if Player#player.sex =:= 1 ->
							   Wedding#ets_wedding.girl_id;
						   true ->
							   Wedding#ets_wedding.boy_id
						end,
					case ets:lookup(?WEDDING_PLAYER,Rid) of
						[] ->
							{ok,Bin4} = pt_48:write(48013,{4,0,<<>>,0,<<>>}),%%对方不在场景
							lib_send:send_to_uid(Rid, Bin4);
						_ ->
							%%传送拜堂的接受方
							gen_server:cast(Player#player.other#player_other.pid,{'WEDDING_BEGIN_SEND'}),
							case lib_player:get_player_pid(Rid) of
								[] ->
									skip;
								Pid ->
									%%传送拜堂的请求方
									gen_server:cast(Pid,{'WEDDING_BEGIN_SEND'}),
									%%通知所有人，拜堂开始，场景内所有人开始观看拜堂
									{ok,BinData48013} = pt_48:write(48013,{1,Wedding#ets_wedding.boy_id,Wedding#ets_wedding.boy_name,Wedding#ets_wedding.girl_id,Wedding#ets_wedding.girl_name}),									
									case ets:tab2list(?WEDDING_PLAYER) of
										[]->skip;
										Plist ->
											Fun = fun(P) ->
														  lib_send:send_to_uid(P#ets_wedding_player.player_id, BinData48013)
												  end,
											[Fun(P) || P <- Plist]
									end
							end,
							%%把场景内其他玩家送到观看位置WEDDING_FORCE_SEND
							case ets:tab2list(?WEDDING_PLAYER) of
								[] -> skip;
								Pinfos ->
									Gun = fun(P) ->
												  if P#ets_wedding_player.player_id =/= Wedding#ets_wedding.boy_id andalso
																												P#ets_wedding_player.player_id =/= Wedding#ets_wedding.girl_id
													   ->
														 case lib_player:get_player_pid(P#ets_wedding_player.player_id) of
															 [] -> skip;
															 PPid ->
																 gen_server:cast(PPid, {'WEDDING_FORCE_SEND'})
														 end;
													 true ->
														 skip
												  end
										  end,
									[Gun(P) || P <- Pinfos]
							end
					end
			end
	end,
	{noreply,State#state{bt = 1}};
	   
handle_cast(_Msg, State) ->
	{noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% --------------------------------------------------------------------

%%负责循环检测时间，发送婚宴通知(开启婚宴场景入口)
handle_info({sys}, State) ->
	TodaySec = util:get_today_current_second(),
	Now = util:unixtime(),
%% 				   %%情人节活动，结束当日24点更新排行榜并且发送奖励    1329235200
%% 				   {_S,LoveEnd} = lib_activities:lovedays_time(),
%% 				   {_S2,SayEnd} = lib_activities:saylove_time(),
%% 				   %%提前更新排行榜
%% 				   case Now =:= (LoveEnd-60) orelse Now =:= (LoveEnd-60+1)  of
%% 					   true -> %%发消息给排行榜
%% 						   Rid = mod_rank:get_mod_rank_pid(),
%% 						   gen_server:cast(Rid, {'UPDATE_CHARM_RANK_NOW'});
%% 					   false ->
%% 						   skip
%% 				   end,			   
%% 				   case Now =:= LoveEnd orelse Now =:= (LoveEnd+1)  of
%% 					   true ->
%% 						   Rid2 = mod_rank:get_mod_rank_pid(),
%% 						   %%发消息给排行榜
%% 						   gen_server:cast(Rid2, {'UPDATE_CHARM_RANK_NOW'}),
%% 						   %%5秒后发奖励
%% 						   erlang:send_after(5000, self(), {'LOVEDAYS_CHARM_AWARD'});					   
%% 					   false ->
%% 						   skip
%% 				   end,
%% 	%% 白色情人节活动时间	
%% 	{WhiteStart, WhiteEnd} = lib_activities:whiteday_time(),
%% 	HasShow = get_white_day(),
%% 	case WhiteStart+10 < Now orelse Now =< WhiteEnd + 10 of
%% 		true ->
%% 			NowSec = util:get_today_current_second(),
%% 			case HasShow of
%% 				0 ->
%% %% 					?DEBUG("1111111", []),
%% 					case NowSec >= ?LOVE_WALL_AWARD_TIME-10 andalso NowSec =< ?LOVE_WALL_AWARD_TIME of
%% 						true ->
%% %% 							?DEBUG("333333333333", []),
%% 							%%最佳表白及其粉丝奖励
%% 							self()!{'LOVE_WINNER'},
%% 							put_white_day(1);
%% 						false ->
%% 							skip
%% 					end;
%% 				_ ->
%% %% 					?DEBUG("22222222", []),
%% 					case NowSec >= ?LOVE_WALL_AWARD_TIME-10 andalso NowSec =< ?LOVE_WALL_AWARD_TIME of
%% 						true ->
%% 							skip;
%% 						false ->
%% %% 							?DEBUG("444444444444", []),
%% 							put_white_day(0)
%% 					end
%% 			end;
%% 		false ->
%% 			put_white_day(0)
%% 	end,
	
	if State#state.is_wedding =:= 0 ->
		   %%最新的ETS
		   case ets:tab2list(?ETS_WEDDING) of
			   [] ->State1 = State;
			   TList ->
				   Fun = fun(W) ->
								 St = W#ets_wedding.wedding_start,
								 BookTime = W#ets_wedding.book_time,
								 case util:is_same_date(Now, BookTime) of
									 false ->
										 catch ets:delete(?ETS_WEDDING, W#ets_wedding.id),
										 skip;
									 true ->
										 if TodaySec < (St+20)->
												{W#ets_wedding.wedding_start,W};
											true ->
												skip
										 end
								 end
						 end,
				   RList = [Fun(T) || T <- TList],
				   Slist = lists:filter(fun(E) -> E=/=skip end, RList),
				   if length(Slist) =:= 0 ->
						  State1 = State;
					  true ->
						  %%获取婚宴开始时间最小的
						  {S,Wedding} = lists:min(Slist),
						  {Start,End} = 
							  case lists:keyfind(S, 2, lib_marry:get_wedding_time()) of
								  false ->
									  {0,0};
								  {_N,Begin,E} ->
									  {Begin,E}
							  end,
						  %%负责循环检测时间，发送婚宴通知(开启婚宴场景入口)
%% 						  ?DEBUG("Wedding = ~p",[Wedding]),					  
						  State1 =  broadcast_wedding_msg(Start,End,Wedding,TodaySec,State)
				   end
		   end;
	   true ->
		   State1 = State
	end,
	erlang:send_after(2000, self(), {sys}),
	{noreply, State1};

%%婚宴结束
handle_info({'WEDDING_END',SceneId}, State) ->
	#state{wedding = Wedding} = State,
	NewWedding = Wedding#ets_wedding{do_wedding = 1},
	ets:insert(?ETS_WEDDING, NewWedding),
	%%通知couple双方更新ets(设置ets_marry已举办过婚宴，并且广播夫妻关系在人物面板上)
	case lib_player:get_player_pid(NewWedding#ets_wedding.boy_id) of
		[] ->
			skip;
		Bpid ->
			Bpid ! {'end_do_marry',NewWedding#ets_wedding.girl_name,NewWedding#ets_wedding.marry_id}
	end,
	case lib_player:get_player_pid(NewWedding#ets_wedding.girl_id) of
		[] ->
			skip;
		Gpid ->
			Gpid ! {'end_do_marry',NewWedding#ets_wedding.boy_name,NewWedding#ets_wedding.marry_id}
	end,
	Title = "婚戒发放",
	Content = "亲爱的玩家,你们的真情感动了月老,送你戒指一枚!",
	GoodsTypeId = lib_marry:get_ring_by_type(Wedding#ets_wedding.wedding_type),
	mod_mail:send_sys_mail([Wedding#ets_wedding.boy_name], Title, Content, 0, GoodsTypeId, 1, 0, 0, 0),
	mod_mail:send_sys_mail([Wedding#ets_wedding.girl_name], Title, Content, 0, GoodsTypeId, 1, 0, 0, 0),
	db_agent:do_wedding_end(Wedding#ets_wedding.marry_id,Wedding#ets_wedding.id),
	db_agent:update_cuple_name(NewWedding#ets_wedding.girl_name,NewWedding#ets_wedding.boy_id),
	db_agent:update_cuple_name(NewWedding#ets_wedding.boy_name,NewWedding#ets_wedding.girl_id),
	mod_scene_agent:send_to_scene_for_event(SceneId, {'SEND_OUT_WEDDING'}),
	%%洞房场景也强制送出玩家
	mod_scene_agent:send_to_scene_for_event(?WEDDING_LOVE_SCENE_ID, {'SEND_OUT_WEDDING'}),
	lib_marry:send_mail_to_boy(Wedding),
	spawn(fun()->db_agent:log_update_wedding(Wedding#ets_wedding.id) end),
	%%清除客户端图标
	lib_marry:notice_all_clear(),
	%%情人节活动，送巧克力
	case lib_activities:is_lovedays_time(util:unixtime()) of
		true ->
			lib_activities:send_to_marry(Wedding#ets_wedding.girl_name),
			lib_activities:send_to_marry(Wedding#ets_wedding.boy_name);
		false ->
			skip
	end,
	erlang:send_after(90000, self(), {'END_WEDDING_PRO'}),%%开始清理场景的定时器(90秒的延时)
	{noreply, State#state{is_wedding=0, wedding=undefined, bt = 0, before_3 = 0, before_1 = 0}};

%%清理婚宴场景的player
handle_info({'END_WEDDING_PRO'}, State) ->
	catch ets:delete_all_objects(?WEDDING_PLAYER),
	{noreply, State};

%%查询婚宴信息
handle_info({'QUERY_WEDDING_INFO',Sex,PlayerId}, State) ->
	%%先判断能不能预订婚宴
	case lib_marry:check_can_book_wedding(Sex,PlayerId) of
		{fail,Error} ->
			%%?DEBUG("ERROR = ~p",[Error]),
			{ok,BinData} = pt_48:write(48003,{Error,[]});
		{ok,_Res} ->
			Wlist = 
				case ets:tab2list(?ETS_WEDDING) of
					[] -> 
						[];
					List ->
						List
				end,
			TodaySec = util:get_today_current_second(),
			F = fun({_WNum,Start,_End}) -> Start < TodaySec end,
			F2 = fun({WNum,Start,End}) -> {WNum,1,lib_marry:get_date_str4(Start,End)} end,
			{Expire,NotExpire} = lists:partition(F, lib_marry:get_wedding_time()),
			Expire_wedding = [F2({Num,Start,End}) || {Num,Start,End} <- Expire],	
			Others = lib_marry:pack_wedding_info(NotExpire,Wlist,PlayerId),
			{ok,BinData} = pt_48:write(48003,{1,lists:append(Expire_wedding, Others)})
	end,
	lib_send:send_to_uid(PlayerId,BinData),
	{noreply, State};

%%发放证书
%% string   男方姓名
%% 	string   女方姓名
%% 	string   时间窜   XX年XX月XX日XX时XX分
%% 	int16          第几对夫妻
handle_info({'give_book',PidSend},State) ->
	Wid = State#state.is_wedding,
	if Wid > 0 ->
		   case ets:lookup(?ETS_WEDDING,Wid) of
			   [] -> skip;
			   [W|_R] ->
				   TodaySec = util:get_today_current_second(),
				   TimeStr = lib_marry:get_date_str2(TodaySec),
				   {ok,Bin} = pt_48:write(48015,{W#ets_wedding.boy_name,W#ets_wedding.girl_name,TimeStr,W#ets_wedding.marry_id}),
				   lib_send:send_to_sid(PidSend,Bin)
		   end;
	   true ->
		   skip
	end,
	{noreply,State};

%%取消婚期
handle_info({'cancel_wedding',PlayerId}, State) ->
	lib_marry:cancel_wedding(PlayerId),
	{noreply,State};

%%查看预订信息
handle_info({'view_book_info',PlayerId}, State) ->
	lib_marry:view_book_info(PlayerId),
	{noreply,State};

%%情人节活动发送魅力榜奖励
handle_info({'LOVEDAYS_CHARM_AWARD'}, State) ->
	Fives = lib_rank:get_charm_five_id(),
	NumList = lists:seq(1,length(Fives)),
	F = fun(Rank) ->
				Pid = lists:nth(Rank,Fives),
				case db_agent:get_nick_by_id(Pid) of
					null->skip;
					Name ->
						lib_activities:send_to_charmer(Rank,Name)
				end
		end,
	[F(Rank) || Rank <- NumList],			
	{noreply,State};

%%新增表白数据
handle_info({'ADD_LOVE_DATA', Rname, Content, PlayerId, PlayerName, PidSend}, State) ->
	%%先检查是否符合条件
	Ms = ets:fun2ms(fun(L) when L#ets_loveday.pid =:= PlayerId -> L end),
	case ets:select(?ETS_LOVEDAY,Ms) of
		[] ->
			case lib_player:get_role_id_by_name(Rname) of
				null ->
					{ok,BinData} = pt_30:write(30026,6),
					lib_send:send_to_sid(PidSend,BinData); %%对方不存在
				Rid ->
					DbId = db_agent:insert_love_data([pid,rid,pname,rname,content],[PlayerId,Rid,PlayerName,Rname,Content]),
					LoveInfo = #ets_loveday{id = DbId, pid = PlayerId, rid= Rid, pname = PlayerName, rname = Rname, content = Content, voters = []},
					ets:insert(?ETS_LOVEDAY, LoveInfo),
					{ok,BinData} = pt_30:write(30026,1),
					lib_send:send_to_sid(PidSend,BinData),
					%% 表白面板重新刷新主推获取当前全服的表白数据
					lib_activities:get_all_lovers_info(PlayerId, PidSend),
					%%世界播报
					Text = 
						io_lib:format("[<font color='#8800FF'>~s</font></a>]对[<font color='#8800FF'>~s</font></a>]深情地说:<font color='#FEDB4F'>~s</font></a>！",
									  [PlayerName, Rname, Content]),
					lib_chat:broadcast_sys_msg(12, Text)
			end;						
		[_P|_Rets] ->
			{ok,BinData} = pt_30:write(30026,2),%%已经表白过了
			lib_send:send_to_sid(PidSend,BinData)
	end,
	{noreply, State};

%%查看
handle_info({'GET_ALL_LOVER',PlayerId, PidSend}, State) ->
	%% 表白面板获取当前全服的表白数据
	lib_activities:get_all_lovers_info(PlayerId, PidSend),
	{noreply, State};

%%投票
handle_info({'VOTE_LOVER', PlayerId, PidSend, Lid}, State) ->
	case ets:lookup(?ETS_LOVEDAY, Lid) of
		[] ->
			{ok,BinData} = pt_30:write(30025,{6,0,0});
		[L|_Rets] ->
			case L#ets_loveday.pid =:= PlayerId of
				true ->
					{ok,BinData} = pt_30:write(30025,{4,0,0}); %%不能对自己发起的表白投票
				false ->
					case ets:lookup(?ETS_VOTERS, PlayerId) of
						[] ->
							NewVoters = [PlayerId | L#ets_loveday.voters],
							NewVotes = L#ets_loveday.votes + 1,
							L2 = L#ets_loveday{votes = NewVotes, voters = NewVoters},
							Term = util:term_to_string(NewVoters),
							db_agent:update_love_data([{votes,NewVotes},{voters,Term}],[{id,Lid}]),
							ets:insert(?ETS_LOVEDAY, L2),
							Voter = #ets_voters{playerid = PlayerId},
							ets:insert(?ETS_VOTERS,Voter),
							{ok,BinData} = pt_30:write(30025,{1,Lid,NewVotes});
						_->
							{ok,BinData} = pt_30:write(30025,{2,0,0})
					end
			end
	end,
	lib_send:send_to_sid(PidSend, BinData),
	{noreply, State};

%%投票最高的玩家及其粉丝奖励
handle_info({'LOVE_WINNER'}, State) ->
	case ets:tab2list(?ETS_LOVEDAY) of
		[] ->
			skip;
		All ->
			%%删除所有的数据
			delete_lovewall(),
			%%排序，倒序
			SortVotes = lists:sort(fun(A,B) ->
										   A#ets_loveday.votes >= B#ets_loveday.votes
								   end, All),
			%%发送奖励
			lovewall_award(3, SortVotes)
	end,
	{noreply, State};

handle_info(_Info, State) ->
	{noreply, State}.


%% --------------------------------------------------------------------
%% Function: terminate/2
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
	?DEBUG("Fail Reason = ~p",[_Reason]),
	ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------

%%%%判断是否新郎新娘(适用于婚宴内部) 
is_inner_couple(Player,State) ->
	#state{wedding = Wedding} = State,
	Reply =
	case Player#player.sex of
		1 ->
			if Wedding#ets_wedding.boy_id =:= Player#player.id ->
				   {true,Wedding,100};
			   true ->
				   {false,0,0}
			end;
		2 ->
			if Wedding#ets_wedding.girl_id =:= Player#player.id ->
				   {true,Wedding,101};
			   true ->
				   {false,0,0}
			end
	end,
	Reply.

%%判断是否新郎新娘(适用于婚宴外部)
is_couple(Player,_State) ->
	{Ms,Moduel} = 
		case Player#player.sex =:= 1 of
			true ->
				{ets:fun2ms(fun(M) when M#ets_wedding.boy_id =:= Player#player.id -> M end),100};
			false ->
				{ets:fun2ms(fun(M) when M#ets_wedding.girl_id =:= Player#player.id -> M end),101}
		end,
	case ets:select(?ETS_WEDDING, Ms) of
		[] -> 
			{false,0,0};
		[Winfo | _R2] ->
			{true,Winfo,Moduel}
	end.

get_white_day() ->
	case get(wd) of
		1 ->
			1;
		_ ->
			0
	end.
put_white_day(Num) ->
	put(wd, Num).

get_max_votes(Result, [], _VotesNum) ->
	Result;
get_max_votes(Result, [Vote|Votes], VotesNum) ->
	case Vote#ets_loveday.votes =:= VotesNum of
		true ->
			NResult = [Vote|Result],
			get_max_votes(NResult, Votes, VotesNum);
		false ->
			get_max_votes(Result, Votes, VotesNum)
	end.
lovewall_award(_Num, []) ->
	skip;
lovewall_award(Num, SortVotes) ->
	[Love|Votes] = SortVotes,
	case Num of
		3 ->%%冠军
			lib_activities:send_to_best_say(Love#ets_loveday.pname, "最佳", 3),
			lib_activities:send_to_best_say(Love#ets_loveday.rname, "最佳", 3),
			Msg = io_lib:format("恭喜<font color='#FFCF00'>~s</font>、<font color='#FFCF00'>~s</font>获得情人节最佳表白，祝愿他俩幸福美满，天下有情人终成眷属～", [Love#ets_loveday.pname,Love#ets_loveday.rname]),
			lib_chat:broadcast_sys_msg(2, Msg),
			Ids = Love#ets_loveday.voters,
			DbData = db_agent:get_player_mult_properties([nickname],Ids),
			Fun = fun(Name) -> lib_activities:send_to_best_fans(Name) end,
			[Fun(PName) || {_Id,[PName]} <- DbData],
			lovewall_award(2, Votes);
		2 ->%%亚军
			lib_activities:send_to_best_say(Love#ets_loveday.pname, "亚军", 2),
			lib_activities:send_to_best_say(Love#ets_loveday.rname, "亚军", 2),
			lovewall_award(1, Votes);
		1 ->%%季军
			lib_activities:send_to_best_say(Love#ets_loveday.pname, "季军", 1),
			lib_activities:send_to_best_say(Love#ets_loveday.rname, "季军", 1),
			lovewall_award(0, Votes);
		_ ->
			skip
	end.
%%删除当前的所有信息，重新来
delete_lovewall() ->
	ets:delete_all_objects(?ETS_LOVEDAY),
	ets:delete_all_objects(?ETS_VOTERS),
	%%删除数据库
	db_agent:delete_all_love_date().

