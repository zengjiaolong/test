%% Author: hxming
%% Created: 2010-11-29
%% Description: 采集任务模块
-module(mod_collect).
-include("common.hrl").
-include("record.hrl").
-export([
	collect_call/2,
	cancel_collect/0
]).
-record(state, {last_collect_time = 0,last_mon_id = 0}).

collect_call(Status, Mon) ->
	%% 玩家卸下坐骑
    {ok,NewStatus} = lib_goods:force_off_mount(Status),
    NowTime = util:longunixtime(),
	State = get_collect_state(),
    %% 限制采集频率
    TimeTick = NowTime - State#state.last_collect_time + 500,
    CollectCd = Mon#ets_mon.hp_lim*1000,
    [Return, RetState] =
        if 
			State#state.last_mon_id > 0 ->
            	if 
					TimeTick >= CollectCd andalso State#state.last_mon_id =:= Mon#ets_mon.id ->
                    	collect_goods(NewStatus, Mon),
                       	NewState = State#state{last_collect_time = 0,last_mon_id=0},
                       	[NewStatus,NewState];
                   	TimeTick < CollectCd andalso State#state.last_mon_id =:= Mon#ets_mon.id ->
                       	[Status, State];
                   	true ->
                       	NewState = State#state{last_collect_time = NowTime - 50,last_mon_id = Mon#ets_mon.id},
                        [Status, NewState]
                end;
           	true->
               	NewState = State#state{last_collect_time = NowTime - 50,last_mon_id = Mon#ets_mon.id},
                [Status, NewState]
   		end,
	put(mod_collect_state, RetState),
	Return.

%% 采集到物品
collect_goods(PlayerStatus, Mon)->
	%% 怪物经验，大于/小于5级经验减半
   	MonExp = 
  		case abs(PlayerStatus#player.lv - Mon#ets_mon.lv) > 5 of
     		true ->
        		round(Mon#ets_mon.exp / 2);
         	false ->
           		Mon#ets_mon.exp
     	end, 
	gen_server:cast(PlayerStatus#player.other#player_other.pid, {'EXP', MonExp, Mon#ets_mon.spirit}),
   	%% 掉落物
	lib_goods_drop:mon_drop(PlayerStatus, Mon, [PlayerStatus#player.id]).

%% 取消采集
cancel_collect() ->
	State = #state{},
	put(mod_collect_state, State).

get_collect_state() ->
	case get(mod_collect_state) of
		undefined ->
			State = #state{},
			put(mod_collect_state, State),			
			State;
		State ->
			State
	end.
