%%%--------------------------------------
%%% @Module  : pp_td
%%% @Author  : lzz
%%% @Created : 2011.05.05
%%% @Description:  塔防
%%%--------------------------------------
-module(pp_td).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%TD info
handle(43001, Status, _) ->
	gen_server:cast(Status#player.other#player_other.pid_dungeon, {'TD_HANDLER', Status#player.other#player_other.pid_send, 43001, td_info}),	
	ok;

%% 退出TD
handle(43002, Status, _) ->
	case catch gen_server:call(Status#player.other#player_other.pid_dungeon, {'TD_HANDLER', 43002, leave_td}) of
		{'EXIT', _} ->
			ok;
		error ->
			ok;
		Res ->
			pp_scene:handle(12030, Status, quit_td),
			case Res of
				{1, _Hor} ->
					%%结束退出，不需要特别处理
					ok;
				{0, _Hor} ->
					%%退出之后没有人了
					ok;
				{999, Hor, Att_num} ->
					Time = util:unixtime(),
					lib_td:set_td_single(0, Status#player.guild_name, Status#player.nickname, Status#player.career, Status#player.realm, Status#player.id, 0, 0, Hor),
					Exp = lib_td:get_exp(Hor, 999),
					Spr = round(Exp/2),
					Content = io_lib:format("镇妖台守护结束，击退~p波，共计获得~p经验，~p灵力和~p镇妖功勋。",[tool:to_list(Att_num),tool:to_list(Exp),tool:to_list(Spr),tool:to_list(Hor)]), 
					db_agent:insert_mail(1, Time, "系统", Status#player.id, "镇妖台守护记录", Content, 0, 0, 0, 0, 0),
					lib_mail:check_unread(Status#player.id),
					NewStatus = lib_player:add_exp(Status, Exp, Spr, 11),
					{ok, NewStatus};
				{998, Hor, Mgc_td, Att_num,Skip_att_num,Kill_p} ->
					if
						Skip_att_num == 0 orelse (Skip_att_num > 0 andalso Kill_p == 1) ->
							Time = util:unixtime(),
							Content = io_lib:format("镇妖台守护结束，击退~p波，共计获得~p镇妖功勋。",[tool:to_list(Att_num),tool:to_list(Hor)]), 
							db_agent:insert_mail(1, Time, "系统", Status#player.id, "镇妖台守护记录", Content, 0, 0, 0, 0, 0),
							lib_mail:check_unread(Status#player.id),
							lib_td:set_td_single(Att_num, Status#player.guild_name, Status#player.nickname, Status#player.career, Status#player.realm, Status#player.id, Hor, Mgc_td, Hor);
						true ->
							skip
					end,
					ok
			end
 		end;

%%护卫信息
handle(43004, Status, _) ->
	gen_server:cast(Status#player.other#player_other.pid_dungeon, {'TD_HANDLER', Status#player.other#player_other.pid_send, 43004, def_info}),	
	ok;

%%使用技能
handle(43005, Status, Def) ->
	if
		Status#player.other#player_other.leader =:= 1 orelse Status#player.scene rem 10000 =:= 998 ->
			case catch gen_server:call(Status#player.other#player_other.pid_dungeon, {'TD_HANDLER', 43005, Def}) of
				{'EXIT', _} ->
					ok;
				error ->
					ok;
				Res ->
					{ok, BinData} = pt_43:write(43005, Res),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok
 			end;
		true ->
			{ok, BinData} = pt_43:write(43005,[6 ,Def]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
end;

%%升级技能
handle(43006, Status, Def) ->
	if
		Status#player.other#player_other.leader =:= 1 orelse Status#player.scene rem 10000 =:= 998 ->
			case catch gen_server:call(Status#player.other#player_other.pid_dungeon, {'TD_HANDLER', 43006, Def}) of
				{'EXIT', _} ->
					ok;
				error ->
					ok;
				[1, _, _] ->
					ok;
				Res ->
					{ok, BinData} = pt_43:write(43006, Res),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok
 			end;
		true ->
			{ok, BinData} = pt_43:write(43006,[4, Def, 0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
end;

%%hor sum
handle(43007, Status, _) ->
	Hor_ttl = lib_td:get_hor_td(Status#player.id),
	{ok, BinData} = pt_43:write(43007, Hor_ttl),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);

%% 加速刷怪
handle(43008, Status, _) ->
	if
		Status#player.other#player_other.leader =:= 1 orelse Status#player.scene rem 10000 =:= 998 ->
			case catch gen_server:call(Status#player.other#player_other.pid_dungeon, {'TD_HANDLER', 43008, get_mon}) of
				{'EXIT', _} ->
					ok;
				error ->
					ok;
				Res ->
					{ok, BinData} = pt_43:write(43008, Res),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok
 			end;
		true ->
			{ok, BinData} = pt_43:write(43008, 3),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;

%%进入单人镇妖
handle(43009,Status,[StartAtt]) ->
	SkipAtt = StartAtt -1,
	SceneId = 998,
	case data_scene:get(SceneId) of
		[] ->
		 	 {ok, BinData} = pt_12:write(12005, [0, 0, 0, <<"场景数据不存在！">>, 0, 0, 0, 0]),
             lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		Scene ->
			case lib_scene:check_requirement(Status, Scene#ets_scene.requirement) of
				{false, Reason} -> 
						{ok, BinData} = pt_12:write(12005, [0, 0, 0, Reason, 0, 0, 0, 0]),
             	 		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
						ok;
				{true} ->
					 case lib_scene:check_enter_std(Status, SceneId, Scene ,SkipAtt) of
						 {false, _, _, _, Msg, _, _} ->
							  	{ok, BinData} = pt_12:write(12005, [0, 0, 0, Msg, 0, 0, 0, 0]),
                              	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
						 {true, NewSceneId, X, Y, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, Status1} ->
								lib_scene:set_hooking_state(Status,NewSceneId),
							  	%% 告诉原来场景玩家你已经离开
                            	pp_scene:handle(12004, Status, Status#player.scene),
								if
									SkipAtt > 1 ->
										%% 元宝变化
										lib_player:send_player_attribute2(Status1,1);
									true ->
										skip
								end,
							 	%% 告诉客户端新场景情况
                            	{ok, BinData} = pt_12:write(12005, [NewSceneId, X, Y, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, 0]),
                            	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
                            	Status2 = Status1#player{scene = NewSceneId, x = X, y = Y},
								{ok, change_ets_table, Status2}
						 end
				end
	end;

handle(_Cmd, _Socket, _Data) ->
    {error, "handletd no match"}.