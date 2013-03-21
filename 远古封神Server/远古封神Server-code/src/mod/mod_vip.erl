%% Author: hxming
%% Created: 2011-4-6
%% Description: TODO: Add description to mod_vip
-module(mod_vip).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export([start_link/1, 
		 start/0,
		 stop/0,
		 get_mod_vip_pid/0,
		 send_mail/3,
		 send_title_mail/3,
		 set_title_mail_log/3,
		 check_title_mail_log/2
		 ]).

%%
%% API Functions
%%
%%
%% API Functions
%%
%% 启动vip邮件服务
start_link([ProcessName, Worker_id]) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName, Worker_id], []).

start() ->
    gen_server:start(?MODULE, [], []).

%%停止服务
stop() ->
    gen_server:call(?MODULE, stop).

send_mail(PlayerStatus,MailType,VipType)->
	gen_server:cast(mod_vip:get_mod_vip_pid(), {'vip_mail', PlayerStatus,MailType,VipType}).

send_title_mail(PlayerStatus,Title,MailType)->
	gen_server:cast(mod_vip:get_mod_vip_pid(), {'title_mail', PlayerStatus,Title,MailType}).
%%
%% Local Functions
%%
%%动态加载vip邮件服务处理进程 
get_mod_vip_pid() ->
	ProcessName = misc:create_process_name(mod_vip_process, [0]),
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> Pid;
				false -> 
					start_mod_vip(ProcessName)
			end;
		_ ->
			start_mod_vip(ProcessName)
	end.


%%启动vip邮件服务监控模块 (加锁保证全局唯一)
start_mod_vip(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> Pid;
					false -> 
						start_vip(ProcessName)
				end;
			_ ->
				start_vip(ProcessName)
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%开启vip邮件服务监控模块
start_vip(ProcessName) ->
    case supervisor:start_child(
               yg_server_sup,
               {mod_vip,
                {mod_vip, start_link,[[ProcessName,0]]},
                permanent, 10000, supervisor, [mod_vip]}) of
		{ok, Pid} ->
				timer:sleep(1000),
				Pid;
		_ ->
				undefined
	end.

%%
%% Local Functions
%%
init([ProcessName, Worker_id]) ->
    process_flag(trap_exit, true),	
	case misc:register(unique, ProcessName, self()) of
		yes ->
			if 
				Worker_id =:= 0 ->
					misc:write_monitor_pid(self(), mod_vip, {}),
					misc:write_system_info(self(), mod_vip, {});
				true->
			 		misc:write_monitor_pid(self(), mod_vip_child, {Worker_id})
			end,
			io:format("7.Init mod_vip finish!!!~n"),
    		{ok, []};
		_ ->
			{stop,normal,[]}
	end.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast({vip_mail,PlayerStatus,MailType,VipType}, State) ->
	case MailType of
		0->lib_vip:vip_mail(PlayerStatus,MailType,VipType);
		_->
			case check_vip_mail_log(PlayerStatus#player.id,MailType) of
				false->
					lib_vip:vip_mail(PlayerStatus,MailType,VipType),
					set_vip_mail_log(PlayerStatus#player.id,MailType,[MailType,VipType]);
				true->skip
			end
	end,
    {noreply, State};

handle_cast({title_mail,PlayerStatus,Title,MailType}, State) ->
	case check_title_mail_log(PlayerStatus#player.id,Title) of
		false->
			lib_love:title_mail(PlayerStatus,MailType),
			set_title_mail_log(PlayerStatus#player.id,Title,[MailType,Title]);
		true->
			skip
	end,
    {noreply, State};

handle_cast(_MSg,State)->
	 {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()).

code_change(_OldVsn, State, _Extra)->
    {ok, State}.

set_vip_mail_log(PlayerId,MailType,Cache)->
	ets:insert(?ETS_VIP_MAIL, {{PlayerId,MailType},Cache}).

check_vip_mail_log(PlayerId,MailType) ->
    case ets:lookup(?ETS_VIP_MAIL, {PlayerId,MailType}) of
        [] ->false;
        _ -> true
    end.

set_title_mail_log(PlayerId,Title,Cache)->
	ets:insert(?ETS_TITLE_MAIL, {{PlayerId,Title},Cache}).

check_title_mail_log(PlayerId,Title) ->
    case ets:lookup(?ETS_TITLE_MAIL, {PlayerId,Title}) of
        [] ->false;
        _ -> true
    end.