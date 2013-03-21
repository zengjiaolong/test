%%%--------------------------------------
%%% @Module  : pp_gateway
%%% @Author  : ygzj
%%% @Created : 2010.09.23
%%% @Description: 网关
%%%--------------------------------------
-module(pp_gateway).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%登陆验证
handle(60000, Status, _) ->
    List = mod_disperse:get_server_list(),
    {ok, Data} = pt_60:write(60000, List),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, Data);

%%是否有角色
handle(60001, Status, Bin) ->
    {Accname, _} = pt:read_string(Bin),
	Ret =
    case db_agent:is_create(Accname) of
        [] ->
            0;
        _R ->
            1
    end,
    {ok, Data} = pt_60:write(60001, Ret),	
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, Data);

handle(_Cmd, _Status, _Data) ->
    {error, "pp_gateway no match"}.
