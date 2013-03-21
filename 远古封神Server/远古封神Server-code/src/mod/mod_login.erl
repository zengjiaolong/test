%%%-----------------------------------
%%% @Module  : mod_login
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 用户登陆
%%%-----------------------------------
-module(mod_login).
-export([login/3, logout/2, stop_all/0]).
-include("common.hrl").
-include("record.hrl").
-compile(export_all).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

init([ProcessName, Worker_id]) ->
    process_flag(trap_exit, true),	
	misc:register(global, ProcessName, self()),
	if 
		Worker_id =:= 0 ->
			misc:write_monitor_pid(self(), mod_vip, {}),
			misc:write_system_info(self(), mod_vip, {});
		true->
			 misc:write_monitor_pid(self(), mod_vip_child, {Worker_id})
	end,
    {ok, []}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.
handle_cast(_MSg,State)->
	 {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()).

code_change(_OldVsn, State, _Extra)->
    {ok, State}.

%%登陆检查入口
%%Data:登陆验证数据
%%Arg:tcp的Socket进程,socket ID
login(start, [PlayerId, AccountId, _Accname], Socket) ->
    case lib_account:check_account(PlayerId, AccountId) of
        false ->
            {error, fail1};
        true ->
			spawn(fun() -> check_duplicated_login(PlayerId) end),
			case mod_player:start(PlayerId, AccountId, Socket) of 
				{ok, Pid} ->
					{ok, Pid};
				_-> 
					mod_player:delete_player_ets(PlayerId),
					{error, fail2}
			end
    end.

%% 检查此账号是否已经登录, 如果登录 则通知退出
check_duplicated_login(PlayerId) ->
	PlayerProcessName = misc:player_process_name(PlayerId),
	case misc:whereis_name({global, PlayerProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> 
    				logout(Pid, 1),
					timer:sleep(500),					
					Pid;
				false -> undefined
			end;
		_ ->
			undefined
	end.

%% 把所有在线玩家踢出去
stop_all() ->
    L = ets:tab2list(?ETS_ONLINE),
    do_stop_all(L).

%% 让所有玩家自动退出
do_stop_all([]) -> ok;
do_stop_all([H | T]) ->
    logout(H#player.other#player_other.pid, 0),
    do_stop_all(T).

%% 把所有在线玩家踢出去， 且显示系统繁忙
kick_all() ->
    L = ets:tab2list(?ETS_ONLINE),
    do_kick_all(L).

%% 让所有玩家自动退出， 且显示系统繁忙
do_kick_all([]) -> ok;
do_kick_all([H | T]) ->
    logout(H#player.other#player_other.pid, 7),
    do_kick_all(T).

%%退出登陆
logout(Pid, Reason) when is_pid(Pid) ->
    mod_player:stop(Pid, Reason),
    ok.
