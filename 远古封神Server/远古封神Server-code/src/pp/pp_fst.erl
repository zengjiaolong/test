%%%--------------------------------------
%%% @Module  : pp_fst
%%% @Author  : lzz
%%% @Created : 2011.02.24
%%% @Description:  封神台 && 封神纪元
%%%--------------------------------------
-module(pp_fst).
-export([handle/3]).
-include("record.hrl").

%% 登陆的时候在封神塔内
handle(35000, Status, _) ->
	case lib_scene:is_fst_scene(Status#player.scene) of
		true->
			Loc = Status#player.scene rem 100;
		false->
			Loc = Status#player.scene rem 100-45
	end,
	FstList = [
				Loc, 
				Status#player.other#player_other.fst_hor_ttl, 
				Status#player.other#player_other.fst_exp_ttl, 
				Status#player.other#player_other.fst_spr_ttl		   
			],
	{ok, BinData} =  pt_35:write(35000, FstList),
   	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
			  

%% 退出封神台(1成功退出，2系统繁忙，稍后重试)
handle(35001, Player, _) ->
	case is_pid(Player#player.other#player_other.pid_team) of
		true ->
			case catch gen_server:call(Player#player.other#player_other.pid_team, {'MEMBER_FST_QUIT',[Player#player.other#player_other.pid,Player#player.scene]}) of
				ok->
					case lib_scene:is_fst_scene(Player#player.scene) of
						true->
							Msg = io_lib:format("您的队友~s离开了封神台", [Player#player.nickname]);
						false->
							Msg = io_lib:format("您的队友~s离开了诛仙台", [Player#player.nickname])
					end,
					{ok, BinData} = pt_15:write(15055,[Msg]),
					gen_server:cast(Player#player.other#player_other.pid_team,
									{'SEND_TO_OTHER_MEMBER', Player#player.id, BinData}),
					RetPlayer = quit_fst(Player),
					{ok, change_status, RetPlayer};
				_Res->
					{ok,BinData1} = pt_35:write(35001,[2]),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData1),
					ok
			end;
		false ->
			RetPlayer = quit_fst(Player),
			{ok, change_status, RetPlayer}
			
	end;

%% 封神台霸主
handle(35002, Status, _) ->
	case lib_scene:is_fst_scene(Status#player.scene) of
		true->
			Loc = Status#player.scene rem 100,
			case Loc rem 2 of
				0 ->
					Gods = db_agent:get_fst_god(Loc, 5),
					case length(Gods) of
						0 ->
							ok;
						_ ->
							{ok, BinData} =  pt_35:write(35002, Gods),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
					end;
				_ ->
					ok
			end;
		false->%%诛仙台霸主
			Loc = Status#player.scene rem 100-45,
			case Loc rem 3 of
				0 ->
					Gods = db_agent:get_zxt_god(Loc, 5),
					case length(Gods) of
						0 ->
							ok;
						_ ->
							{ok, BinData} =  pt_35:write(35002, Gods),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
					end;
				_ ->
					ok
			end
	end;

%% 封神台跳层
handle(35003, Status, [Loc]) ->
	[JumpRes, Gold] =
		case lists:member(Loc, [6,12,18]) of
			true ->
				Cost = Loc * 10 div 6,
				case goods_util:is_enough_money(Status, Cost, gold) of
					false ->
						[1, Cost];
					true ->
						[10, Cost]
				end;
			false ->
				[0, 0]
		end,
	case JumpRes of
		10 ->
			SceneId = Loc + 1000,
			%% 封神台次数判断
			{_NewPlayerStatus, _, AwardTimes} = lib_vip:get_vip_award(fst, Status),
			case lib_dungeon:check_dungeon_times(Status#player.id, 1001, 3+AwardTimes) of
				{fail,_}->
					{ok, BinData} = pt_35:write(35003, [3, Status#player.gold]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
				{pass, _Counter}->
					case pp_scene:handle(12005, Status, SceneId) of
						{ok, change_ets_table, Status2} ->
							NewStatus = lib_goods:cost_money(Status2, Gold, gold, 3533),
							{ok, BinData} = pt_35:write(35003, [2, NewStatus#player.gold]),
    						lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData),
%% 							lib_dungeon:add_dungeon_times(NewStatus#player.id, 1001),
							{ok, change_ets_table, NewStatus};
						_ ->
							skip
					end
			end;	  
		_ ->
			{ok, BinData} = pt_35:write(35003, [JumpRes, Status#player.gold]),
    		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
	end;


%% %% 登陆的时候在诛仙台内
%% handle(35004, Status, _) ->
%% 	Loc = Status#player.scene rem 100,
%% 	FstList = [
%% 		Loc, 
%% 		Status#player.other#player_other.zxt_hor_ttl, 
%% 		Status#player.other#player_other.zxt_exp_ttl, 
%% 		Status#player.other#player_other.zxt_spr_ttl		   
%% 	],
%% 	{ok, BinData} =  pt_35:write(35004, FstList),
%%     lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
%% 
%% %% 退出诛仙台
%% handle(35005, Status, _) ->
%% 	case is_pid(Status#player.other#player_other.pid_team) of
%% 		true ->
%% 			Msg = io_lib:format("您的队友~s离开了诛仙台", [Status#player.nickname]),
%% 			{ok, BinData} = pt_15:write(15055,[Msg]),
%% 			gen_server:cast(Status#player.other#player_other.pid_team,
%% 								{'SEND_TO_OTHER_MEMBER', Status#player.id, BinData}),
%% 			gen_server:cast(Status#player.other#player_other.pid_team, {'MEMBER_ZXT_QUIT'});
%% 		false ->
%% 			skip
%% 	end,
%% 	lib_scene_zxt:quit_zxt(Status);
%% 
%% %% 诛仙台霸主
%% handle(35006, Status, _) ->
%% 	Loc = Status#player.scene rem 100,
%% 	case Loc rem 3 of
%% 		0 ->
%% 			Gods = db_agent:get_zxt_god(Loc, 5),
%% 			case length(Gods) of
%% 				0 ->
%% 					ok;
%% 				_ ->
%% 					{ok, BinData} =  pt_35:write(35002, Gods),
%% 					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
%% 			end;
%% 		_ ->
%% 			ok
%% 	end;



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%封神纪元%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 封神纪元tooltip显示
handle(35010,Status,[PlayerId]) ->
	Data = lib_era:get_player_era_tooltip(Status,PlayerId),
	{ok,BinData} = pt_35:write(35010, Data),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%%封神纪元通关信息
handle(35011,Status,[PlayerId,Stage]) ->
	case lib_era:get_player_era_stage_info(Status,PlayerId,Stage) of
		[] ->
			ok;
		Data ->
			{ok,BinData} = pt_35:write(35011, Data),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;

%%封神纪元通关奖励领取
handle(35014,Status,[Stage,Level]) ->
	[NewStatus,Data] = 
		case lib_war:is_war_server() of
			false->
				lib_era:get_player_era_prize(Status,Stage,Level);
			true->
				[Status,[Stage,Level,5]]
		end,
	{ok,BinData} = pt_35:write(35014, Data),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	{ok,NewStatus};
%%
handle(_Cmd, _Status, _Data) ->
%%     ?DEBUG("pp_fst no match", []),
    {error, "pp_fst no match"}.

%%退出封神台处理
quit_fst(Player)->
	NewPlayer = lib_scene_fst:quit_fst(Player),
	%% 去除副本BUFF
	Buff = NewPlayer#player.other#player_other.battle_status,
	RetBuff = 
		case lists:keyfind(last_zone_def, 1, Buff) of
			false ->
				case lists:keyfind(last_zone_att, 1, Buff) of
					false ->
						Buff;
					_ ->
						NewBuff = lists:keydelete(last_zone_att, 1, Buff),
						Now = util:unixtime(),
						lib_player:refresh_player_buff(NewPlayer#player.other#player_other.pid_send, NewBuff, Now),
						NewBuff
				end;
			_ ->
				NewBuff = lists:keydelete(last_zone_def, 1, Buff),
				Now = util:unixtime(),
				lib_player:refresh_player_buff(NewPlayer#player.other#player_other.pid_send, NewBuff, Now),
				NewBuff
		end,
	RetPlayer = NewPlayer#player{
		other = NewPlayer#player.other#player_other{
			battle_status = RetBuff
		}
	},
	List = [
		{exp, RetPlayer#player.exp},
		{spirit, RetPlayer#player.spirit},
		{honor, RetPlayer#player.honor},
		{fst_exp_ttl, RetPlayer#player.other#player_other.fst_exp_ttl}, 
		{fst_spr_ttl, RetPlayer#player.other#player_other.fst_spr_ttl}, 
		{fst_hor_ttl, RetPlayer#player.other#player_other.fst_hor_ttl},
		{battle_status, RetBuff}
	],
	mod_player:save_online_info_fields(RetPlayer, List),
	RetPlayer.