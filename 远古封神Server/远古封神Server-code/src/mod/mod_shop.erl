%%%------------------------------------
%%% @Module     : mod_shop
%%% @Author     : ygzj
%%% @Created    : 2010.10.06
%%% @Description: 商城
%%%------------------------------------
-module(mod_shop).
-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-compile(export_all).
-define(TIMER,60).
-define(TIME1,259200).%%259200 %% 3天
-define(TIME2,43200).%%43200 %% 半天
-define(OPGOODS,[
				 28602,%%vip半年卡
				 24303, %%仙灵召唤卡
				 28186, %%时装优惠礼包
				 %% 		
				 %%			
				 31034,	%%附魔石优惠礼包
				 28600, %%vip 月卡
				 28603, %%vip 周卡
%% 				 10931, %%时装
%% 				 10932,
%% 				 10933,
%% 				 10934,
%% 				 10935,
%% 				 10936,
%% 				 10937,
%% 				 10938,
%% 				 10939,
%% 				 10940
				 28822 %% 幸运神袋
				]).

-record(state, {copy,th_goods,cur_goods}).
%%%------------------------------------
%%%             接口函数
%%%------------------------------------

start_link() ->      %% 启动服务
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%动态加载商城处理进程 
get_mod_shop_pid() ->
	ProcessName = mod_shop_process,
	case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> 
						Pid;
					false -> 
						start_mod_shop(ProcessName)
				end;
			_ ->
				start_mod_shop(ProcessName)
	end.

