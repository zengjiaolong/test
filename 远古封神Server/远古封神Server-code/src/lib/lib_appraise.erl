%% Author: ygzj
%% Created: 2011-9-2
%% Description: 评价模块
-module(lib_appraise).
-compile(export_all).
%%
%% Exported Functions
%%
-export([
	init_data/0,
	get_ets_appraise/0,
	get_adore/2,
	get_multi/1,
	get_adore_twice/1,
	get_max_appraise/2,
	achieve_get_adore/1,	%%成就系统使用的获取玩家的被鄙视和崇拜次数
	get_all_max_appraise/0	%%排行一次性获取崇拜和鄙视最多
]).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("achieve.hrl").

%% @doc 创建评价ets
init_data() ->
	Data = db_agent:load_appraise_data(),
	case Data of
		[] -> skip;
		_ ->
			F = fun([Id,Owner_id,Other_id,Type,Adore_num,Handle_num,Ct]) ->
				Ets_appraise = #ets_appraise{
					id = Id,
      				owner_id = Owner_id,       
	  				other_id = Other_id,
					type = Type,
					adore_num = Adore_num,
					handle_num = Handle_num,
					ct = Ct	
				},
				ets:insert(?ETS_APPRAISE,Ets_appraise)
			end,
			[F(Appraise) || Appraise <- Data]
	end.
	
%%查询ets_appraise
get_ets_appraise() ->
	Ets_appraiseList = ets:match(?ETS_APPRAISE,_='$1'),
	Ets_appraiseList.

