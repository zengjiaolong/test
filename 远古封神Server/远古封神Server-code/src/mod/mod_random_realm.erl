%% Author: hxming
%% Created: 2010-12-04
%% Description: TODO: 选择阵营处理模块
-module(mod_random_realm).
%%
%% Include files
%%
-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export([start_link/0, start/0,stop/0,get_realm/0,select_pay_player/0]).
-compile(export_all).

%%
%% API Functions
%%
%% 定时器1间隔时间
-define(TIMER_1, 5*60*1000).

%% 启动选择阵营服务
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

start() ->
    gen_server:start(?MODULE, [], []).

%%停止服务
stop() ->
    gen_server:call(?MODULE, stop).

%%获取一个阵营
get_realm()->
	gen_server:call(?MODULE,{'get_realm'}).
%%
%% Local Functions
%%
init([]) ->
    process_flag(trap_exit, true),	
	erlang:send_after(?TIMER_1, self(), {event, select_realm}),
	select_realm(),
	misc:write_monitor_pid(self(),?MODULE, {}),	
    {ok, []}.

%%获取阵营
handle_call({'get_realm'},_From,State) ->
	Realm = random_nation(),
	{reply,Realm,State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, select_realm}, State) ->
	select_realm(),
	erlang:send_after(?TIMER_1, self(), {event, select_realm}),
	{noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
    ok.

code_change(_OldVsn, State, _Extra)->
    {ok, State}.

select_realm()->
	try
		{N_Pay,S_Pay,F_Pay} = select_pay_player(),
		N_Cache = db_agent:get_realm(1),
		insert_realm_cache(1,N_Cache+N_Pay*5),
		S_Cache = db_agent:get_realm(2),
		insert_realm_cache(2,S_Cache+S_Pay*5),
		F_Cache = db_agent:get_realm(3),
		insert_realm_cache(3,F_Cache+F_Pay*5),
		ok
	catch
		_:_ -> fail
	end.

select_pay_player()->
	PayBag = db_agent:get_pay_player(),
	PayBag1 = lists:usort([PlayerId || [PlayerId] <- PayBag]),%% 去除重复Id
	RealmBag = db_agent:get_pay_player_realm(PayBag1),
	count_pay_realm(RealmBag,{0,0,0}).

count_pay_realm([],{N,S,F})->{N,S,F};
count_pay_realm([[Realm|_]|RealmBag],{N,S,F})->
	case Realm of
		1->
			count_pay_realm(RealmBag,{N+1,S,F});
		2->
			count_pay_realm(RealmBag,{N,S+1,F});
		3->
			count_pay_realm(RealmBag,{N,S,F+1});
		_->
			count_pay_realm(RealmBag,{N,S,F})
	end.

random_nation()->
	N = get_realm_cache(1),
	S = get_realm_cache(2),
	F = get_realm_cache(3),
	Min = lists:min([N,S,F]),
	if Min =:= N ->
		   Realm = 1;
	   Min =:= S ->
		   Realm = 2;
	   true -> 
		   Realm = 3
	end,
	update_realm(Realm),
	Realm.

update_realm(Realm)->
	RealmNums = get_realm_cache(Realm),
	insert_realm_cache(Realm, RealmNums+1).

%%**************缓存区操作**************%%
%% 获取单个阵营信息
get_realm_cache(Realm) ->
    case ets:lookup(?ETS_REALM, Realm) of
        [] -> 0;
        [{_,RealmCache}] ->RealmCache
    end.

%%更新阵营统计
insert_realm_cache(Realm,Cache) ->
	ets:insert(?ETS_REALM, {Realm,Cache}).

