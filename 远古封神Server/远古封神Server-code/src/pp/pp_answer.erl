%% Author: ygzj
%% Created: 2011-4-8
%% Description: 答题模块
-module(pp_answer).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").


%% 答题报名
handle(37001, PlayerStatus, _) ->
	Data = mod_answer:answer_join(PlayerStatus),
	Data;

%% 提交答题
handle(37004, PlayerStatus, [Order,BaseAnswerId,Opt,Tool,Reference_id]) ->
	Data = mod_answer:answer_commit(PlayerStatus,Order,BaseAnswerId,Opt,Tool,Reference_id),
	case Data =:= 1 orelse Data =:= 10 orelse Data =:= 11 of
		true ->
			lib_activity:update_activity_data(answer, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, 1);%%添加玩家活跃度统计
		false ->
			skip
	end,
	{ok, BinData} = pt_37:write(37004, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%% 退出答题活动
handle(37006, PlayerStatus, _) ->
	Data = mod_answer:answer_exit(PlayerStatus),
	{ok, BinData} = pt_37:write(37006, Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%% 重新登陆检查是否在答题时间内
handle(37008, PlayerStatus, _) ->
	mod_answer:check_answer_time_info(PlayerStatus).


