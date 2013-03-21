%% Author: xianrongMai
%% Created: 2011-7-1
%% Description: 成就系统的处理接口
-module(pp_achieve).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include("achieve.hrl").
-include("activity.hrl").
%%
%% Exported Functions
%%
-export([handle/3]).

%%
%% API Functions
%%
%% =====================================================================================================
%% **************************************		成就相关协议操作 	 	************************************
%% =====================================================================================================

%% -----------------------------------------------------------------
%% 38000 总成就获取
%% -----------------------------------------------------------------
handle(38000, Status,[]) ->
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(Status#player.id),
	Result = lib_achieve_outline:get_achieves(Status),
	{ok, BinData38000} = pt_38:write(38000, [Result]),
%%	?DEBUG("38000: ~p", [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38000),
	ok;
%% -----------------------------------------------------------------
%% 38001 获取最近完成成就
%% -----------------------------------------------------------------
handle(38001, Status, []) ->
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(Status#player.id),
	Result = lib_achieve_outline:get_achieve_log(Status#player.id),
%% 	?DEBUG("38001:~p", [Result]),
	{ok, BinData38001} = pt_38:write(38001, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38001),
	ok;

%% -----------------------------------------------------------------
%% 38002 奇珍异宝 列表
%% -----------------------------------------------------------------
handle(38002, Status, []) ->
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(Status#player.id),
	Result = lib_achieve_outline:get_ach_treasure_list(Status#player.id, 38002),
%% 	?DEBUG("38002Result:~p", [Result]),
	{ok, BinData38002} = pt_38:write(38002, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38002),
	ok;

%% -----------------------------------------------------------------
%% 38003 奇珍异宝  领取奖励
%% -----------------------------------------------------------------
handle(38003, Status, [Type, AchNum]) ->
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(Status#player.id),
	AType = AchNum div 100,
	SAType = AchNum rem 100,
	case (AType =:= 7 orelse AType =:= 10) andalso SAType >= 1 andalso 
			 ((AchNum >= 701 andalso AchNum =< 728) orelse (AchNum >= 1001 andalso AchNum =< 1008)) of
		true ->
			Result = lib_achieve_outline:get_ach_treasure(AchNum, Status),
%%			?DEBUG("Result 38003: ~p", [Result]),
			{ok, BinData38003} = pt_38:write(38003, [Type, Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38003);
		false ->
			{ok, BinData38003} = pt_38:write(38003, [Type, 0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38003)
	end,
	
	ok;

%% -----------------------------------------------------------------
%% 38004 八神珠 已装备
%% -----------------------------------------------------------------
handle(38004, Status, []) ->
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(Status#player.id),
	lib_achieve_outline:get_ach_pearl_equiped(Status),
	ok;
	
%% -----------------------------------------------------------------
%% 38005 八神珠 未装备
%% -----------------------------------------------------------------
handle(38005, Status, []) ->
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(Status#player.id),
	lib_achieve_outline:get_ach_pearl_equipno(Status),
	ok;
	
%% -----------------------------------------------------------------
%% 38006 八神珠  装备和卸载
%% -----------------------------------------------------------------
handle(38006, Status, [GoodsId, Type]) ->
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(Status#player.id),
	{NewStatus, Result} = lib_achieve_outline:load_unload_pearl(GoodsId, Type, Status),
	{RType, GoodsTypeId, Cell} = Result,
%% 	?DEBUG("Result:38006: ~p", [Result]),
	case RType =:= 1 of
		true ->
			%%需要即时更新玩家的属性状态
			spawn(fun()->lib_player:send_player_attribute(NewStatus, 1)end),
			{ok, BinData38006} = pt_38:write(38006, [{RType, Type, GoodsId, GoodsTypeId, Cell}]),
			lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData38006),
			{ok, NewStatus};
		false ->
			{ok, BinData38006} = pt_38:write(38006, [{RType, Type, GoodsId, GoodsTypeId, Cell}]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38006),
			ok
	end;
	
%% -----------------------------------------------------------------
%% 38008 人物属性面板称号列表获取
%% -----------------------------------------------------------------
handle(38008, Status, []) ->
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(Status#player.id),
	{AchTs, ComTs, SpecTs} = 
		lib_achieve_outline:get_ach_title(Status#player.id, Status#player.other#player_other.titles),
%%	?DEBUG("38008 result:~p", [SpecTs]),
	NSpecTs = lib_title:check_get_ornot(Status#player.id, SpecTs),
%%	?DEBUG("38008 result after :~p", [NSpecTs]),
	{ok, BinData38008} = pt_38:write(38008, [{AchTs, ComTs, NSpecTs}]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38008),
	ok;

%% -----------------------------------------------------------------
%% 38009 使用称号
%% -----------------------------------------------------------------
handle(38009, Status, [AchNum]) ->
	%% 检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(Status#player.id),
	{Result, NewStatus} = lib_achieve_outline:use_ach_title(Status, AchNum),
	case Result of
		1 ->
			%%需要即时更新玩家的属性状态
%% 			spawn(fun()->lib_player:send_player_attribute(NewStatus, 1) end),
			{ok, BinData38009} = pt_38:write(38009, [Result, AchNum]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38009),
			{ok, NewStatus};
		_ ->
			{ok, BinData38009} = pt_38:write(38009, [Result, AchNum]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38009),
			ok
	end;

%% -----------------------------------------------------------------
%% 38010 取消称号
%% -----------------------------------------------------------------
handle(38010, Status, [AchNum]) ->
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(Status#player.id),
	{Result, NewStatus} = lib_achieve_outline:cancel_ach_title(Status, AchNum),
%% 	?DEBUG("38010Result:~p", [Result]),
	{ok, BinData38010} = pt_38:write(38010, [Result, AchNum]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38010),
	{ok, NewStatus};

%% -----------------------------------------------------------------
%% 38011 获取称号
%% -----------------------------------------------------------------
handle(38011, Status, [AchNum]) ->
	IsExist = lists:member(AchNum, ?PLYAER_TITLES_MEMBERS),
	case IsExist of
		true ->%%是在称号集里面的
			{Result, NewStatus} = lib_achieve_outline:claim_ach_title(Status, AchNum),
%% 	?DEBUG("38011Result:~p", [Result]),
			case Result of
				1 ->
					{ok, BinData38011} = pt_38:write(38011, [Result, AchNum]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38011),
					{ok, NewStatus};
				_ ->
					{ok, BinData38011} = pt_38:write(38011, [Result, AchNum]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38011),
					ok
			end;
		false ->
			{ok, BinData38011} = pt_38:write(38011, [0, AchNum]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38011),
			ok
	end;


%% -----------------------------------------------------------------
%% 38014 新手成就 列表
%% -----------------------------------------------------------------
handle(38014, Status, []) ->
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(Status#player.id),
	Result = lib_achieve_outline:get_ach_treasure_list(Status#player.id, 38014),
%% 	?DEBUG("38002Result:~p", [Result]),
	{ok, BinData38002} = pt_38:write(38014, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38002),
	ok;
%% =====================================================================================================
%% ======================================	活跃度相关协议操作 	========================================
%% =====================================================================================================


%% -----------------------------------------------------------------
%% 38012 获取活跃度
%% -----------------------------------------------------------------
handle(38012, Status, []) ->
	ActivityData = lib_activity:check_load_activity(Status#player.id),
	Result = lib_activity:make_activity_return(ActivityData),
	{ok, BinData38012} = pt_38:write(38012, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38012),
	ok;
	

%% -----------------------------------------------------------------
%% 38013 活跃度领取奖品
%% -----------------------------------------------------------------
handle(38013, Status, [Num]) ->
%% 	?DEBUG("38013 :~p", [Num]),
	case Num >= 1 andalso Num =< 4 of
		true ->
			Result = lib_activity:get_active_goods(Status, Num),
%% 			?DEBUG("38013 result ~p", [Result]),
			{ok, BinData38013} = pt_38:write(38013, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData38013),
			ok;
		false ->
			ok
	end;

handle(Cmd, _Socket, Data) ->
	?DEBUG("handle_achieve no match_/~p/~p/", [Cmd, Data]),
    {error, "handle_achieve no match"}.

%%
%% Local Functions
%%