%%评价
adore(Player, OtherId, Type, {Flag, Bool},NewRela)  ->
	 Now = util:unixtime(),
	 {Today, NextDay} = util:get_midnight_seconds(Now),
	 %%当天对某玩家的评价
	 MS = ets:fun2ms(fun(T) when T#ets_appraise.owner_id == Player#player.id andalso T#ets_appraise.other_id == OtherId andalso T#ets_appraise.ct >= Today andalso T#ets_appraise.ct =< NextDay ->	T end),
	 List = ets:select(?ETS_APPRAISE, MS),
	 %%本人一天的所有对别人的评价
	 MS1 = ets:fun2ms(fun(T) when T#ets_appraise.owner_id == Player#player.id andalso T#ets_appraise.other_id =/= 0 andalso T#ets_appraise.ct >= Today andalso T#ets_appraise.ct =< NextDay -> T end),
	 List1 = ets:select(?ETS_APPRAISE, MS1),
	 Adore_Num = length(List1),
	 if
		 Player#player.lv < 30 ->
			 2; %%您等级不够，只有30级以上才能评价
		 List =/= [] ->
			 3; %%对同一玩家每天只能评价一次 
		 Adore_Num >= ?ADORE_TWICE ->
			 4; %%超过每天允许评价次数(10) 
		 Player#player.id == OtherId ->
			 5;%%不能评价自己
		 true ->
			Id = db_agent:insert_appraise(Player#player.id,OtherId,Type,0,0,Now),
			Ets_appraise = #ets_appraise{
					id = Id,
      				owner_id = Player#player.id,       
	  				other_id = OtherId,
					type = Type,
					adore_num = 0,
					handle_num = 0,
					ct = Now	
				},
			ets:insert(?ETS_APPRAISE,Ets_appraise),
			%%更新被评价人的被崇拜的次数
			MS2 = ets:fun2ms(fun(T) when T#ets_appraise.owner_id == OtherId andalso T#ets_appraise.other_id == 0 -> T end),
			List2 = ets:select(?ETS_APPRAISE, MS2),
			OtherData = lib_player:get_online_info(OtherId),
			OtherPlayerStatus = 
				case OtherData == [] of
					true -> [];
					false -> OtherData
				end,
			%%如果是好友被崇拜则添加亲密度
			add_appraise_close(Player,OtherPlayerStatus,OtherId,Type,{Flag, Bool},NewRela),
			%%更新被评价人的被崇拜的次数
			case  List2 of
				[] ->
					Id3 = db_agent:insert_appraise(OtherId,0,0,1,0,Now),
					Ets_appraise3 = #ets_appraise{
						id = Id3,
      					owner_id = OtherId,       
	  					other_id = 0,
						type = 0,
						adore_num = 1,
						handle_num = 0,
						ct = Now	
					},
					ets:insert(?ETS_APPRAISE,Ets_appraise3);
				_ ->
					%%被评价人有原始记录，则更新相应的ets和数据库记录
					Ets_appraise3 = lists:nth(1, List2),
					Adore_num3 = Ets_appraise3#ets_appraise.adore_num+1,
					Handle_num3 = Ets_appraise3#ets_appraise.handle_num,
					%%计算魅力值
					Love_Value = trunc((Adore_num3 - Handle_num3) / 20),
					Id3 = Ets_appraise3#ets_appraise.id,
					db_agent:update_appraise(Adore_num3,Handle_num3,Now,Id3),
					Ets_appraise4 = Ets_appraise3#ets_appraise{
						adore_num = Adore_num3,
						handle_num = Handle_num3+Love_Value*20,
						ct = Now	
						},
					%%处理被评价玩家的魅力值，每达到20增加一点魅力值
					if
						Love_Value >= 1 ->
							case OtherPlayerStatus of
								[] -> 
									%% 不在线直接更新数据库
									db_agent:update_charm_add(OtherId, Love_Value);
								_ -> 
									%% 人物在线则从ETS表中取数据
									gen_server:cast(OtherPlayerStatus#player.other#player_other.pid,{'add_charm',Love_Value})
							end,
							spawn(fun()->db_agent:log_charm([OtherId,2,0,0,Love_Value,util:unixtime()])end),
							ok;
						true ->
							skip
					 end,
					ets:insert(?ETS_APPRAISE,Ets_appraise4)
			end,
			send_sys_msg(Player,OtherPlayerStatus,OtherId,Type),
			[BS,CB] = achieve_get_adore(OtherId),
			[1,[BS,CB]]
	 end.

%%添加评价好友亲蜜度
add_appraise_close(Player,OtherPlayerStatus,OtherId,Type,{Flag, Bool},Rela) ->
	Appraise_Close = 10,
	if
		Bool ==  true ->
			if
				Type == 2 ->
					%%双方都在线
					{DbId,_,1} = Flag,
					[NewRela] = Rela,
%% 				[NewRela] = ets:lookup(?ETS_RELA, Flag),
					case OtherPlayerStatus of
						[] ->
							%% 不在线只更新好友中自己的ets
							Player#player.other#player_other.pid ! ({'SET_CLOSE', [{DbId,Player#player.id,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close+Appraise_Close]}),
							spawn(fun()->db_agent:update_close(DbId,NewRela#ets_rela.close+Appraise_Close,NewRela#ets_rela.pk_mon,NewRela#ets_rela.timestamp) end);
						_ ->
							%% 对方在线更新双方好友的ets
							%% 人物在线则从ETS表中取数据
							Player#player.other#player_other.pid ! ({'SET_CLOSE', [{DbId,Player#player.id,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close+Appraise_Close]}),
							OtherPlayerStatus#player.other#player_other.pid ! ({'SET_CLOSE', [{DbId,OtherId,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close+Appraise_Close]}),
							spawn(fun()->db_agent:update_close(DbId,NewRela#ets_rela.close+Appraise_Close,NewRela#ets_rela.pk_mon,NewRela#ets_rela.timestamp) end)
					end;
				true ->
					skip
			end;
		true ->
			skip
	end.
	

%%发送系统消息
send_sys_msg(Player,OtherPlayerStatus,OtherId,Type) ->
	%%性别
	[Sex1,Nickname,Career1] = [Player#player.sex,Player#player.nickname,Player#player.career],	
	[Sex2,OtherNickname,Career2] =
		case OtherPlayerStatus of
			[] ->
				OtherPlayerInfo = db_agent:get_player_mult_properties([nickname,career,sex],[OtherId]),
				if OtherPlayerInfo == [] ->
					   skip;
				   true ->
					   [{_Key,[OtherNickname3,Career3,Sex3]}] = OtherPlayerInfo,
					   [Sex3,OtherNickname3,Career3]
				end;
			_ ->
				[OtherPlayerStatus#player.sex,OtherPlayerStatus#player.nickname,OtherPlayerStatus#player.career]
		end,
	if
		%%性别相同
		Sex1 == Sex2 ->
			if
				Type == 2 ->
					Content1 = io_lib:format("【你看到[<a href='event:1,~p, ~s, ~p, ~p'><font color='#FEDB4F'><u>~s</u></font></a>]一身威风凛凛的装备，顷刻间敬仰之情如滔滔江水连绵不断。】",[OtherId,tool:to_list(OtherNickname),Career2,Sex2,tool:to_list(OtherNickname)]),
					Content2 = io_lib:format("【[<a href='event:1,~p, ~s, ~p, ~p'><font color='#FEDB4F'><u>~s</u></font></a>]看到你一身威风凛凛的装备，顷刻间敬仰之情如滔滔江水连绵不断。】",[Player#player.id,tool:to_list(Nickname),Career1,Sex1,tool:to_list(Nickname)]),
					%%发送系统消息
					{ok, BinData} = pt_11:write(11080, 2, Content1),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					case OtherPlayerStatus  of
						[] ->
							skip;
						_ ->
							{ok, BinData1} = pt_11:write(11080, 2, Content2),
							lib_send:send_to_sid(OtherPlayerStatus#player.other#player_other.pid_send, BinData1)
					end;
				Type == 3 ->
					Content1 = io_lib:format("【你用鄙夷的目光扫视[<a href='event:1,~p, ~s, ~p, ~p'><font color='#FEDB4F'><u>~s</u></font></a>]，面上流露不屑的神态。】",[OtherId,tool:to_list(OtherNickname),Career2,Sex2,tool:to_list(OtherNickname)]),
					Content2 = io_lib:format("【[<a href='event:1,~p, ~s, ~p, ~p'><font color='#FEDB4F'><u>~s</u></font></a>]用鄙夷的目光扫视你，面上流露不屑的神态。】",[Player#player.id,tool:to_list(Nickname),Career1,Sex1,tool:to_list(Nickname)]),
					%%发送系统消息
					{ok, BinData} = pt_11:write(11080, 2, Content1),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					case OtherPlayerStatus of
						[] ->
							skip;
						_ ->
							{ok, BinData1} = pt_11:write(11080, 2, Content2),
							lib_send:send_to_sid(OtherPlayerStatus#player.other#player_other.pid_send, BinData1)
					end;
				true ->
					skip
			end;
		%%性别不同
		true ->
			if
				Type == 2 ->
					Content1 = io_lib:format("【你用含情脉脉的眼光看着[<a href='event:1,~p, ~s, ~p, ~p'><font color='#FEDB4F'><u>~s</u></font></a>]，暗暗露出仰慕之情。】",[OtherId,tool:to_list(OtherNickname),Career2,Sex2,tool:to_list(OtherNickname)]),
					Content2 = io_lib:format("【[<a href='event:1,~p, ~s, ~p, ~p'><font color='#FEDB4F'><u>~s</u></font></a>]用含情脉脉的眼光看着你，暗暗露出仰慕之情。】",[Player#player.id,tool:to_list(Nickname),Career1,Sex1,tool:to_list(Nickname)]),
					%%发送系统消息
					{ok, BinData} = pt_11:write(11080, 2, Content1),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					case OtherPlayerStatus of
						[] ->
							skip;
						_ ->
							{ok, BinData1} = pt_11:write(11080, 2, Content2),
							lib_send:send_to_sid(OtherPlayerStatus#player.other#player_other.pid_send, BinData1)
					end;
				Type == 3 ->
					Content1 = io_lib:format("【你用鄙夷的目光扫视[<a href='event:1,~p, ~s, ~p, ~p'><font color='#FEDB4F'><u>~s</u></font></a>]，面上流露不屑的神态。】",[OtherId,tool:to_list(OtherNickname),Career2,Sex2,tool:to_list(OtherNickname)]),
					Content2 = io_lib:format("【[<a href='event:1,~p, ~s, ~p, ~p'><font color='#FEDB4F'><u>~s</u></font></a>]用鄙夷的目光扫视你，面上流露不屑的神态。】",[Player#player.id,tool:to_list(Nickname),Career1,Sex1,tool:to_list(Nickname)]),
					%%发送系统消息
					{ok, BinData} = pt_11:write(11080, 2, Content1),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					case OtherPlayerStatus of
						[] ->
							skip;
						_ ->
							{ok, BinData1} = pt_11:write(11080, 2, Content2),
							lib_send:send_to_sid(OtherPlayerStatus#player.other#player_other.pid_send, BinData1)
					end;
				true ->
					skip
			end
	end.


%%玩家评价信息(打开界面返回相应的数据)
get_adore(Player_Id, OtherId) ->
	Ets_Appraise_List = ets:match_object(?ETS_APPRAISE, #ets_appraise{other_id = OtherId,_ = '_'}), 
	%%查询玩家被崇拜的次数
	Type1Num = get_adore_num(Ets_Appraise_List, 2),
	%%查询玩家被鄙视的次数
	Type2Num = get_adore_num(Ets_Appraise_List, 3),
	%%查找粉丝信息
	[Fans_Id,Nickname,Level,Career,Sex] = get_fans(Ets_Appraise_List),
	%%查询自己剩下的评价次数
	Remain_Twice = ?ADORE_TWICE - get_adore_twice(Player_Id),
	[Type1Num, Type2Num, Nickname, Remain_Twice, Fans_Id, Level, Career, Sex].

%%查询玩家被崇拜和被鄙视的次数
get_adore_num(Ets_Appraise_List,Type) ->
	case Ets_Appraise_List of
		[] -> 
			0;
		_ -> 
			L = [Ets_Appraise|| Ets_Appraise <- Ets_Appraise_List, Ets_Appraise#ets_appraise.type == Type],
			length(L)
	end.
	
%%成就系统使用的获取玩家的被鄙视和崇拜次数
achieve_get_adore(PlayerId) ->
	Ets_Appraise_List = ets:match_object(?ETS_APPRAISE, #ets_appraise{other_id = PlayerId,_ = '_'}), 
    if Ets_Appraise_List == [] ->
		   [0,0];
	   true ->
		   %%查询玩家被崇拜的次数
		   Type1Num = get_adore_num(Ets_Appraise_List, 2),
		   %%查询玩家被鄙视的次数
		   Type2Num = get_adore_num(Ets_Appraise_List, 3),
		   [Type2Num, Type1Num]
	end.

%%查找粉丝
get_fans(Ets_Appraise_List) ->
	case Ets_Appraise_List of
		[] -> 
			[0,<<>>,0,0,0]; 
		_ ->
			List = [{Ets_Appraise#ets_appraise.owner_id,Ets_Appraise#ets_appraise.ct} || Ets_Appraise <- Ets_Appraise_List, Ets_Appraise#ets_appraise.type == 2],
			Player_Id = get_multi(List),
			case Player_Id of
				[] -> [0,<<>>,0,0,0];
				_ ->
					case ets:lookup(?ETS_ONLINE, Player_Id) of
						[] ->
							case mod_cache:get({lib_appraise,get_fans,Player_Id}) of
								[] ->
									%% 不在线要从数据库中取数据
									[{_Key,[_Id,Nickname,Lv,Career,Sex]}] = db_agent:get_player_mult_properties([id,nickname,lv,career,sex],[Player_Id]),
									mod_cache:set({lib_appraise,get_fans,Player_Id},[Player_Id,Nickname,Lv,Career,Sex],3600),
									[Player_Id,Nickname,Lv,Career,Sex];
								CacheData ->
									CacheData
							end;
						[Player] ->       %% 人物在线则从ETS表中取数据
							[Player_Id,Player#player.nickname,Player#player.lv,Player#player.career,Player#player.sex]
					end
			end
	end.

%%查询集合中重复元素及出现的次数
get_multi(List) ->
	case List of
		[] -> [];
		_ ->
			ResultList = get_multi([{Player_Id,[Ct,1]} || {Player_Id,Ct} <- List], []),
			ResultList1 = lists:sort(fun({_Player_Id1, [Ct1, Num1]},{_Player_Id2, [Ct2, Num2]}) -> 
						   if Num1 =/= Num2 -> 
								  Num1 > Num2; 
							  true -> 
								  Ct1 < Ct2 
						   end 
				   end ,
				   ResultList),
			{Player_Id3, [_Ct, _Num]} = lists:nth(1,ResultList1),
			Player_Id3
	end.

get_multi([], ResulitList) ->
	ResulitList;
get_multi([{H,[Ct,Num]} | Rest], ResulitList) ->
	case lists:keyfind(H, 1, ResulitList) of
		false ->
			get_multi(Rest, [{H,[Ct,Num]}|ResulitList]); 
		{H,[Ct1,Num1]} ->
			get_multi(Rest, lists:keyreplace(H, 1, ResulitList, {H,[Ct1,Num1+Num]})) 
	end.

%%查找当前用户当天的评论次数
get_adore_twice(Player_Id) ->
	 Now = util:unixtime(),
	 {Today, NextDay} = util:get_midnight_seconds(Now),
	 MS = ets:fun2ms(fun(T) when T#ets_appraise.owner_id == Player_Id andalso T#ets_appraise.other_id =/= 0 andalso T#ets_appraise.ct >= Today andalso T#ets_appraise.ct =< NextDay ->	
							 T 
					 		end),
	 List = ets:select(?ETS_APPRAISE, MS),
	 length(List).

%%查找最终粉丝(type=2崇拜次数最多最早的,type=3鄙视次数最多最早的那位),并且返回 次数超过Limit值的名单
get_max_appraise(Type, Limit) ->
	 MS = ets:fun2ms(fun(T) when T#ets_appraise.other_id =/= 0 andalso T#ets_appraise.type == Type ->	
							 T 
					 		end),
	 List = ets:select(?ETS_APPRAISE, MS),
	 case List of
		 [] ->
			 [];
		 _ ->
			 List1= [{Ets_Appraise#ets_appraise.other_id,[1,1]} || Ets_Appraise <- List],
			 ResultList = get_multi(List1, []),
			 ResultList1 = lists:sort(fun({_Player_Id1, [Ct1, Num1]},{_Player_Id2, [Ct2, Num2]}) -> 
						   if Num1 =/= Num2 -> 
								  Num1 > Num2;
							  true -> 
								  Ct1 < Ct2 
						   end 
				   end ,
				   ResultList),
			 {_Player_Id1, [_Ct, Num]} = lists:nth(1,ResultList1),
			 case Num >= Limit of
				 true ->
					 ResultList2 = [Player_Id2 || {Player_Id2, [_Ct2, Num2]} <- ResultList1,Num2 == Num],
					 ResultList2;
				 false ->
					 []
			 end
	 end.

%%排行一次性获取崇拜和鄙视最多
get_all_max_appraise() ->
	{get_max_appraise(2, ?ADORE_DISDAIN_LIMIT), get_max_appraise(3, ?ADORE_DISDAIN_LIMIT)}.
