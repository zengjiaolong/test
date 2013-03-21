%% Author: zj
%% Created: 2011-5-19
%% Description: TODO: Add description to lib_hack
-module(lib_hack).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-compile([export_all]).

%%
%% API Functions
%%
%%防外挂速度计算
speed_mark(Player,X,Y) ->
	case get(player_speed_mark) of
		undefined ->
			put(player_speed_mark,{Player#player.scene,X,Y,0});
		{OldScene,Ox,Oy,L} ->
			if
				OldScene /= Player#player.scene ->
					put(player_speed_mark,{Player#player.scene,X,Y,0});
				true ->
					if
						%%战场和神岛加速检测
						(Player#player.scene >= 600 andalso Player#player.scene < 700) orelse Player#player.scene == 520 ->
							Nl = round(math:sqrt(round(math:pow(abs(Ox - X)*2,2))+round(math:pow(abs(Oy - Y),2)))),
							put(player_speed_mark,{Player#player.scene,X,Y,L + Nl});
						true ->
							put(player_speed_mark,{Player#player.scene,X,Y,0})
					end
			end
	end.

%%
%%监控消息数量
socket_event_mark()->
	case get(socket_event_cout) of
		undefined ->
			put(socket_event_cout,1);
		Count ->
			put(socket_event_cout,Count+1)
	end.


%%重置速度
reset_speed_mark()->
	put(player_speed_mark,undefined),
	put(player_speed_mark_timer,undefined),
	ok.


%%检查

%%速度检查
check_speed_mark(Player) ->
	case get(player_speed_mark_timer) of
		undefined ->
			case get(player_speed_mark) of
				undefined ->
					put(player_speed_mark_timer,0),
					ok;
				{_OldScene,_Ox,_Oy,L} ->
					put(player_speed_mark_timer,L),
					ok
			end;
		Distance ->
			case get(player_speed_mark) of
				undefined ->
					put(player_speed_mark_timer,0),
					ok;
				{OldScene,_Ox,_Oy,L} ->
					if
						L > Distance  ->
							S = L - Distance;
						true ->
							S = 0
					end,
					%%?DEBUG("__________________________--S:~p",[S]),
					if
						%%战场 跑速 150下
						S > 150 andalso OldScene >= 600 andalso OldScene < 700 -> %%战场场景id >= 600 <700
							{ok, Bin} = pt_10:write(10007, 6),
							lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin),
							put(player_speed_mark_timer,L),
    						stop;
						%%空战 跑速 350 下 
						S > 265 andalso OldScene == 520 ->
							{ok, Bin} = pt_10:write(10007, 6),
							lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin),
							put(player_speed_mark_timer,L),
    						stop;
						true ->
							put(player_speed_mark_timer,L),
							ok
					end
						
			end
	end.	

%%socket数检查
check_socket_count(Player) ->
	case get(socket_event_cout) of
		undefined -> ok;
		Num ->
			if
				Num > 500 ->
					{ok, BinData} = pt_10:write(10007, 6),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
    				stop;
				true ->
					put(socket_event_cout,0),
					ok
			end
	end.
%%
%% Local Functions
%%

