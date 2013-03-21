%% Author: xiaomai
%% Created: 2010-12-27
%% Description: 玩家游戏系统配置
-module(pp_syssetting).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").

%%
%% Exported Functions
%%
-export([handle/3]).

%%
%% API Functions
%%
%% -----------------------------------------------------------------
%% 34000 读取设置信息
%% -----------------------------------------------------------------
handle(34000, Status, []) ->
	Result = get_player_sys_settings(),
%%	?DEBUG("RESULT:~p", [Result]),
	{ok, BinData} = pt_34:write(34000, Result),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 34001 保存设置信息
%% -----------------------------------------------------------------
handle(34001, Status, [Param]) ->
	Fasheffect1 = lib_syssetting:get_player_sys_setting(fasheffect),
	Result = set_player_sys_settings(Status#player.id, [Param]),
	[_ShieldRole, _ShieldSkill, _ShieldRela, _ShieldTeam, _ShieldChat, _Music, _SoundEffect,Fasheffect, _Smelt] = Param,
	
	case  Fasheffect =/= Fasheffect1 of
		false -> 
			NewPlayerStatus = Status;
		true ->
			[Wq, _Yf, Fbyf, Spyf, Zq] = Status#player.other#player_other.equip_current,
			case Fasheffect1 == 1 of
				false -> 
					{ok, Bin12042} = pt_12:write(12042, [Status#player.id, [{2, 0}]]),
					%%采用广播通知，附近玩家都能看到
					mod_scene_agent:send_to_area_scene(Status#player.scene, Status#player.x, Status#player.y, Bin12042),
					CurrentEquip = [Wq, 0, Fbyf, Spyf, Zq],
					NewPlayerStatus = Status#player{
						   other = Status#player.other#player_other{
                           		equip_current = CurrentEquip
							}
      				};
				true ->
					Fashion = goods_util:get_equip_cell(Status#player.id,1,13),
					case is_record(Fashion,goods) of
						true when Fashion#goods.goods_id >= 10901 andalso Fashion#goods.goods_id =< 10940 ->
							%% 如果时装有变化效果
							if
								Fashion#goods.icon > 0 ->
									CurrentEquip = [Wq, Fashion#goods.icon, Fbyf, Spyf, Zq],
									{ok, Bin12042} = pt_12:write(12042, [Status#player.id, [{2, Fashion#goods.icon}]]);
								true ->
									CurrentEquip = [Wq, Fashion#goods.goods_id, Fbyf, Spyf, Zq],
									{ok, Bin12042} = pt_12:write(12042, [Status#player.id, [{2, Fashion#goods.goods_id}]])
							end,							
							NewPlayerStatus = Status#player{
						   		other = Status#player.other#player_other{
                           			equip_current = CurrentEquip
								}
      						},
							%%采用广播通知，附近玩家都能看到
							mod_scene_agent:send_to_area_scene(Status#player.scene, Status#player.x, Status#player.y, Bin12042);
						false -> 
							NewPlayerStatus = Status
					end
			end
	end,
	{ok, BinData} = pt_34:write(34001, Result),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	NewCurrent = NewPlayerStatus#player.other#player_other.equip_current,
	gen_server:cast(NewPlayerStatus#player.other#player_other.pid_goods,{'equip_current',NewCurrent}),
	{ok,NewPlayerStatus};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_syssetting no match", []),
    {error, "pp_syssetting no match"}.

%%======================== 玩家游戏系统配置  begin =========================
%% -----------------------------------------------------------------
%% 34000 读取设置信息
%% -----------------------------------------------------------------
get_player_sys_settings() ->
	try 
		lib_syssetting:get_player_sys_setting_info()
	catch
		_:_ ->
			[0,0,0,0,0,50,50,0,0]
	end.

%% -----------------------------------------------------------------
%% 34001 保存设置信息
%% -----------------------------------------------------------------
set_player_sys_settings(PlayerId, [Param]) ->
	try 
		lib_syssetting:set_player_sys_setting_info(PlayerId, Param)
	catch
		_:_ ->
			[0]
	end.

%%======================== 玩家游戏系统配置  end =========================
