%% Author: zj
%% Created: 2011-8-1
%% Description: TODO:  flash策略文件请求处理
-module(yg_flash_843).

-export([start_link/0, stop/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("common.hrl").

%% 开启连接监听服务
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% 关闭连接监听服务
stop() ->
    ok.

init([]) ->
    Port = 843,
    case gen_tcp:listen(Port, ?TCP_OPTIONS) of
        {ok, LSock} ->
            spawn_link(fun() -> loop(LSock) end),
            {ok, state};
        {error, _Reason}->
            {stop, listen_failure, state}
    end.

handle_call(_Request, _From, State) ->
    {noreply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

loop(LSock) ->
    case gen_tcp:accept(LSock) of
        {ok, Sock} -> spawn(fun()-> send_file(Sock) end);
        {error, Reason} -> Reason
    end,
    loop(LSock).

%%发送安全策略文件
send_file(Sock) ->
    case gen_tcp:recv(Sock, 6) of
        {ok, ?FL_POLICY_REQ} -> 
			%%?DEBUG("---843-SEND-FILE:~~n",[]),
			gen_tcp:send(Sock, ?FL_POLICY_FILE);
        _r -> 
			error
    end,
    gen_tcp:close(Sock).