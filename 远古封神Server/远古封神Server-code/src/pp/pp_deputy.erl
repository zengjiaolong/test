%% Author:
%% Created: 2011-10-20
%% Description: 副法宝
-module(pp_deputy).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-export([handle/3]).

%% 获取副法宝信息

handle(46000, Status, [PlayerId]) ->
%% 	DeputyInfo = case lib_war:is_war_server() of
%% 					 false->
%% 						 lib_deputy:get_deputy_equip_info(Status,PlayerId);
%% 					 true->[]%%跨服不能查看神器
%% 				 end,
	DeputyInfo = lib_deputy:get_deputy_equip_info(Status,PlayerId),
	{ok,BinData} = pt_46:write(46000,[PlayerId,DeputyInfo]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	ok;

%% 获取所有副法宝信息
handle(46001,Status,[Lv]) ->
	InfoList = lib_deputy:get_all_deputy_equip_info(Lv),
	{ok,BinData} = pt_46:write(46001,[InfoList]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	ok;

%% 副法宝提升品质
handle(46002,Status,[Auto_Purch]) ->
	[Code,LuckyColor,LuckyColorMax,NewPlayer]=lib_deputy:upgrade_deputy_color(Status,Auto_Purch),
	{ok,BinData} = pt_46:write(46002,[Code,LuckyColor,LuckyColorMax,NewPlayer#player.gold,NewPlayer#player.coin,NewPlayer#player.bcoin]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	{ok,NewPlayer};

%% 副法宝提升潜能
handle(46003,Status,[Auto_Purch]) ->
	[Code,LuckyStep,LuckyStepMax,NewPlayer] = lib_deputy:upgrade_deputy_step(Status,Auto_Purch),
	{ok,BinData} = pt_46:write(46003,[Code,LuckyStep,LuckyStepMax,NewPlayer#player.gold,NewPlayer#player.coin,NewPlayer#player.bcoin]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	{ok,NewPlayer};

%%提升熟练度
handle(46004,Status,[Type,Auto_Purch]) ->
	[Code,Prof,Prof_max,Prof_lv,NewPlayer] = lib_deputy:upgrade_deputy_prof(Status,Type,Auto_Purch),
	{ok,BinData} = pt_46:write(46004,[Code,Prof,Prof_max,Prof_lv]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	{ok,NewPlayer};

%% 突破瓶颈
handle(46005,Status,[Auto_Purch]) ->
	[Code,LuckyProf,LuckyProfMax,ProfLv,NewPlayer] = lib_deputy:break_deputy_prof(Status,Auto_Purch),
	{ok,BinData} = pt_46:write(46005,[Code,LuckyProf,LuckyProfMax,NewPlayer#player.gold,NewPlayer#player.coin,NewPlayer#player.bcoin]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	if
		Code == 1 ->
			{ok, Bin12042} = pt_12:write(12042, [Status#player.id, [{5, ProfLv}]]),
			%%采用广播通知，附近玩家都能看到
			mod_scene_agent:send_to_area_scene(Status#player.scene, Status#player.x, Status#player.y, Bin12042);
		true ->
			skip
	end,
	{ok,NewPlayer};

%%属性洗练
handle(46006,Status,[Type,Auto_Purch]) ->
	[Code,OldAtt,NewAtt,ChangeAtt,NewPlayer,Step,Color] = lib_deputy:wash_deputy(Status,Type,Auto_Purch),
	{ok,BinData} = pt_46:write(46006,[Code,NewPlayer#player.gold,NewPlayer#player.coin,NewPlayer#player.bcoin,Step,Color,NewPlayer#player.spirit,OldAtt,NewAtt,ChangeAtt]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	{ok,NewPlayer};

%%属性变更
handle(46007,Status,[Type]) ->
	{Step,Color,AttList,NewPlayer} = lib_deputy:confirm_wash(Status,Type),
	{ok,BinData} = pt_46:write(46007,[Step,Color,AttList]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	{ok,NewPlayer};

%% 学习技能
handle(46008,Status,[Goods_id,Gid]) ->
	[Code,NewPlayer] = lib_deputy:learn_skill(Status,Goods_id,Gid),
	{ok,BinData} = pt_46:write(46008,[Code,NewPlayer#player.culture,NewPlayer#player.gold,NewPlayer#player.coin,NewPlayer#player.bcoin]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	{ok,NewPlayer};

%%神器排行榜查询
handle(46010,Status,[Player_id]) ->
	DeputyInfo = lib_deputy:get_deputy_rank_tooltip_info(Player_id),
	{ok,BinData} = pt_46:write(46010,DeputyInfo),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send,BinData),
	ok;
	
%% 查询
handle(_Cmd, _Status, _Data) ->
%%     ?DEBUG("pp_fst no match", []),
    {error, "pp_deputy no match"}.

