%% Author: ZhangChao
%% Created: 2011-11-29
%% Description: TODO: 结婚及婚宴
-module(lib_marry).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-define(CUPLE_CALL_TIMELIMIT, 60).	
%%
%% Exported Functions
%%
-compile(export_all).
%%
%% API Functions
%%

%%提亲判断(男方进程调用)
check_boy_propose(Player,GirlName) ->
	{Result,Code,Girl_Pid} = 
	case Player#player.sex =/= 1 of
			true -> 
				{false,2,0}; %% 2.提亲必须是男方
			false ->
				case goods_util:is_enough_money(Player,?MARRY_COST, coin) of
					false -> 
						{false,3,0};%% 3.你的铜币不足
					true ->
						Ms = ets:fun2ms(fun(M) when M#ets_marry.boy_id =:= Player#player.id -> M end),
						MRes =
							case ets:select(?ETS_MARRY, Ms) of
								[] ->
									1;
								[Marry|_Rets]->
									M = get_self_marry(Marry,Player#player.id),
									case M#ets_marry.do_wedding of
										0 ->
											16;%%(准夫妻关系,已同意求亲，但未办婚宴) 叫"不是单身"
										1 ->
											case M#ets_marry.divorce of
												0 ->
													4;   %%未离婚，不能重婚
												1 ->
													Now = util:unixtime(),
													Days = round((Now - M#ets_marry.div_time)/86400),
													case Days < 7 of
														true -> 
															6;   %%离婚未超过7天
														false -> 
															%%删掉此条离婚超过7天的结婚记录、婚宴记录
															{DbId,_bg} = M#ets_marry.id,
															catch ets:delete(?ETS_MARRY, M#ets_marry.id),
															db_agent:delete_wedding_by_boy(Player#player.id),
															db_agent:delete_marry_info(DbId),
															1
													end
											
											end
									end
							end,
						case ets:lookup(?ETS_PROPOSE_INFO, Player#player.id) of
							[_p|_R] -> 
								{false,5,0}; %% 5.不能重复提亲
							[]->
								case MRes of
									1 ->
										case lib_player:get_role_id_by_name(GirlName) of
											null -> 
												{false,13,0}; %% 5.角色不存在
											Id when erlang:is_integer(Id) ->
												case lib_relationship:rela_for_marry(Player#player.id,Id,1) of
													{fail,RelationCode} ->
														{false,RelationCode,0}; %% 9.对方不是你的好友;  10.亲密度不足16000
													{ok,suc} ->
														case lib_player:get_player_pid(Id) of
															[] -> 
																{false,7,0}; %% 对方不在线
															Pid ->
																{true,0,Pid}
														end
												end
										end;
									FalseCode ->
										{false,FalseCode,0} %%4不能重婚，6离婚不够7天，16你不是单身
								end
						end
				end
	end,
	case Result of
		false ->
			{ok,BinData48000} = pt_48:write(48000,Code),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData48000);
		true ->
			%%开始检查女方
			Girl_Pid ! {'girl_propose_check',Player#player.other#player_other.pid,Player#player.nickname,Player#player.id}
	end.

%%提亲判断(女方进程调用)
check_girl_propose(Player,BoyPid,BoyName,BoyId)->
	{Result,Code} =
		case Player#player.sex of
			1 ->
				{false,8}; %% 8.只能对异性提亲
			2 ->
				Ms = ets:fun2ms(fun(M) when M#ets_marry.girl_id =:= Player#player.id -> M end),
				case ets:select(?ETS_MARRY,Ms) of
					[M|_R] ->
						Marry = get_self_marry(M,Player#player.id),
						case Marry#ets_marry.do_wedding of
							0 ->
								{false,15};%%(准夫妻关系,已同意求亲，但未办婚宴) 叫"不是单身"
							1 ->
								case Marry#ets_marry.divorce of
									0 -> 
										%%未离婚
										{false,11};
									1 ->
										%%离了婚
										Now = util:unixtime(),
										Days = round((Now - Marry#ets_marry.div_time)/86400),
										case Days < 7 of
											true -> 
												{false,14};   %%离婚未超过7天
											false -> 
												%%删掉此条离婚超过7天的结婚记录、婚宴记录
												{DbId,_bg} = Marry#ets_marry.id,
												catch ets:delete(?ETS_MARRY, Marry#ets_marry.id),
												db_agent:delete_wedding_by_boy(BoyId),
												db_agent:delete_marry_info(DbId),
												{true,1}
										end
								end
						end;
					[] -> 
						{true,0}
				end
		end,
	case Result of
		false ->
			{ok,BinData48000} = pt_48:write(48000,Code),
			lib_send:send_to_uid(BoyId, BinData48000);
		true -> 
			%%双方完全满足结婚条件
			%%通知女方，有人求婚  48001
			{ok,BinData48001} = pt_48:write(48001,{BoyId,BoyName}),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData48001),
			%%通知男方，提亲成功
			{ok,BinData48000} = pt_48:write(48000,1),
			lib_send:send_to_uid(BoyId, BinData48000),
			%%男方写入提亲表
			BoyPid ! {'propose_sucess',Player#player.id}
	end.

%%检查能否结婚(男方调用)
check_can_marry(Player,Gpid,Gid,Grealm) ->
	{Res,G,B} = 
		case Player#player.coin < ?MARRY_COST of
			true ->
				{false,4,4};
			false ->
				case Player#player.sex of
					2 ->
						{false,5,5};
					1 ->
						case ets:lookup(?ETS_PROPOSE_INFO,Player#player.id) of
							[] ->
								{false,6,6};
							[_P|_Ps] ->
								{true,1,1}
						end
				end
		end,
	case Res of
		false ->
			{ok,GirlBin} = pt_48:write(48002,G),
			{ok,BoyBin} = pt_48:write(48016,B),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BoyBin),
			lib_send:send_to_uid(Gid,GirlBin),
			{false,Player};
		true ->
			Now = util:unixtime(),
			DbId = db_agent:do_marry(Now,Player#player.id,Gid),
			Marry = #ets_marry{ id = {DbId,Player#player.id}, boy_id = Player#player.id, girl_id = Gid, marry_time = Now},
			%%男方节点插入ETS
			ets:insert(?ETS_MARRY, Marry),
			%%男方扣钱
			Player2 = lib_goods:cost_money(Player, ?MARRY_COST, coinonly, 4802),
			%%通知女方更新结婚ETS，并刷新任务,
			Gpid ! {'marry_sucess',Marry#ets_marry{id = {DbId,Gid}}},
			{ok,GirlBin} = pt_48:write(48002,1),
			{ok,BoyBin} = pt_48:write(48016,1),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BoyBin),
			lib_send:send_to_uid(Gid,GirlBin),
			%%男方打开婚宴面板
			Wedding_Pid = mod_wedding:get_mod_wedding_pid(),
			Wedding_Pid ! {'QUERY_WEDDING_INFO',Player#player.sex,Player#player.id},
			%%男方刷新任务列表
			gen_server:cast(Player#player.other#player_other.pid_task,{'refresh_task',Player}),
			%%全服广播
			NameColor = data_agent:get_realm_color(Player#player.realm),
			GNameColor = data_agent:get_realm_color(Grealm),
			Gname = db_agent:get_nick_by_id(Gid),
			Msg = io_lib:format("百年恩爱双心结，千里姻缘一线牵！<font color='~s'>~s</font>被<font color='~s'>~s</font>的爱意打动！接受了<font color='~s'>~s</font>的提亲！祝福他们百年好合，永结同心！", [GNameColor,Gname,NameColor,Player#player.nickname,NameColor,Player#player.nickname]),
			lib_chat:broadcast_sys_msg(2, Msg),
			Title = "订婚通知",
			Content1 = io_lib:format("恭喜你和~s订婚成功，请于即日起3天内举办婚宴，订婚3天后未举办婚宴的将会自动解除订婚关系，需要重新提亲！",[Gname]),
			Content2 = io_lib:format("恭喜你和~s订婚成功，请于即日起3天内举办婚宴，订婚3天后未举办婚宴的将会自动解除订婚关系，需要重新提亲！",[Player#player.nickname]),
			mod_mail:send_sys_mail([tool:to_list(Player#player.nickname)], Title, Content1, 0, 0, 0, 0, 0, 0),
			mod_mail:send_sys_mail([tool:to_list(Gname)], Title, Content2, 0, 0, 0, 0, 0, 0),
			%%日志
			spawn(fun()->db_agent:log_add_marry(Player#player.id,Gid,?MARRY_COST,Now) end),
			%%广播鲜花
			{ok,Bin48017} = pt_48:write(48017,<<>>),
			lib_send:send_to_all(Bin48017),
			{true,Player2}
	end.
					
%%判断能否打开预订婚宴的面板
check_can_book_wedding(Sex,PlayerId) ->
	case Sex of
		1 -> case db_agent:get_marry_by_boy(PlayerId) of
				 null -> {fail,2};%%未结婚
				 1 -> {fail,3}; %%已举办过
				 0 -> {ok,1};
				 _R ->
					 {fail,4}
			 end;
		2 -> case db_agent:get_marry_by_girl(PlayerId) of
				 null -> {fail,2};%%未结婚
				 1 -> {fail,3}; %%已举办过
				 0 -> {ok,1};
				 _ -> {fail,4}
			 end
	end.

%%判断能否预订该婚宴
%% 3，还未结婚；4，已经办过，5，该婚宴已被预订，7,你已预定今天的婚宴，8，只有男方可以预定， 2，婚宴与场次不符 ， 6， 元宝不足
check_wedding(Player,Marry,Type,Num) ->
	%%该场婚宴有没被预订过
	Ms = ets:fun2ms(fun(W) when W#ets_wedding.wedding_num =:= Num -> W end),
	%%该玩家是否已经预订了
	{Mid,_Id} = Marry#ets_marry.id,
	Ms_w = ets:fun2ms(fun(W) when W#ets_wedding.marry_id =:= Mid -> W end),
		case ets:select(?ETS_WEDDING,Ms_w) of
			[] ->
				case ets:select(?ETS_WEDDING,Ms) of	
					[] ->
						TodaySec = util:get_today_current_second(),
						case lists:keyfind(Num, 1, get_wedding_time()) of
							false -> {false,2};%%2，婚宴与场次不符 
							{_N,S,_E} ->
								case S < TodaySec of
									true ->
										{false,5}; %%过期，需要新的错误码
									false ->
										case goods_util:is_enough_money(Player,get_wedding_cost(Type),gold) of
											false -> {false,6}; %%元宝不足
											true ->
												case lists:member(Num,[11,12,13]) of
													true ->
														case (Type =/= 2 andalso Type =/= 3) of
															true ->
																{false,2};%%2，婚宴与场次不符 
															false ->
																{true,Marry}
														end;
													false ->
														{true,Marry}
												end
										end
								end
						end;
					_ -> 
						{false,5} %%已被预订
				end;
			_->
				{false,7}
	end.
						  
%%预订婚宴
%%MarryId,BoyName,GirlName,WType,WNum,WStart,BookTime,Gold
do_wedding(Marry,WType,WNum,Player) ->
	{Bcolor,BoyName} = 
		case db_agent:get_chat_info_by_id(Marry#ets_marry.boy_id) of
			[BRealm, _Level, _G, _GId, Bname] ->{data_agent:get_realm_color(BRealm),Bname};
			[] -> 100
		end,
	{Gcolor,GirlName} =
		case db_agent:get_chat_info_by_id(Marry#ets_marry.girl_id) of
			[GRealm, _Level2, _G2, _GId2, Gname] -> {data_agent:get_realm_color(GRealm),Gname};
			[] -> 100
		end,
	Now = util:unixtime(),
	Gold = get_wedding_cost(WType),
    case lists:keyfind(WNum,1,get_wedding_time()) of
		false -> skip;
		{_N,WStart,_E} ->
			{Mid,_O} = Marry#ets_marry.id,
			DbId = db_agent:insert_wedding(Mid,Marry#ets_marry.boy_id,Marry#ets_marry.girl_id,BoyName,GirlName,WType,WNum,WStart,Now,Gold),		
			Data = [DbId,Mid,BoyName,GirlName,Marry#ets_marry.boy_id,Marry#ets_marry.girl_id,[],[],WType,WNum,WStart,Now,Gold,0,0,0],
			Red = list_to_tuple([ets_wedding | Data]),
			ets:insert(?ETS_WEDDING,Red),
			%%通知人物进程扣钱
			Pid = Player#player.other#player_other.pid,
			Pid ! {'BOOK_WEDDING_PAY',Gold},
			%%发放婚宴通知邮件（新郎新娘）
			send_mail_book_wedding(Red),
			spawn(fun()->db_agent:log_add_wedding(Player#player.id,Marry#ets_marry.girl_id,DbId,Gold,0,Now,WNum) end),
			%%聊天广播
			TimeStr = get_date_str(WStart),
			{CnType,_R} = get_cn_type(WType),
			Msg = io_lib:format("<font color='~s'>~s</font>与<font color='~s'>~s</font>预定了<font color='#FEDB4F'> ~s</font>的<font color='#FEDB4F'>~s</font>婚宴！被邀请的朋友届时记得前来参加!", [Bcolor,BoyName,Gcolor,GirlName,TimeStr,CnType]),
			lib_chat:broadcast_sys_msg(2, Msg)
	end.

%%婚宴广播全服
notice_all(W)->
	case wedding_msg(W) of
		{0,0} ->
			skip;
		{BinData,AllBinData} ->
			F = fun(Id) ->
						lib_send:send_to_uid(Id, BinData),
						lib_send:send_to_uid(Id, AllBinData)
				end,
			IdList = [W#ets_wedding.boy_id,W#ets_wedding.girl_id] ++ W#ets_wedding.boy_invite ++ W#ets_wedding.girl_invite,
			lists:map(F,IdList),
			lib_send:send_to_all(AllBinData)
	end.

%%客户端清除婚宴图标
notice_all_clear() ->
	{ok,AllBinData} = pt_48:write(48014,{2,0,[],0,0}),
	lib_send:send_to_all(AllBinData).

%%婚宴开始时发放烟花
send_fireworks(W) ->
	Send_ids = W#ets_wedding.boy_invite ++ W#ets_wedding.girl_invite,
	Title = "婚礼烟花",
	Content1 = "祝福您们新婚快乐!送上烟花一份。",
	Content2 = io_lib:format("祝~s与~s新婚快乐，送上烟花一份！", [W#ets_wedding.boy_name,W#ets_wedding.girl_name]),
	{GoodsId,Num} = get_fireworks_type(W#ets_wedding.wedding_type),
	if Send_ids =/= [] ->
		   DbData = db_agent:get_player_mult_properties([nickname],Send_ids),
		   NickNames = [Nick || {_Id,[Nick]} <- DbData],		  
		   Mfun = fun(Nstr) ->
						  mod_mail:send_sys_mail([Nstr], Title, Content2, 0, GoodsId, Num, 0, 0, 0)
				  end,
		   %%被邀请的玩家
		   [Mfun(Name) || Name <- NickNames];
	   true ->
		   skip
	end,
	%%新郎
	mod_mail:send_sys_mail([W#ets_wedding.boy_name], Title, Content1, 0, GoodsId, Num, 0, 0, 0),
	%%新娘
	mod_mail:send_sys_mail([W#ets_wedding.girl_name], Title, Content1, 0, GoodsId, Num, 0, 0, 0).	

wedding_msg(W) ->
	TimeStr = get_date_str(W#ets_wedding.wedding_start),
	{Wtype,RingLv} = get_cn_type(W#ets_wedding.wedding_type),
	Message = "恭喜<font color='#FEDB4F'>~s</font>和<font color='#FEDB4F'>~s</font>\n成为本服第~p对新人\n以~p级永恒之戒作为他们爱情的见证\n他们将于<font color='#FEDB4F'>~s</font>举办~s婚礼\n希望所有玩家给予这对幸福的新人最真诚的祝福!\n请收到邀请的嘉宾尽快进入结婚场景参加婚礼!",
	Msg = io_lib:format(Message, [W#ets_wedding.boy_name,
								  W#ets_wedding.girl_name,
								  W#ets_wedding.marry_id,
								  RingLv,
								  TimeStr,
								  Wtype]),
	case db_agent:get_player_career(W#ets_wedding.boy_id) of
		null ->
			{0,0};
		Bc ->
			case db_agent:get_player_career(W#ets_wedding.girl_id) of
				null ->
					{0,0};
				Gc ->
					%%48008中间弹窗; 48014图标通知
					%%?DEBUG("{BinData,AllBinData}{BinData,AllBinData}",[]),
					{ok,BinData} = pt_48:write(48008,{Msg,Bc,Gc}),
					TodaySec = util:get_today_current_second(),
					{_N,_S,E} = lists:keyfind(W#ets_wedding.wedding_num,1,get_wedding_time()),
					Retime = E - TodaySec,
					{ok,AllBinData} = pt_48:write(48014,{1,Retime,Msg,Bc,Gc}),
					{BinData,AllBinData}
			end
	end.

%%登陆加载结婚记录
load_marry_info(Sex,Id) ->
	Field = 
		case Sex of
			1 -> boy_id;
			2 -> girl_id
		end,
	case db_agent:get_marry_row(Id,Field) of
		[] -> "";
		DbMarry ->
			[DbId,BoyId,GirlId,DoWedding,MarryTime,RecGold,RecCoin,Divorce,DivTime] = DbMarry,
			M = 
				case Field of
					boy_id ->
						[{DbId,BoyId},BoyId,GirlId,DoWedding,MarryTime,RecGold,RecCoin,Divorce,DivTime];
					girl_id ->
					   [{DbId,GirlId},BoyId,GirlId,DoWedding,MarryTime,RecGold,RecCoin,Divorce,DivTime]
				end,	
			Marry = list_to_tuple([ets_marry | M]),
			if Marry#ets_marry.do_wedding =:= 0 ->
				   Now = util:unixtime(),
				   MTime = Marry#ets_marry.marry_time,
				   case round((Now - MTime)/86400) < 3 of
					   true ->
						   %%准夫妻关系没超过3天，保留
						   ets:insert(?ETS_MARRY,Marry),
						   "";%%未正常举办婚宴，不显示红心与配偶姓名
					   false ->
						   %%删除超过3天的准夫妻关系
						   %%要先检查玩家是否预订了今天的婚宴，预订了就不能删了，临界点！！！
						   case db_agent:get_wedding_by_mid(DbId) of
							   [] -> db_agent:delete_marry_info(DbId),
									 "";%%已经3天，而且还未预订婚宴，删掉
							   _->
								   ets:insert(?ETS_MARRY,Marry),
								   ""%%虽然已经3天，但是已经预订婚宴只是还未举办，不能删除结婚记录
						   end
				   end;
			   true ->
				   case Marry#ets_marry.divorce of
					   0 ->
						   case Sex of
							   1->
								   case db_agent:get_nick_by_id(Marry#ets_marry.girl_id) of
									   null ->
										   "";
									   Name -> 
										   ets:insert(?ETS_MARRY,Marry),
										   Name   %%未离婚
								   end;
							   2->
								   case db_agent:get_nick_by_id(Marry#ets_marry.boy_id) of
									   null ->
										   "";
									   Name -> 
										   ets:insert(?ETS_MARRY,Marry),
										   Name   %%未离婚
								   end
						   end;
					   1 ->
						   Now = util:unixtime(),
						   Days = round((Now - Marry#ets_marry.div_time)/86400),
						   case Days < 7 of
							   true ->
								   ets:insert(?ETS_MARRY,Marry);%%离婚未超过7天
							   false -> 
								   %%删掉此条离婚超过7天的结婚记录、婚宴记录
%% 								   {DbId,_bg} = Marry#ets_marry.id,
								   catch ets:delete(?ETS_MARRY, Marry#ets_marry.id),
								   case Sex of
									   2 ->
										   spawn(fun()->db_agent:delete_wedding_by_girl(Id) end);
									   1 ->
										   spawn(fun() -> db_agent:delete_wedding_by_boy(Id) end)
								   end,
								   db_agent:delete_marry_info(DbId)
						   end,
						   ""    %%离婚了
				   end
			end
	end.

%%打包婚宴信息
%% 1已过期，2可预约，3被预订，4我的婚期, 5特殊婚宴且未被预订
pack_wedding_info(All,Wlist,PlayerId) ->
	Fun = fun(E) ->
				  {E_num,E_start,E_end} = E,
				  TimeStr = lib_marry:get_date_str4(E_start,E_end),
				  Live_nums = [{W#ets_wedding.wedding_num,W} || W <- Wlist],
				  case lists:keyfind(E_num,1,Live_nums) of
					  {E_num,W} ->
						  case W#ets_wedding.boy_id =:= PlayerId orelse W#ets_wedding.girl_id =:= PlayerId of
							  true ->
								  {E_num,4,TimeStr};%%自己的婚期
							  false ->
								  {E_num,3,TimeStr}%%被预定了的
						  end;
					  false ->
						  case lists:member(E_num, [11,12,13]) of
							  true ->
								  {E_num,5,TimeStr};%%可预约,且是豪华型
							  false ->
								  {E_num,2,TimeStr} %%可预约
						  end
				  end
		  end,
	Fun2 = fun(E)->
				  {E_num,E_start,E_end} = E,  
				  TimeStr = lib_marry:get_date_str4(E_start,E_end),
				  case lists:member(E_num, [11,12,13]) of
							  true ->
								  {E_num,5,TimeStr};%%可预约,且是豪华型
							  false ->
								  {E_num,2,TimeStr} %%可预约
				  end
		   end,
	NeedList =
		if Wlist =:= [] ->
			   [Fun2(E) || E <- All];
		   true ->
			   [Fun(E) || E <- All]
		end,
	NeedList.
				
%%加载结婚信息，并获取配偶名
get_couple_name(Sex,Id) ->
	load_marry_info(Sex,Id).

%%下线删除ETS结婚信息
unload_marry_info(PlayerId,Sex) ->
	Ms =
		case Sex of
			1 ->
				ets:fun2ms(fun(M) when M#ets_marry.boy_id =:= PlayerId -> M end);
			2 ->
				ets:fun2ms(fun(M) when M#ets_marry.girl_id =:= PlayerId -> M end)
		end,
	case ets:select(?ETS_MARRY, Ms) of
		[] ->
			skip;
		[Marry|_Rets] ->
			M = get_self_marry(Marry,PlayerId),
			ets:delete(?ETS_MARRY, M#ets_marry.id)
	end.

%%赠送贺礼扣钱(玩家进程来操作)
pay_for_gift(Gold,Coin,Player) ->
	Player1 = lib_goods:cost_money(Player, Gold, gold, 4809),
	Player2 = lib_goods:cost_money(Player1, Coin, coinonly, 4809),
	lib_player:send_player_attribute(Player2, 2),
	Player2.

%%  15,48	24,36
%% 	22,58	34,45
%% 	33,70	44,53

%%餐桌生成函数
make_dinner_table(PidSend) ->
	A = [{1,15,48},{2,24,36},{3,22,58},{4,34,45},{5,33,70},{6,44,53}],
	{ok,Bin} = pt_12:write(12073,A),
	lib_send:send_to_sid(PidSend, Bin).
				  
%%进入婚宴前的检测(只与婚宴相关的条件)
enter_wedding(Status) ->
	 Sce = lib_deliver:could_deliver(Status),
	 if Sce =:= 31 orelse Sce =:= 32 orelse Sce =:= 33 
				orelse Sce =:= 34 orelse Sce =:= 35
				orelse Sce =:= 36 orelse Sce =:= 37
		  		orelse Sce =:= 38 orelse Sce =:= 41
		  	    orelse Sce =:= 42 orelse Sce =:= 43
		  		orelse Sce =:= 39 ->	%%副本中
						{5,  1, Status};
		Sce =:= 22 -> %%运镖,跑商
			{6, 1, Status};
		Sce =:= 21 ->%%红名
			{7,  1, Status};
		Sce =:= 10 orelse Sce =:= 13 ->%%战斗中，挂机中
			{8,  1, Status};
		Sce =:= 12 ->%%蓝名
			{13,  1, Status};
		Sce =:= 14 ->%%打坐
			{9,  1, Status};
		Sce =:= 15 ->%%凝神
			{10,  1, Status};
		Status#player.mount > 0 ->%%有坐骑
			{11,  1, Status};
		Sce =:= 11 orelse Sce =:= 16  ->%%死亡，挖矿
			{12,  1, Status};
		Sce =:= 18 ->%%双修不能进入婚宴
			{14, 1,  Status};
		true -> 
			Result =
				case data_scene:get(?WEDDING_SCENE_ID) of
					[] ->
						{false, 0, 0, 0, <<"场景不存在!">>, 0, []};
					Scene ->
						case lib_scene:check_requirement(Status, Scene#ets_scene.requirement) of
							{false, Reason} -> 
								{false, 0, 0, 0, Reason, 0, []};
							{true} ->
								get_wedding_scene_info(Status, Scene#ets_scene.name,Scene#ets_scene.x, Scene#ets_scene.y, ?WEDDING_SCENE_ID);
							_Other ->
								{false, 0, 0, 0, <<"场景不存在!">>, 0, []}
						end
				end,
			case Result of
				{false, _, _, _, _Msg, _, _} ->%%没有这个场景
					{0, 1,Status};
				{true, NewSceneId, X, Y, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, Status1} ->
					case gen_server:call(mod_wedding:get_mod_wedding_pid(), {'CAN_ENTER_WEDDING',Status1#player.id}) of
						{'EXIT', _} ->
							{error,1,2};
						{false,Code} ->
							{Code,1,Status};
						{true,Moduel,W_Type} ->
							%%告诉原场景的玩家你已经离开
							pp_scene:handle(12004, Status, Status#player.scene),
							{ok, BinData} = pt_12:write(12005,			
												[NewSceneId, X, Y, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, 0]),
							lib_send:send_to_sid(Status1#player.other#player_other.pid_send, BinData),
							put(change_scene_xy , [X, Y]),%%做坐标记录
							Status2 = Status1#player{scene = NewSceneId, x = X, y = Y,
															 other = Status1#player.other#player_other{turned = Moduel}},
							%%更新玩家新坐标
							ValueList = [{scene,NewSceneId},{x,X},{y,Y}],
							WhereList = [{id, Status2#player.id}],
							%%通知场景，模型改变
							{ok,Data12066} = pt_12:write(12066,[Status2#player.id,Status2#player.other#player_other.turned]),
							mod_scene_agent:send_to_area_scene(Status2#player.scene,Status2#player.x, Status2#player.y, Data12066),
							db_agent:mm_update_player_info(ValueList, WhereList),                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                
							{1,W_Type,Status2}
					end
			end
	 end.

%%通过传送阵进入婚宴或洞房场景
check_marry_scene_enter(SceneId)->
	Wpid = mod_wedding:get_mod_wedding_pid(),
	case SceneId =:= ?WEDDING_LOVE_SCENE_ID of
		true ->%%由婚宴场景进入洞房场景
			case gen_server:call(Wpid, {'IS_BT'}) of
				{'EXIT',_} ->
					{false,<<"进入场景时发生错误！">>};
				false ->
					{false,<<"新郎新娘还未拜堂，不能进入洞房场景！">>};
				true ->
					{true,enter}
			end;
		false -> %%由洞房场景进入婚宴场景
			{true,enter}
	end.
			

%%婚宴加经验灵力定时器
wedding_add_timmer(Player,Wtype) ->
	misc:cancel_timer(wedding_timer),
	#player{lv = Lv} = Player,
	Exp = get_wedding_expspi(Lv,Wtype),
	Spi = tool:ceil(Exp * 2),
	NewStatus = lib_player:add_exp(Player, Exp, Spi, 22),
	%%婚宴经验定时器
	WeddingTimeer = erlang:send_after(30*1000, self(), {'WEDDING_ADD',Wtype}), 
	put(wedding_timer, WeddingTimeer),
	NewStatus.
	
%%登陆检测是否有婚宴在举办
is_wedding_on(Player) ->
	case gen_server:call(mod_wedding:get_mod_wedding_pid(), {'IS_WEDDING_ON'}) of
		{'EXIT',_} ->
			skip;
		{false,0} ->
			skip;
		{true,Wedding} ->
			{BinData,AllBin} = wedding_msg(Wedding),
			if Wedding#ets_wedding.boy_id =:= Player#player.id orelse Wedding#ets_wedding.girl_id =:= Player#player.id ->
				   lib_send:send_to_sid(Player#player.other#player_other.pid_send, AllBin),
				   lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
			   true ->
				   lib_send:send_to_sid(Player#player.other#player_other.pid_send, AllBin)
			end
	end.
	
%%
%% Local Functions
%%
	
add_invite_ids([],OldIds) ->
	OldIds;
add_invite_ids([One|NeedAdd],OldIds) ->
	add_invite_ids(NeedAdd,[One | OldIds]).
	
%%婚宴的价格
get_wedding_cost(Type) ->
	case Type of
		2 -> 1314;
		3 -> 3344;
		_ -> 0
	end.

%%女方接受提亲时，判断新郎是否有足够铜币
is_enough_coin(Player) ->
	goods_util:is_enough_money(Player,?MARRY_COST,coinonly). 

%%用于购买喜帖的元宝
get_pay_for_mail(Wedding,Sex) ->
	case Sex of
		1 -> Wedding#ets_wedding.boy_cost;
		2 -> Wedding#ets_wedding.girl_cost
	end.

%%婚宴的请帖数
get_wedding_invites_max(Wedding,Sex) ->
	Inv_cost = get_pay_for_mail(Wedding,Sex),
	Num1 = 
		case Wedding#ets_wedding.wedding_type of
			1 -> 5;
			2 -> 10;
			3 -> 20;
			_ -> 0
		end,
	Num2 = erlang:round(Inv_cost/10),
	Num1 + Num2.

%%婚宴中文类型、戒指级数
get_cn_type(Type) ->
	case Type of
		1 -> {"普通型",1};
		2 -> {"豪华型",3};
		3 -> {"梦幻型",4}
	end.

%%烟花类型、烟花数量
get_fireworks_type(Type) ->
	case Type of
		1 ->
			{28049,5};
		2 ->
			{28050,10};
		3 ->
			{28051,20}
	end.

%%戒指级数获取ID
get_ring_by_type(Type) ->
	{_M,Rlv} = get_cn_type(Type),
	case Rlv of
		1 -> 10801;
		3 -> 10803;
		4 -> 10804
	end.
			

%%生成日期时间字符窜
get_date_str(TodaySec)->
	{_Y,Month,Day} = erlang:date(),
	Hour = erlang:trunc(TodaySec/3600),
	Min = erlang:round((TodaySec rem 3600)/60),
	io_lib:format("~p月~p日~p时~p分",[Month,Day,Hour,Min]).

get_date_str2(TodaySec)->
	{Y,Month,Day} = erlang:date(),
	Hour = erlang:trunc(TodaySec/3600),
	io_lib:format("~p年~p月~p日~p时",[Y,Month,Day,Hour]).

get_date_str3(DaySec) ->
	Hour = erlang:trunc(DaySec/3600),
	Min = erlang:round((DaySec rem 3600)/60),	
	Str1 = io_lib:format("~p:",[Hour]),
	Str2 = 
		if Min =:= 0 ->
			   io_lib:format("~p0",[Min]);
		   Min < 10 ->
			   io_lib:format("0~p",[Min]);
		   true ->
			   io_lib:format("~p",[Min])
		end,
	io_lib:format("~s~s",[Str1,Str2]).

get_date_str4(S,E) ->
	Str1 = get_date_str3(S),
	Str2 = get_date_str3(E),
	io_lib:format("~s-~s", [Str1,Str2]).
		
	

%%是否婚宴场景
is_wedding_scene(SceneId) ->
	SceneId =:= ?WEDDING_SCENE_ID.

%%是否洞房场景
is_love_scene(SceneId) ->
	SceneId =:= ?WEDDING_LOVE_SCENE_ID.

%%是否婚宴或洞房场景
is_wedding_love_scene(SceneId) ->
	SceneId =:= ?WEDDING_SCENE_ID orelse SceneId =:= ?WEDDING_LOVE_SCENE_ID.

%%传出天涯海角的坐标
get_wedding_send_out() ->
	[{214, [{11, 41}, {13, 39}]},2].

get_wedding_scene_info(Status, Name, X, Y, SceneId) ->
	case mod_wedding:get_mod_wedding_pid() of
		Pid when erlang:is_pid(Pid) ->
			Status1 = Status#player{other = Status#player.other#player_other{pid_scene = Pid}},
			%%获取发送给客户端的有关玩家资源Id
			ResureSId = SceneId, 
			{true, SceneId, X, Y, Name, ResureSId, 0, 0, Status1};
		_ ->
			{false, 0, 0, 0, <<"场景不存在!">>, 0, []}
	end.

%%通知已被邀请参加婚宴的玩家
send_mail_to_invites(IdList,Bname,Girlname) ->
	DbData = db_agent:get_player_mult_properties([nickname],IdList),
	NickNames = [Nick || {_Id,[Nick]} <- DbData],
	Title2 = io_lib:format("婚宴通知",[]),
	Content2 = io_lib:format("亲爱的玩家，由于结婚时间冲突导致~s和~s的婚礼不能如期举办，我们深感抱歉！",[Bname,Girlname]),
	mod_mail:send_sys_mail(NickNames, Title2, Content2, 0, 0, 0, 0, 0).

%%赔偿婚宴不能正常举办
send_mail_to_pay(Gold,BoyNameList,GirlNameList,Wid)->
	Title = io_lib:format("婚宴补偿",[]),
	if Gold =< 0 ->
		   Content = io_lib:format("亲爱的玩家，由于结婚时间冲突导致婚宴无法正常举办，我们深感遗憾！您可以重新选择一次婚期，望见谅！",[]),
		   mod_mail:send_sys_mail(BoyNameList, Title, Content, 0, 0, 0, 0, 0),
		   mod_mail:send_sys_mail(GirlNameList, Title, Content, 0, 0, 0, 0, 0);
	   true ->
		   Content = io_lib:format(" 亲爱的玩家，由于结婚时间冲突导致婚宴无法正常举办，我们深感遗憾！同时将会退回您全额元宝，您可以重新选择一次婚期。",[]),
		   mod_mail:send_sys_mail(BoyNameList, Title, Content, 0, 0, 0, 0, Gold),
		   mod_mail:send_sys_mail(GirlNameList, Title, Content,0, 0, 0, 0, 0)
	end,
	%%删除此条婚宴记录
	db_agent:delete_wedding(Wid).

%%成功预订婚宴的邮件通知
send_mail_book_wedding(Wedding) ->
	Title = io_lib:format("婚宴通知",[]),
	TimeStr = get_date_str(Wedding#ets_wedding.wedding_start),
	Content = io_lib:format("~s已成功预订~s的婚礼！",[Wedding#ets_wedding.boy_name,TimeStr]),
	mod_mail:send_sys_mail([Wedding#ets_wedding.boy_name], Title, Content, 0, 0, 0, 0, 0, 0),
	mod_mail:send_sys_mail([Wedding#ets_wedding.girl_name], Title, Content, 0, 0, 0, 0, 0, 0).

%%取消婚宴的通知
send_mail_cancel_wedding(W) ->
	InvIds = W#ets_wedding.boy_invite ++ W#ets_wedding.girl_invite,
	DbData = db_agent:get_player_mult_properties([nickname],InvIds),
	NickNames = [Nick || {_Id,[Nick]} <- DbData],
	TimeStr = get_date_str(W#ets_wedding.wedding_start),
	Title = io_lib:format("婚宴取消",[]),
	Content1 = io_lib:format("~s已取消了原定为~s举办的婚礼。",[W#ets_wedding.boy_name,TimeStr]),
	Content2 = io_lib:format("~s与~s已取消了原定为~s举办的婚礼。",[W#ets_wedding.boy_name,W#ets_wedding.girl_name,TimeStr]),
	%%被邀请的玩家
	mod_mail:send_sys_mail(NickNames, Title, Content2, 0, 0, 0, 0, 0),
	%%新郎
	mod_mail:send_sys_mail([W#ets_wedding.boy_name], Title, Content1, 0, 0, 0, 0, W#ets_wedding.gold),
	%%新娘
	mod_mail:send_sys_mail([W#ets_wedding.girl_name], Title, Content1, 0, 0, 0, 0, 0).

%%婚宴结束通知新郎
send_mail_to_boy(W) ->
	case db_agent:get_marry_info(W#ets_wedding.marry_id) of
		[] ->
			skip;
		Data ->
			[_DbId,_BoyId,_GirlId,_DoWedding,_MarryTime,RecGold,RecCoin,_Divorce,_DivTime] = Data,
			Title = io_lib:format("婚宴结束",[]),
			Content = io_lib:format("婚宴结束，你共收到~p元宝，~p铜币。",[RecGold,RecCoin]),
			mod_mail:send_sys_mail([W#ets_wedding.boy_name], Title, Content, 0, 0, 0, 0, 0)
	end.

%%离婚通知邮件
send_divorce_mail(Name1,Name2) ->
	Title = "离婚",
	Content1 = io_lib:format("~s认为你们真的不适合在一起，已与你离婚！即日起7天内你们将无法提亲或被提亲。", [Name1]),
	Content2 = io_lib:format("你已与~s离婚！即日起7天内你们将无法提亲或被提亲。", [Name2]),
	mod_mail:send_sys_mail([tool:to_list(Name2)], Title, Content1, 0, 0, 0, 0, 0),
	mod_mail:send_sys_mail([tool:to_list(Name1)], Title, Content2, 0, 0, 0, 0, 0).
		
%%取消吃饭状态
cancel_wedding_eat(Player) ->
	if Player#player.carry_mark =:= 28 ->
		   Player1 = Player#player{carry_mark = 0},
		   lib_player:send_player_attribute(Player1,2),
		   {ok,Bin} = pt_48:write(48010,{Player1#player.id,0}),
		   lib_send:send_to_sid(Player1#player.other#player_other.pid_send, Bin),
		   mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, Bin),
		   Player1;
	   true ->
		   Player
	end.

%%取消婚期
cancel_wedding(PlayerId) ->
	%%只限男方能取消
	Ms = ets:fun2ms(fun(W) when W#ets_wedding.boy_id =:= PlayerId -> W end ),
	case ets:select(?ETS_WEDDING, Ms) of
		[] ->
			%%还未预订婚宴
			{ok,Bin} = pt_48:write(48020,2);
		[W|_Rets] ->
			TodaySec = util:get_today_current_second(),
			Start = W#ets_wedding.wedding_start,
			case TodaySec >=  Start - 3*60 of
				true ->
					%%婚宴快要开始了(3分钟公告已发出，不可取消)
					{ok,Bin} = pt_48:write(48020,3);
				false ->
					%%成功
					%%处理ETS
					catch ets:delete(?ETS_WEDDING, W#ets_wedding.id),
					%%处理DB
					db_agent:delete_wedding(W#ets_wedding.id),
					%%扣除男方YB
					case lib_player:get_player_pid(PlayerId) of
						[] ->
							skip;
						Pid ->
							Pid ! {'cancel_wedding_pay'}
					end,
					%%邮件赔偿元宝并通知,
					send_mail_cancel_wedding(W),
					Now = util:unixtime(),
					spawn(fun()->db_agent:log_cancel_wedding(W#ets_wedding.id,W#ets_wedding.wedding_start,W#ets_wedding.wedding_num,
													W#ets_wedding.gold,Now,100) end),
					{ok,Bin} = pt_48:write(48020,1)
			end
	end,
	lib_send:send_to_uid(PlayerId,Bin).

%%查看预订信息
view_book_info(PlayerId) ->
	{Y,M,D} = erlang:date(),
	case ets:tab2list(?ETS_WEDDING) of
		[] ->
			{ok,Bin} = pt_48:write(48021,{Y,M,D,[]});
		Wlist ->
			Gun = fun(W) ->
						  Start = W#ets_wedding.wedding_start,
						  End =
							  case lists:keyfind(Start, 2, get_wedding_time()) of
								  false ->
									  0;
								  {_N,_S,E} ->
									  E
							  end,
						  TimeStr = get_date_str4(Start,End),
						  {W#ets_wedding.wedding_start,{TimeStr,W#ets_wedding.boy_name,W#ets_wedding.girl_name,W#ets_wedding.wedding_type}}
				  end,
			List1 = lists:sort([Gun(W) || W <- Wlist]),
			Fun = fun(E) ->
						{_S,{TimeStr,Bname,Gname,Wtype}} = E,
						{TimeStr,Bname,Gname,Wtype}
				  end,
			List2 = lists:reverse([Fun(E) || E <- List1]),
			{ok,Bin} = pt_48:write(48021,{Y,M,D,List2})
	end,
	lib_send:send_to_uid(PlayerId,Bin).

%%检查是否能离婚
check_can_divorce(Player,Type) ->
	Ms = 
		case Player#player.sex of
			1 ->
				ets:fun2ms(fun(M) when M#ets_marry.boy_id =:= Player#player.id -> M end);
			2 ->
				ets:fun2ms(fun(M) when M#ets_marry.girl_id =:= Player#player.id -> M end)
		end,
	%%2月7号0时0分0秒    1328544000
	Now = util:unixtime(),
	case Now < 1328544000 of
		true ->
			{false,68};
		false ->
			case ets:select(?ETS_MARRY,Ms) of
				[] ->
					{false,64};%%还未结婚
				[Marry | _Rets] ->
					M = get_self_marry(Marry,Player#player.id),
					case M#ets_marry.do_wedding of
						0 ->
							{false,65};%%还不是正式夫妻
						1 ->
							Mtime = M#ets_marry.marry_time,
							case round((Now-Mtime)/86400) < 3  of
								true -> 
									{false,67};   %%结婚未够三天
								false ->
									case M#ets_marry.divorce of
										1 ->
											{false,66};%% 还处于离婚期
										0 ->
											case Type of
												2 ->
													case goods_util:is_enough_money(Player, 100000, coin) of
														false ->
															{false,2}; %%铜币不足
														true ->
															{true,M}
													end;
												1 ->
													{true,M}
											end
									end
							end
					end
			end
	end.

%%获取自己的结婚记录，防止同节点下拿到另一方的数据
get_self_marry(M,PlayerId) ->
	{DbId,Id} = M#ets_marry.id,
	case PlayerId =:= Id of
		true ->
			M;
		false ->
			case ets:lookup(?ETS_MARRY,{DbId,PlayerId}) of
				[]->
					M;
				[Marry|_R] ->
					Marry
			end
	end.


%% int:8	部落类型
%% 	string	氏族名字
%% 	string	攻击者名字
%% 	int:32	PK的场景Id
%% 	int:32	PK坐标X
%% 	int:32	PK坐标Y
%% 	string	被攻击的氏族成员名字

cast_Der([Der,Aname,Aid]) ->
	case (Der#player.scene < 500 orelse Der#player.scene =:= 705) 
		andalso Der#player.scene =/= ?WEDDING_SCENE_ID
		andalso Der#player.scene =/= ?WEDDING_LOVE_SCENE_ID of
		true ->
			Pid = Der#player.other#player_other.pid,
			Pid ! {'call_help',[Der,Aname,Aid]};
		false ->
			skip
	end.

call_help([Der,Aname,Aid]) ->
	{Field,Ms} =
		case Der#player.sex of
			1 ->
				{boy,ets:fun2ms(fun(M) when M#ets_marry.boy_id =:= Der#player.id -> M end)};
			2 ->
				{girl,ets:fun2ms(fun(M) when M#ets_marry.girl_id =:= Der#player.id -> M end)}
		end,
	case ets:select(?ETS_MARRY, Ms) of
		[] ->
			skip;
		[M|_Rets] ->
			Marry = get_self_marry(M,Der#player.id),
			send_help(Marry,Field,Aid,[Aname,Der#player.scene,Der#player.x,Der#player.y,Field])
	end.

send_help(M,Filed,Aid,Data) ->
	Cid = 
		case Filed of
			boy ->
				M#ets_marry.girl_id;
			girl ->
				M#ets_marry.boy_id
		end,
	if Cid =:= Aid ->
		   skip;
	   true ->
		   case lib_player:get_player_pid(Cid) of
			   []->
				   skip;
			   Pid ->
				   Pid ! {'cuple_help',Data}
		   end
	end.

%%获取和更新玩家传送的坐标
get_cuple_pk_coord() ->
	case get(cuple_pk_coord) of
		List when is_list(List) ->
			List;
		_ ->
			[]
	end.

put_pk_coord({NowTime, SceneId, X, Y}) ->
	List = get_cuple_pk_coord(),
	%%过滤过期的数据
	FilteList = lists:foldl(fun(Elem, AccIn) ->
								  {ETime, _ESceneId, _EX, _EY} = Elem, 
								  Diff = NowTime - ETime,
								  case Diff > ?CUPLE_CALL_TIMELIMIT of
									  true ->
										 AccIn;
									  false ->
										  [Elem|AccIn]
								  end
						  end, [], List),
	NewList = [{NowTime, SceneId, X, Y}|FilteList],
	put(cuple_pk_coord, NewList).

%%离婚
%%玩家进程调用
divorce(Type,Player) ->
	case check_can_divorce(Player,Type) of
		{false,Code} ->
			{ok,Bin48019} = pt_48:write(48019,Code),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin48019),
			Player;
		{true,Marry} ->
			Rid = 
				case Player#player.sex of
					1 -> Marry#ets_marry.girl_id;
					2 -> Marry#ets_marry.boy_id
				end,
			%%清除Ets的marry
			{DbId,_D} = Marry#ets_marry.id,
			Now = util:unixtime(),
			ets:insert(?ETS_MARRY, Marry#ets_marry{divorce = 1, div_time = Now}),
			%%通知对方
			case lib_player:get_player_pid(Rid) of
				[]->
					skip;
				Rpid ->
					Rpid ! {'do_divorce',Marry#ets_marry.id,Type,Now}
			end,
			%%db
			db_agent:update_marry([{divorce,1},{div_time, Now}],[{id,DbId}]),
			%%发邮件通知
			send_divorce_mail(Player#player.nickname,Player#player.couple_name),
			%%清除任务
			pp_task:handle(30005, Player, [84010]),
			%%清除player身上的couple_name
			%%双方DB
			db_agent:update_cuple_name("",Marry#ets_marry.boy_id),
			db_agent:update_cuple_name("",Marry#ets_marry.girl_id),
			Player1 = Player#player{couple_name = ""},
			%%广播
			{ok,Data12075} = pt_12:write(12075,{Player#player.id,""}),
			%%场景广播
			mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, Data12075),
			%%扣除亲密度
			Player2 = 
				case Type of
					1 ->%%通过离婚协议书
						Player1;
					2 ->%%通过npc
						%%扣除亲密度，内存与DB都一起操作了
						lib_relationship:del_close(Player1#player.id,Rid,2000,48019),
						%%扣铜币
						lib_goods:cost_money(Player1, 100000, coin, 4819)
				end,
			spawn(fun()->db_agent:log_divorce(DbId,Player#player.id,Marry#ets_marry.boy_id,Marry#ets_marry.girl_id,Type,Now) end),
			lib_player:send_player_attribute(Player2,2),
			{ok,Bin48019} = pt_48:write(48019,1),
			lib_send:send_to_sid(Player2#player.other#player_other.pid_send, Bin48019),
			Player2
	end.
	

%%婚宴定时器经验
get_wedding_expspi(Lv,Type) ->
	BExp = 
		case Lv of
			30 -> 444;
			31 -> 579;
			32 -> 581;
			33 -> 633;
			34 -> 696;
			35 -> 707;
			36 -> 721;
			37 -> 773;
			38 -> 788;
			39 -> 823;
			40 -> 831;
			41 -> 858;
			42 -> 885;
			43 -> 899;
			44 -> 909;
			45 -> 1283;
			46 -> 1316;
			47 -> 1336;
			48 -> 1341;
			49 -> 1346;
			50 -> 2109;
			51 -> 2225;
			52 -> 2326;
			53 -> 2417;
			54 -> 2489;
			55 -> 2825;
			56 -> 2914;
			57 -> 3198;
			58 -> 3339;
			59 -> 3466;
			60 -> 3546;
			61 -> 3589;
			62 -> 3867;
			63 -> 3879;
			64 -> 4025;
			65 -> 4335;
			66 -> 4474;
			67 -> 4621;
			68 -> 4764;
			69 -> 4897;
			70 -> 4916;
			71 -> 5084;
			72 -> 5595;
			73 -> 5948;
			74 -> 5963;
			75 -> 5969;
			76 -> 5970;
			77 -> 5976;
			78 -> 6261;
			79 -> 6364;
			80 -> 6637;
			81 -> 6722;
			82 -> 6764;
			83 -> 6884;
			84 -> 6902;
			85 -> 6990;
			86 -> 7055;
			87 -> 7083;
			88 -> 7162;
			89 -> 7243;
			90 -> 7312;
			91 -> 7370;
			92 -> 7372;
			93 -> 7416;
			94 -> 7506;
			95 -> 7659;
			96 -> 7961;
			97 -> 8245;
			98 -> 8501;
			99 -> 8747;
			_ -> 00
		end,
	case Type of
		1 ->
			BExp;
		2 ->
			tool:ceil(1.2*BExp);
		3 ->
			tool:ceil(1.3*BExp);
		_-> 
			0
	end.

%%获取名字颜色
realm_color(Bid,Gid)->
	Br = 
		case db_agent:get_realm_by_id(Bid) of
			null -> 100;
			R ->
				R
		end,
	Gr = 
		case db_agent:get_realm_by_id(Gid) of
			null -> 100;
			R2 ->
				R2
		end,
	{data_agent:get_realm_color(Br),data_agent:get_realm_color(Gr)}.
	

%%10分钟一场婚宴，便于测试

%%9点开始，每10分钟一场，每场20分钟[{1,32400,33600},{2,34200,35400},{3,36000,36600},{4,37800,38400},{5,39000,40200},{6,40800,42000},{7,42600,43800},{8,44400,45600},{9,46200,47400},{10,48000,49200},
%% 			{11,49800,51000},{12,51600,52800},{13,52200,53400},{14,54000,55200},{15,55800,57000}];
get_wedding_time() ->
	[
			 {1,32400,33300},
			 {2,36000,36900},
			 {3,39600,40500},
			 {4,43200,44100},
			 {5,46800,47700},
			 {6,50400,51300},
			 {7,54000,54900},
			 {8,57600,58500},
			 {9,61200,62100},
			 {10,64800,65700},
			 {11,68400,69300},
			 {12,72000,72900},
			 {13,75600,76500},
			 {14,79200,80100},
			 {15,82800,83700}
	].
%%    make_test_time(35100,10*60,50,15*60).

%% 生成测试时间的函数(参数：第一场开始时间，一场持续的时间，一共有多少场，每场间隔多少时间) 单位:S
make_test_time(FirstBegin,HowLong,HowMany,InterVal) ->
	NumList = lists:seq(1,HowMany),
	F = fun(N)->
			N2 = N - 1,
			if N2 =:= 0 ->
				   {N,FirstBegin,FirstBegin+HowLong};
			   true ->
				   NextBegin = FirstBegin+ N2*InterVal,
				   NextEnd = NextBegin + HowLong,
				   {N, NextBegin, NextEnd}
			end
		end,
	[F(N) || N <- NumList].
  

	