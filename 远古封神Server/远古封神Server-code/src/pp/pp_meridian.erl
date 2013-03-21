%%%--------------------------------------
%%% @Module  : pp_meridian
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description:  经脉处理
%%%--------------------------------------

-module(pp_meridian).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%查询经脉是否可修炼
handle(25010,PlayerStatus,[])->
	case mod_meridian:meridian_active_check(PlayerStatus,[1,2,3,4,5,6,7,8]) of
		{false,_}->
			skip;
		{true,NewPlayerStatus}->
			{ok,Bin} = pt_25:write(25010,[1]),
    		lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, Bin)
	end;

%经脉信息
handle(25020, PlayerStatus, PlayerId) ->
    {ok,PS,Data} = lib_meridian:check_meridian_info(PlayerStatus,PlayerId),
    {ok,Bin} = pt_25:write(25020,Data),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, Bin),
	{ok,PS};

%经脉属性
handle(25030, PlayerStatus, [PlayerId,MeridianId]) ->
	MerType = lib_meridian:id_to_type(MeridianId),
	{PS,UPInfo,MeridianInfo} = lib_meridian:check_can_uplvl(PlayerStatus,PlayerId,MeridianId),
    {_,Info} = lib_meridian:check_meridian_lvl_and_linggen(PlayerId,MeridianInfo,MerType),
	[Lvl,LG,_value]=Info,
	Effect = [lib_meridian:get_meridian_effect(MeridianId,Lvl,LG)],
	EffectNext = [lib_meridian:get_meridian_effect(MeridianId,Lvl+1,LG)],
	{ok,Bin} = pt_25:write(25030,[PlayerId,MeridianId]++Info++Effect++EffectNext++[UPInfo]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, Bin),
	{ok,PS};

%经脉升级
handle(25040,PlayerStatus,MeridianId) ->
   {Type,PS, Data} =  mod_meridian:meridian_active(PlayerStatus,MeridianId),
	[Result,Timestamp]= Data,
   case Type of
	   ok ->
		   %%成就系统统计接口
		   lib_achieve:check_achieve_finish(PlayerStatus#player.other#player_other.pid_send, PlayerStatus#player.id, 425, [1]);
	   _ ->
		   skip
   end,
   {ok, Bin} = pt_25:write(25040, [MeridianId,Result,Timestamp]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, Bin),
   {ok,PS};

%经脉停止修炼
handle(25050,PlayerStatus,MeridianId) ->
	{_,PS,Data} = mod_meridian:meridian_uplvl_cancel(PlayerStatus,MeridianId),
	{ok, Bin} = pt_25:write(25050, [MeridianId,Data]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, Bin),
	{ok,PS};

%经脉修炼加速
handle(25060,PlayerStatus,[MeridianId,GoodsId]) ->
	{_,PS ,Data} = mod_meridian:meridian_uplvl_speed(PlayerStatus,MeridianId,GoodsId),
	{ok, Bin} = pt_25:write(25060, [MeridianId]++Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, Bin),
	{ok,PS};

%经脉灵根洗练
handle(25070,PlayerStatus,[MeridianId,IsSave,AutoPay])->
	{_,PS ,Data} = mod_meridian:meridian_up_linggen(PlayerStatus,MeridianId,IsSave,AutoPay),
	[Result,_Value,_Effect] = Data,
	case Result of
		3 ->
			%%成就系统统计接口
			lib_achieve:check_achieve_finish(PlayerStatus#player.other#player_other.pid_send, PlayerStatus#player.id, 424, [1]);
		_Other ->
			skip
	end,
	{ok, Bin} = pt_25:write(25070, [MeridianId]++Data),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, Bin),
	{ok,PS};

%%经脉突破
handle(25090,PlayerStatus,[MerId])->
	{Res,NewPlayer,Value} = mod_meridian:merdian_break_through(PlayerStatus,MerId),
	{ok,Bin} = pt_25:write(25090,[Res,MerId,Value]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, Bin),
	if PlayerStatus =/= NewPlayer->
		   {ok,NewPlayer};
	   true->
			ok
	end;

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_meridian no match", []),
    {error, "pp_meridian no match"}.


