%%%------------------------------------
%%% @Module     : mod_mail
%%% @Author     : huangyongxing
%%% @Email      : huangyongxing@yeah.net
%%% @Created    : 2010.08.5
%%% @Description: 信件服务
%%%------------------------------------
-module(mod_mail).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export([start_link/0, stop/0, send_sys_mail/7, send_priv_mail/7]).
-include("common.hrl").
-include("record.hrl").

%%%------------------------------------
%%%             接口函数
%%%------------------------------------

%% 启动邮件服务
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% 发个人邮件
send_priv_mail(NameList, Title, Content, GoodsId, GoodsNum, Coin, PlayerStatus) ->
    gen_server:cast(?MODULE, {'send_priv_mail', [NameList, Title, Content, GoodsId, GoodsNum, Coin, PlayerStatus]}).

%% 发系统邮件
send_sys_mail(NameList, Title, Content, GoodsId, GoodsNum, Coin, Silver) ->
    gen_server:cast(?MODULE, {'send_sys_mail', [NameList, Title, Content, GoodsId, GoodsNum, Coin, Silver]}).

stop() ->
    gen_server:call(?MODULE, stop).

%%%------------------------------------
%%%             回调函数
%%%------------------------------------

init([]) ->
    process_flag(trap_exit, true),
    {ok, []}.

%% 发系统信件，返回处理结果（{ok, IList} | {error, Reason}）
handle_call({'send_sys_mail', [NameList, Title, Content, GoodsId, GoodsNum, Coin, Silver]}, _From, State) ->
    Reply = lib_mail:send_sys_mail(NameList, Title, Content, GoodsId, GoodsNum, Coin, Silver),
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%% 发私人信件
handle_cast({'send_priv_mail', [NameList, Title, Content, GoodsId, GoodsNum, Coin, PlayerStatus]}, State) ->
    case lib_mail:send_priv_mail(NameList, Title, Content, GoodsId, GoodsNum, Coin, PlayerStatus) of
        {ok, RName} ->
            {ok, BinData} = pt_19:write(19001, [1, []]),            %% 发送成功
            {ok, Bin} = pt_19:write(19005, 1),                      %% 通知收件人有未读邮件
            lib_send:send_to_nick(RName, Bin);
        {error, Reason} ->
            {ok, BinData} = pt_19:write(19001, [Reason, []]);

        {VList, IList} ->                                           %% {发送成功名单，发送失败名单}
            case IList of
                [] ->
                    {ok, BinData} = pt_19:write(19001, [1, []]);    %% 发送成功
                _ ->
                    {ok, BinData} = pt_19:write(19001, [6, IList])  %% 部分发送失败
            end,
            {ok, Bin} = pt_19:write(19005, 1),                      %% 通知收件人有未读邮件
            lists:foreach(fun(Nick) -> lib_send:send_to_nick(Nick, Bin) end, VList)
    end,
    %timer:sleep(5),    %% Erlang模拟客户端测试需要，分隔两个数据包
    lib_send:send_one(PlayerStatus#player_status.socket, BinData),  %% 通知发件人处理结果
    {noreply, State};

%% 发系统信件，不返回处理结果
handle_cast({'send_sys_mail', [NameList, Title, Content, GoodsId, GoodsNum, Coin, Silver]}, State) ->
    lib_mail:send_sys_mail(NameList, Title, Content, GoodsId, GoodsNum, Coin, Silver),
    {noreply, State};

%% 清理信件
handle_cast({'clean_mail'}, State) ->
    lib_mail:check_mail_time(),
    {noreplay, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
