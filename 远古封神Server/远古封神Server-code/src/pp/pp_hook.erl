%%%--------------------------------------
%%% @Module  : pp_hook
%%% @Author  : ygzj
%%% @Created : 2010.10.07
%%% @Description: 挂机
%%%--------------------------------------

-module(pp_hook).
-export(
  	[
		handle/3
	]
).
-include("record.hrl").

%% 获取场景怪物
%% Status 玩家状态信息
%% Scene 场景ID
handle(26001, Player, SceneId) ->
    Minfo = lib_hook:get_scene_mon_info(SceneId),
    {ok, BinData} = pt_26:write(26001, [SceneId, Minfo]),    
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

%% 获取挂机面板信息
handle(26002, Player, _) ->
	HookConfig = tuple_to_list(get(hook_config)),
	[_ | Config] = HookConfig,
	{ok, BinData} = pt_26:write(26002, Config),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

%% 开始/停止挂机 
%% Sign 信号，1开始挂机，0停止挂机
handle(26003, Player, Sign) ->
	%% 竞技场不能挂机
	case lib_coliseum:is_coliseum_scene(Player#player.scene) of
		false ->
			[Result, Sta] = 
		        case Sign of
		            %% 开始挂机
		            1 ->
		                case lists:member(Player#player.status, [0, 2, 5]) of
							true ->
								[1, 5];
		                    false ->
								[2, Player#player.status]                        
		                end;
		            %% 停止挂机
		            _ ->	
		                %% 判断是否在挂机状态
		                case Player#player.status of 
							5 ->
								[0, 0];                    
		                    _ ->
								[2, Player#player.status]                        
		                end
		        end,
		    {ok, BinData} = pt_26:write(26003, [Result, Sta]),
		    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
			NewPlayer = Player#player{
				status = Sta
		    },
			List = [
				{status, Sta},
				{hook_pick, NewPlayer#player.other#player_other.hook_pick},
				{hook_equip_list, NewPlayer#player.other#player_other.hook_equip_list},
				{hook_quality_list, NewPlayer#player.other#player_other.hook_quality_list}
			],
			mod_player:save_online_info_fields(NewPlayer, List),
			{ok, change_status, NewPlayer};
		true ->
			skip
	end;

%% 保存挂机信息
%% Config 挂机信息
handle(26004, Player, Config) ->
	HookConfig = list_to_tuple([hook_config | Config]),
	put(hook_config, HookConfig),
	NewPlayer = Player#player{
		other = Player#player.other#player_other{
			hook_pick = HookConfig#hook_config.pick,
			hook_equip_list = HookConfig#hook_config.equip_list,
			hook_quality_list = HookConfig#hook_config.quality_list
		}
    },
	List = [
		{hook_pick, HookConfig#hook_config.pick},
		{hook_equip_list, HookConfig#hook_config.equip_list},
		{hook_quality_list, HookConfig#hook_config.quality_list}
	],
	mod_player:save_online_info_fields(NewPlayer, List),
	spawn(fun()->
		{ok, BinData} = pt_26:write(26004, 1),
    	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
		db_agent:update_hook_config(Player#player.id, HookConfig)
	end),
	{ok, change_status, NewPlayer};

%% 查询高级经验挂机时间
handle(26006, PlayerStatus, [])->
	case lib_hook:time_limit_msg() of
		0->skip;
		Timestamp->
			{ok, BinData} = pt_26:write(26006, [Timestamp]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end;

handle(_Cmd, _Status, _Data) ->
    {error, "pp_hook no match"}.
