%%%--------------------------------------
%%% @Module  : pp_ore
%%% @Author  : zj
%%% @Created : 2011.03.01
%%% @Description: 天降彩石 
%%%--------------------------------------
-module(pp_ore).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%=========================================================================
%% 接口函数 
%%=========================================================================

%% -----------------------------------------------------------------
%% 获取挖矿倒计时
%% -----------------------------------------------------------------
handle(36000, Status,_R) ->
	OreSup = mod_ore_sup:get_mod_ore_pid(),
	Pidsend = Status#player.other#player_other.pid_send,
   	gen_server:cast(OreSup,{'ore_running_time',Pidsend}),
    ok;

%% -----------------------------------------------------------------
%% 挖矿状态切换 场景广播
%% -----------------------------------------------------------------
handle(36001,Status,[State]) ->
	case lib_ore:check_ore_dig_limit(Status) of
		true ->
			%%取消坐骑状态
			{ok, Status1} = lib_goods:force_off_mount(Status),
			 %% 从打坐状态恢复正常状态
			{ok, Status2} =
                case Status1#player.status of
                    6 ->
                        lib_player:cancelSitStatus(Status1);
                    _ ->
                        {ok, Status1}
                end,
			{ok,BinData} = pt_36:write(36001,[1,State,Status2#player.id]),
			mod_scene_agent:send_to_area_scene(Status2#player.scene,Status2#player.x,Status2#player.y,BinData),
			case State of
				0 -> 
					put(ore_first_time,undefined),					
					OreSup = mod_ore_sup:get_mod_ore_pid(),
					gen_server:cast(OreSup,{'out_ore_dig',Status2#player.id}),
					NewStatus = Status2#player{status = 0};
				1 ->
					put(ore_first_time,true),
					NewStatus = Status2#player{status = 8};
				_ -> 
					NewStatus = Status2#player{status = 0}
			end,	
			{ok,NewStatus};
		Ret ->
			?DEBUG("_____________________CHECK_ORE_DIG_LIMIT~p",[Ret]),
			{ok,BinData} = pt_36:write(36001,[Ret,State,Status#player.id]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;

%% -----------------------------------------------------------------
%% 挖矿请求
%% -----------------------------------------------------------------
handle(36002,Status,_R) ->
	case lib_ore:check_ore_dig_request() of
		true ->
			case lib_ore:check_ratio(Status)  of
				true ->
					put(ore_first_time,undefined),
					%%添加采矿参与度
					case get(join_play_ore) of
						undefined ->
							db_agent:update_join_data(Status#player.id, orc),
							put(join_play_ore,played);
						_ ->
							skip
					end,
					%%所有条件符合，发起一次请求
					OreSup = mod_ore_sup:get_mod_ore_pid(),
%%					?DEBUG("_______________36002____pid~p",[OreSup]),
					S = Status#player.status,
					Player_id = Status#player.id,
					Nickname =  Status#player.nickname,
					Pidsend = Status#player.other#player_other.pid_send,
					Pid_goods = Status#player.other#player_other.pid_goods,
					Scene = Status#player.scene,
					X = Status#player.x,
					Y = Status#player.y,
					gen_server:cast(OreSup,{'routing',Player_id,Nickname,Pidsend,Pid_goods,Scene,X,Y,S});
				false ->
					skip
			end,
			{ok,BinData} = pt_36:write(36002,[1,Status#player.status]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		false ->
			{ok,BinData} = pt_36:write(36002,[0,Status#player.status]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
	end,
	ok;

%% -----------------------------------------------------------------
%% 切换回正常状态
%% -----------------------------------------------------------------
handle(36004,Status,_R) ->
	NewStatus = Status#player{status = 0},
	{ok,NewStatus};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_pet no match", []),
    {error, "pp_pet no match"}.



