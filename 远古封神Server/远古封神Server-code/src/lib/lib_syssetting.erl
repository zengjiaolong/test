%% Author: xiaomai
%% Created: 2010-12-27
%% Description: 玩家游戏系统配置
-module(lib_syssetting).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%%
%% Exported Functions
%%
-export([get_player_sys_setting_info/0,		%% 34000 读取设置信息
		 set_player_sys_setting_info/2,		%% 34001 保存设置信息
		 init_player_sys_setting_info/1,	%% 玩家初始化时，初始化游戏系统配置
%%  ========================= 对外提供的获取状态的接口 ========================
		 get_player_sys_setting/1,			%%获取玩家单个的系统配置
		 get_player_sys_setting/2,			%%远程调用获取玩家单个的系统配置
		query_player_sys_setting/1
%%  =========================================================================
		]).

%%
%% API Functions
%%


%% %% -----------------------------------------------------------------
%% %% 玩家初始化时，初始化游戏系统配置
%% %% -----------------------------------------------------------------
init_player_sys_setting_info(PlayerId) ->
	{Type, PlayerSysSet} = get_player_sys_settings(PlayerId),
	%%初始化，写进程字典
	init_player_sys_setting_record(PlayerSysSet),
	%%做标识
	update_player_sys_setting(sys_setting_type, Type).

%%获取玩家游戏的系统配置
get_player_sys_settings(PlayerId) ->
	case db_agent:get_player_sys_settings(PlayerId) of
		[] ->%%数据库没记录，玩家没有做过系统配置，直接赋予默认值
			PlayerSysSet = #player_sys_setting{player_id = PlayerId,
											   shield_role = 0,
											   shield_skill = 0, 
											   shield_rela = 0,
											   shield_team = 0, 
											   shield_chat = 0, 
											   music = 50,
											   soundeffect = 50,
											   fasheffect = 0,
											   smelt = 0},
			{0, PlayerSysSet};
		PlayerSysSetList ->
			PlayerSysSet = list_to_tuple([player_sys_setting] ++ PlayerSysSetList),
			{1, PlayerSysSet}
	end.
	
init_player_sys_setting_record(PlayerSysSet) ->
	update_player_sys_setting(shield_role, PlayerSysSet#player_sys_setting.shield_role),
	update_player_sys_setting(shield_skill, PlayerSysSet#player_sys_setting.shield_skill),
	update_player_sys_setting(shield_rela, PlayerSysSet#player_sys_setting.shield_rela),
	update_player_sys_setting(shield_team, PlayerSysSet#player_sys_setting.shield_team),
	update_player_sys_setting(shield_chat, PlayerSysSet#player_sys_setting.shield_chat),
	update_player_sys_setting(music, PlayerSysSet#player_sys_setting.music),
	update_player_sys_setting(soundeffect, PlayerSysSet#player_sys_setting.soundeffect),
	update_player_sys_setting(fasheffect, PlayerSysSet#player_sys_setting.fasheffect),
	update_player_sys_setting(smelt, PlayerSysSet#player_sys_setting.smelt).

%%更新玩家单个的系统配置
update_player_sys_setting(Type, Result) ->
	put(Type, Result).
%%获取玩家单个的系统配置
get_player_sys_setting(Type) ->
	case get(Type) of
		undefined ->
			case Type of
				music ->%%音乐，默认为50
					50;
				soundeffect -> %%音效，默认为50
					50;
				_ ->
					0
			end;
		Value ->
			Value
	end.
%%远程调用获取玩家单个的系统配置
get_player_sys_setting(PlayerPid, Type)->
	gen_server:call(PlayerPid, {'get_player_sys_setting', Type}).

%%获取玩家单个的系统配置
query_player_sys_setting(PlayerId)->
	Data = db_agent:get_player_sys_settings(PlayerId),
	case Data == [] of
		true ->
			[0,0,0,0,0,0,50,50,0,0];
		false ->
			Data
	end.


%%初始化数据库玩家系统配置数据
init_player_sys_settings(PlayerSysSet) ->
	db_agent:init_player_sys_settings(PlayerSysSet).
%%更新玩家数据库系统配置数据
update_player_sys_settings(ValueList, PlayerId, Param) ->
	case get_player_sys_setting(sys_setting_type) of
		0 ->%%数据库没数据的
			[ShieldRole, ShieldSkill, ShieldRela, 
			 ShieldTeam, ShieldChat, Music, SoundEffect,Fasheffect, Smelt] = Param,
			PlayerSysSet = #player_sys_setting{player_id = PlayerId,
											   shield_role = ShieldRole,
											   shield_skill = ShieldSkill, 
											   shield_rela = ShieldRela,
											   shield_team = ShieldTeam, 
											   shield_chat = ShieldChat, 
											   music = Music,
											   soundeffect = SoundEffect,
											   fasheffect = Fasheffect,
											   smelt = Smelt},
			init_player_sys_settings(PlayerSysSet),
			%%改变标识
			update_player_sys_setting(sys_setting_type, 1);
		1 ->%%数据库有数据了
			WhereList = [{player_id, PlayerId}],
			db_agent:update_player_sys_settings(ValueList, WhereList)
	end.
	
%% -----------------------------------------------------------------
%% 34000 读取设置信息
%% -----------------------------------------------------------------
get_player_sys_setting_info() ->
	KeysList = [shield_role, shield_skill, shield_rela, shield_team, shield_chat, music, soundeffect,fasheffect,smelt],
	lists:map(fun get_player_sys_setting/1, KeysList).
%% -----------------------------------------------------------------
%% 34001 保存设置信息
%% -----------------------------------------------------------------
set_player_sys_setting_info(PlayerId, Param) ->
	Len = length(Param),
	case (Len =:= 9) of
		true ->
			%%检查数据合法性
			case check_validate(true, 1, Param) of
				true ->
					KeysList = [shield_role, shield_skill, shield_rela, shield_team, shield_chat, music, soundeffect, fasheffect, smelt],
					{_KeysListNew, ValuesList} = lists:foldl(fun(Elem, AccIn) ->
																	 {[AccElem|AccInNew], Result} = AccIn,
																	 %%更新进程字典
																	 update_player_sys_setting(AccElem, Elem),
																	 %%顺便返回用于更新数据库的数据
																	 {AccInNew, [{AccElem, Elem}|Result]}
															 end, 
															 {KeysList, []}, Param),
					update_player_sys_settings(ValuesList, PlayerId, Param),
					[1];
				false ->
					[0]
			end;
		false ->%%客户端数据有误
			[0]
	end.
	
%%
%% Local Functions
%%
			
%%检查配置数据合法性
check_validate(true, _Count, []) ->
	true;
check_validate(true, Count, [Elem|Param]) ->
	Result = 
		if Count =:= 6 orelse Count =:= 7 ->
			   Elem >= 0 orelse Elem =< 255;
		   true ->
			   Elem=:= 0 orelse Elem=:= 1
		end,
	check_validate(Result, Count+1, Param);
check_validate(false, _Count, _Param) ->
	false.
	