%%启动商城模块 (加锁保证全局唯一)
start_mod_shop(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid = start_shop(),
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%启动商城模块
start_shop() ->
	case supervisor:start_child(
       		yg_server_sup, {mod_shop,
            		{mod_shop, start_link,[]},
               		permanent, 10000, supervisor, [mod_shop]}) of
		{ok, Pid} ->
				timer:sleep(1000),
				Pid;
		_ ->
				undefined
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
	ProcessName = mod_shop_process,	
 	case misc:register(unique, ProcessName, self()) of
		yes ->
			%%misc:write_monitor_pid(self(),?MODULE, {}),
			%%misc:write_system_info(self(), mod_shop, {}),	
			%%特惠区物品
			Base = goods_util:get_shop_list(1, 6),
			F = fun(Gs) ->
						lists:member(Gs#ets_shop.goods_id, ?OPGOODS) /= true
				end,
			%%除开服道具外的物品
			Th_goods = lists:filter(F, Base),
			Now = util:unixtime(),
			Opening = config:get_opening_time(),
			case Opening + ?TIME1 > Now of
				true -> %% 开服3天内 
					OP1 = lists:nth(1, ?OPGOODS),
					OP2 = lists:nth(2, ?OPGOODS),
					OP3 = lists:nth(3, ?OPGOODS),
					OP4 = lists:nth(4, ?OPGOODS),
					OP5	= lists:nth(5, ?OPGOODS),
					OP6 = lists:nth(6, ?OPGOODS),
					OP7 = lists:nth(7, ?OPGOODS),
					%% {物品ID ,数量 ，开始时间 ，结束时间 ,职业，性别}
					%% 0表示无限制
					%%显示顺序跟排列顺序一致
					Cur = [
						   {OP1,100,Opening,Opening + ?TIME1 ,0,0},
						   {OP2,100,Opening,Opening + ?TIME1 ,0,0},
						   {OP3,100,Opening,Opening + ?TIME1 ,0,0},
						   %%%
%% 						    {10931,50,Opening,Opening + ?TIME1,1,1},%%玄武男
%% 							{10932,50,Opening,Opening + ?TIME1,1,2},%%玄武女
%% 							{10933,50,Opening,Opening + ?TIME1,2,1},%%白虎男
%% 							{10934,50,Opening,Opening + ?TIME1,2,2},%%白虎女
%% 							{10935,50,Opening,Opening + ?TIME1,3,1},%%青龙男
%% 							{10936,50,Opening,Opening + ?TIME1,3,2},%%青龙女
%% 							{10937,50,Opening,Opening + ?TIME1,4,1},%%朱雀男
%% 							{10938,50,Opening,Opening + ?TIME1,4,2},%%朱雀女
%% 							{10939,50,Opening,Opening + ?TIME1,5,1},%%麒麟男
%% 							{10940,50,Opening,Opening + ?TIME1,5,2},%%麒麟女
						   {OP7,30000,Opening ,Opening + ?TIME1,0,0},
						   %%%%					   
						   {OP4,100,Opening + 86400,Opening + ?TIME1,0,0}, %% 1天后开启86400
						   {OP5,100,Opening + 172800,Opening + ?TIME1,0,0},%% 2天后开启172800
						   {OP6,100,Opening + 172800,Opening + ?TIME1,0,0}
						  ],
					Th_goods2 = Th_goods;
				false -> 
					G1= lists:nth(1, Th_goods),
					G2= lists:nth(2, Th_goods),
					Cur = [
						   {G1#ets_shop.goods_id,888,0,Now+?TIME2,0,0},
						   {G2#ets_shop.goods_id,888,0,Now+?TIME2,0,0}
						  ],
					Th_goods2 = lists:nthtail(2, Th_goods)
			end,
			State = #state{
				   copy=Th_goods,
				   cur_goods = Cur,
				   th_goods=Th_goods2
				  },
			erlang:send_after(?TIMER * 1000, self(), 'refresh'),
			io:format("3.Init mod_shop finish!!!~n"),
			{ok, State};
		_ ->
			{stop,normal,#state{}}
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
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_shop__apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method, Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};
			
handle_call(_Request, _From, State) ->
    {reply, State, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_shop__apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%% 特惠区购买数量增加
handle_cast({'th_sell_add',Goods_id},State) ->
	Cur = State#state.cur_goods,
	case lists:keyfind(Goods_id, 1, Cur) of
		{_g,Num,_B,_T,_C,_S} ->
			NewCur = lists:keyreplace(Goods_id, 1, Cur, {_g,Num -1,_B,_T,_C,_S});
		_ ->
			NewCur = Cur
	end,
	NewState = State#state{cur_goods = NewCur},
	{noreply,NewState};

%% 特惠区物品信息
handle_cast({'get_th_goods',Playerid,Career,Sex,Pid_send},State) ->
	Now = util:unixtime(),
	Cur0 = State#state.cur_goods,
	F_filter = fun({_Goods_id,_Num,_BegTime,_OverTime,_Gcareer,_Gsex}) ->
				 (_Gcareer == Career andalso _Gsex == Sex) orelse (_Gcareer == 0 andalso _Gsex == 0) 
			   end,
	Cur = lists:filter(F_filter, Cur0),
	F = fun({Goods_id,Num,BegTime,OverTime,_career,_sex})  ->
						Lt = 
							if
								OverTime > Now -> %% 72 小时 259200
									if
										BegTime > Now -> %% 还没开始
											Now - BegTime;
										true ->
											OverTime - Now
									end;				
								true ->
									0
							end,
						if	
							Lt == 0 ->
								self() ! {refresh,Goods_id};
							true ->
								skip
						end,
				{Goods_id,Num,Lt}
		end,
	
	GoodsList = lists:map(F, Cur),
	{ok, BinData} = pt_15:write(15013, [Playerid,1, 6, GoodsList, 1]),
	lib_send:send_to_sid(Pid_send, BinData),
	{noreply,State};

	
handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------

%%定时器检查刷新
handle_info('refresh',State)->
	Cur = State#state.cur_goods,
	Now = util:unixtime(),
	F = fun({Goods_id,_Num,_BegTime,OverTime,_Career,_Sex}) ->
				if
					Now > OverTime ->
						self() ! {refresh,Goods_id};
					true ->
						skip
				end
		end,
	lists:foreach(F, Cur),
	erlang:send_after(?TIMER * 1000, self(), 'refresh'),
	{noreply,State};

%%刷新商店物品
handle_info({refresh,Goods_id},State)->
	Cur = State#state.cur_goods,
	Th_goods = State#state.th_goods,
	Copy = 	State#state.copy,
	Now = util:unixtime(),
	IsOpgood = lists:member(Goods_id, ?OPGOODS),
	%%开服道具刷新直接删除
	case IsOpgood andalso length(Cur) > 2  of
		true ->
			NewCur = lists:keydelete(Goods_id, 1, Cur),
			NewState = State#state{cur_goods = NewCur};
		false ->
			case length(Th_goods) > 1 of
				true ->
					G1 = hd(Th_goods),
					Th_goods2 = lists:nthtail(1, Th_goods);			
				false ->
					G1 = hd(Copy),
					Th_goods2 = lists:nthtail(1, Copy)
			end,
			NewOne = {G1#ets_shop.goods_id,888,0,Now + ?TIME2 ,0,0},
			NewCur = lists:keyreplace(Goods_id, 1, Cur, NewOne),
			NewState = State#state{th_goods = Th_goods2 , cur_goods = NewCur}		
	end,
	{noreply,NewState};

handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
	misc:delete_system_info(self()),
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%=========================================================================
%% 业务处理函数
%%=========================================================================

get_goods_num(Goods_id) ->
	case misc:whereis_name({global, mod_shop_process}) of
		Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> 
						gen_server:call(Pid,{get_goods_num,Goods_id});
					false -> 
						0
				end;
			_ ->
				0
	end.

%%是否特惠区开服物品
is_opening_th_goods(Goods_id) ->
	lists:member(Goods_id, ?OPGOODS).
	