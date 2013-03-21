%% Author: ygzj
%% Created: 2011-9-3
%% Description: 评价模块
-module(pp_appraise).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").


%% 查看玩家评价信息
handle(44000, PlayerStatus, Other_Id) ->
	Data = mod_appraise:get_adore(PlayerStatus#player.id, Other_Id),
	case Data == [] of
		true ->
			skip;
		false ->
			{ok, BinData} = pt_44:write(44000, Data),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;

%% 玩家评价
handle(44001, PlayerStatus, [Other_Id, Type]) ->
	{Flag, Bool} = lib_relationship:find_is_exists(PlayerStatus#player.id, Other_Id, 1),
	NewRela = ets:lookup(?ETS_RELA, Flag),
	Data = mod_appraise:adore(PlayerStatus, Other_Id, Type, {Flag, Bool},NewRela),
	case Data == [] of
		true -> skip;
		false ->
			Result = 
				case Data of
					[1,BSCB] ->
						lib_achieve_outline:player_adore(BSCB, Other_Id, Type),%%鄙视和崇拜的成就判断
						1;
					Other ->
						Other
				end,
			{ok, BinData} = pt_44:write(44001, [Result]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;

handle(_Cmd, _Status, _Data) ->
    {error, "pp_appraise no match"}.

