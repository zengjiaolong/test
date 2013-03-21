%% Author: hxming
%% Created: 2011-5-12
%% Description: TODO: 远古情缘
-module(mod_love).

-behaviour(gen_server).
%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").

%%
%% Exported Functions
%%
-export(
    [
        start_link/4
        ,stop/0
    ]
).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% 定时器1间隔时间
-define(TIMER_1, 15000).
-define(Flower,120000).
-define(CheckState,600000).
-record(state, {player_id = 0}).

start_link(PlayerId,Pid_send,Pid,Sex)->
    gen_server:start_link(?MODULE, [PlayerId,Pid_send,Pid,Sex], []).

%% 关闭服务器时回调
stop() ->
    ok.

init([PlayerId,Pid_send,Pid,Sex])->
	misc:write_monitor_pid(self(),?MODULE, {}),
	{ok,Love} = lib_love:init_love(PlayerId,Sex),
	case lib_love:init_share_exp(Pid_send,Love) of
		{ok,_RemainTime}->
			erlang:send_after(?TIMER_1, self(), share_exp),
			gen_server:cast(Pid,{'start_privity_test_timer',1});
		_->skip
	end,
%% 	erlang:send_after(?TIMER_1, self(), check_title),
	State = #state{player_id=PlayerId},
    {ok,State}.

%%
%% Local Functions
%%

%%停止进程
handle_cast({stop, _Reason}, State) ->
    {stop, normal, State};

handle_cast({start_share_exp,PlayerStatus,Mult,InviteData,Type}, State) ->
	lib_love:start_share_exp(PlayerStatus,Mult,Type,InviteData),
	erlang:send_after(?TIMER_1, self(), share_exp),
%% 	erlang:send_after(?Flower, self(), evaluate_tips),
    {noreply, State};

handle_cast(_Message,State)->
	{noreply,State}.

%%邀请有缘人
handle_call({'invite',InviteId},_From,State) ->
	Result = lib_love:check_invitee(InviteId),
	{reply,Result,State};

%%检查是否可邀请
handle_call({'check_invite',InviteId},_From,State) ->
	Result = case lib_love:check_invitee(InviteId) of
		{ok,1}->{ok,1};
		{error,_}->{error,2}
	end,
	{reply,Result,State};

%%评价
handle_call({'evaluate',Invitee,PlayerId,Nickname,Career,Sex,App,Flower,Charm},_From,State)->
	Result=lib_love:check_evaluate(Invitee,PlayerId,Nickname,Career,Sex,App,Flower,Charm),
	{reply,Result,State};

handle_call(_Request, _From, State) ->
    {reply, State}.

%%共享经验
handle_info(share_exp, State) ->
	case ets:lookup(?ETS_ONLINE, State#state.player_id) of
		[] ->
			erlang:send_after(?TIMER_1, self(), share_exp),
			ok;
		[PlayerStatus] ->
			case lib_love:share_exp(PlayerStatus) of
				ok->erlang:send_after(?TIMER_1, self(), share_exp);
				skip->skip
			end
	end,
    {noreply, State};

%%评价
handle_info(evaluate_tips,State)->
	case ets:lookup(?ETS_ONLINE, State#state.player_id) of
		[] ->skip;
		[PlayerStatus] ->
			lib_love:evaluate_tips(PlayerStatus)
	end,
    {noreply, State};

%% %%检查状态
%% handle_info(check_title,State)->
%% 	case ets:lookup(?ETS_ONLINE, State#state.player_id) of
%% 		[] ->skip;
%% 		[PlayerStatus] ->
%% 			NewPlayerStatus = lib_love:check_title_state(PlayerStatus),
%% 			if PlayerStatus =/= NewPlayerStatus ->
%% 				   mod_player:save_online_diff(State,NewPlayerStatus);
%% 			   true->
%% 				   if NewPlayerStatus#player.other#player_other.charm_title > 0->
%% 						  erlang:send_after(?CheckState, self(), check_title);
%% 					  true->skip
%% 				   end
%% 			end
%% 	end,
%%     {noreply, State};


handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


