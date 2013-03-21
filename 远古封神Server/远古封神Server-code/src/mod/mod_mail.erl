%%%------------------------------------
%%% @Module     : mod_mail
%%% @Author     : ygzj
%%% @Created    : 2010.10.05
%%% @Description: 信件服务
%%%------------------------------------
-module(mod_mail).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export([
		 start_link/0, stop/0, 
		 send_sys_mail/8, %%注，不能群发物品
		 send_sys_mail/9, %%注，不能群发物品 
		 send_priv_mail/7,
		 delete_read_mail/1		%% 19008 删除已读邮件
		]).
-include("common.hrl").
-include("record.hrl").

%% 定时器1间隔时间: 邮件清理 (每4小时检查一次，如果检查时的时间为2:00~6:00，则执行信件清理)
-define(TIMER_1, 4*60*60*1000).
%% 定时器1间隔时间: 邮件清理 (清理一次之后，间隔24小时再清理)
-define(TIMER_2, 24*60*60*1000).

%%%------------------------------------
%%%  接口函数
%%%------------------------------------

%% 启动邮件服务
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% 发个人邮件
send_priv_mail(NameList, Title, Content, GoodsId, GoodsNum, Coin, PlayerStatus) ->
    gen_server:cast(?MODULE, {'send_priv_mail', [NameList, Title, Content, GoodsId, GoodsNum, Coin, PlayerStatus]}).

%% 发系统邮件
send_sys_mail(NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Cash) ->
    gen_server:cast(?MODULE, {'send_sys_mail', [NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Cash]}).

%% 发系统邮件	GoodsBind为0时，发绑定的物品，其他值如1时不绑定
send_sys_mail(NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Cash, GoodsBind) ->
    gen_server:cast(?MODULE, {'send_sys_mail', [NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Cash, GoodsBind]}).
stop() ->
    gen_server:call(?MODULE, stop).

%%%------------------------------------
%%%             回调函数
%%%------------------------------------

init([]) ->
	process_flag(trap_exit, true),	
	misc:write_monitor_pid(self(),?MODULE, {}),
	erlang:send_after(5*1000, self(), {event, clean_overdure_mail}), %%5秒钟后执行信件清理检查
    {ok, []}.

%% 发系统信件，返回处理结果（{ok, IList} | {error, Reason}）
handle_call({'send_sys_mail', [NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Cash]}, _From, State) ->
    Reply = lib_mail:send_sys_mail(NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Cash),
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%% 发系统信件，不返回处理结果
handle_cast({'send_sys_mail', [NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Cash, GoodsBind]}, State) ->
    lib_mail:send_sys_mail(NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Cash, GoodsBind),
    {noreply, State};
%% 发系统信件，不返回处理结果
handle_cast({'send_sys_mail', [NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Cash]}, State) ->
    lib_mail:send_sys_mail(NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Cash),
    {noreply, State};

%% 发私人信件
handle_cast({'send_priv_mail', [NameList, Title, Content, GoodsId, GoodsNum, Coin, PlayerStatus]}, State) ->
    case lib_mail:send_priv_mail(NameList, Title, Content, GoodsId, GoodsNum, Coin, PlayerStatus) of
        {ok, RName} ->
            {ok, BinData} = pt_19:write(19001, [1, []]),            %% 发送成功
			lib_mail:check_unread_by_name(RName);                    %% 通知收件人有未读邮件         
        {error, Reason} ->
            {ok, BinData} = pt_19:write(19001, [Reason, []]);
        {VList, IList} ->                                           %% {发送成功名单，发送失败名单}
            case IList of
                [] ->
                    {ok, BinData} = pt_19:write(19001, [1, []]);    %% 发送成功
                _ ->
                    {ok, BinData} = pt_19:write(19001, [6, IList])  %% 部分发送失败
            end,
			%% 通知收件人有未读邮件
            lists:foreach(fun(Nick) -> 
								  lib_mail:check_unread_by_name(Nick) end, VList)
    end,
    %timer:sleep(5),    %% Erlang模拟客户端测试需要，分隔两个数据包
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),  %% 通知发件人处理结果
    {noreply, State};

handle_cast({'clean_mail'}, State) ->
%% ?DEBUG("handle_cast_clean_overdure_mail_~p/~p ~n",[clean_overdure_mail, clean_mail]),
    lib_mail:check_mail_time(),
    {noreplay, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% 清理信件
handle_info({event, clean_overdure_mail}, State) ->
	Nowtime=util:unixtime(),
%% ?DEBUG("clean_overdure_mail_~p/~p ~n",[clean_overdure_mail, Nowtime]),
	Time_jd = (Nowtime + 8*3600) rem 86400,
	if
		Time_jd >= 2*3600 andalso Time_jd =< 6*3600 ->
			case ets:match(?ETS_SYSTEM_INFO, {'$1',mod_guild,'_'}) of
				[] -> no_action;		%% 保证此操作仅在一个节点执行
				_ ->
					try
						lib_mail:check_mail_time()
					catch
						_:_ -> error
					end
			end,
			erlang:send_after(?TIMER_2, self(), {event, clean_overdure_mail});
		true ->
			erlang:send_after(?TIMER_1, self(), {event, clean_overdure_mail})
	end,
	{noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ----------------------------------------------------------
%% 19008 删除已读邮件
%% ----------------------------------------------------------
delete_read_mail(Status) ->
	lib_mail:delete_read_mail(Status#player.id).

