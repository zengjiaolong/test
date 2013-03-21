%%%-----------------------------------
%%% @Module  : sd_schema
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.15
%%% @Description: 创建mnesia数据库
%%%-----------------------------------
-module(sd_schema).
%-export([install/0, wait_for_tables/0]).
%-include("record.hrl").
%
%%%安装数据库
%install() ->
%    mnesia:stop(),
%    mnesia:delete_schema([node()]),
%    catch(mnesia:create_schema([node()])),
%    mnesia:start(),
%    create_tables(),
%    ok.
%
%%% 数据表数据
%table_definitions() ->
%    [
%        {
%            server,
%             [
%                  {disc_copies, [node()]},
%                  {index, [ip, port]},
%                  {type, set},
%                  {attributes, record_info(fields, server)}
%            ]
%        },
%        {
%            counter,
%             [
%                  {disc_copies, [node()]},
%                  {type, set},
%                  {attributes, record_info(fields, counter)}
%             ]
%        },
%        {
%            player,
%            [
%                {disc_copies, [node()]},
%                {index, [accname, nickname, scene, guild_id]},
%                {type, set},
%                {attributes, record_info(fields, player)}
%            ]
%        },
%        {
%            relationship,
%            [
%                {disc_copies, [node()]},
%                  {index, [idA]},
%                {type, set},
%                {attributes, record_info(fields, relationship)}
%            ]
%        },
%        {
%            friend_group,
%            [
%                {disc_copies, [node()]},
%                {type, set},
%                {attributes, record_info(fields, friend_group)}
%            ]
%        },
%        {
%            guild,
%            [
%                {disc_copies, [node()]},
%                {index, [initiator_id, chief_id]},
%                {type, set},
%                {attributes, record_info(fields, guild)}
%            ]
%        },
%        {
%            guild_member,
%            [
%                {disc_copies, [node()]},
%                {index, [guild_id]},
%                {type, set},
%                {attributes, record_info(fields, guild_member)}
%            ]
%        },
%        {
%            guild_apply,
%            [
%                {disc_copies, [node()]},
%                {index, [guild_id, player_id]},
%                {type, set},
%                {attributes, record_info(fields, guild_apply)}
%            ]
%        },
%        {
%            guild_invite,
%            [
%                {disc_copies, [node()]},
%                {index, [guild_id, player_id]},
%                {type, set},
%                {attributes, record_info(fields, guild_invite)}
%            ]
%        }
%     ].
%
%%%创建所有表
%create_tables() ->
%    lists:foreach(fun ({Tab, TabArgs}) ->
%                          case mnesia:create_table(Tab, TabArgs) of
%                              {atomic, ok} -> ok;
%                              {aborted, Reason} ->
%                                  throw({error, {table_creation_failed,
%                                                 Tab, TabArgs, Reason}})
%                          end
%                  end,
%                  table_definitions()),
%    ok.
%
%%%获取表名
%table_names() ->
%    [Tab || {Tab, _} <- table_definitions()].
%
%%%登陆加载完表
%wait_for_tables() -> wait_for_tables(table_names()).
%wait_for_tables(TableNames) ->
%    case check_schema_integrity() of
%        ok ->
%            case mnesia:wait_for_tables(TableNames, 30000) of
%                ok -> ok;
%                {timeout, BadTabs} ->
%                    throw({error, {timeout_waiting_for_tables, BadTabs}});
%                {error, Reason} ->
%                    throw({error, {failed_waiting_for_tables, Reason}})
%            end;
%        {error, Reason} ->
%            throw({error, {schema_integrity_check_failed, Reason}})
%    end.
%
%%%检查数据表
%check_schema_integrity() ->
%    %%TODO: more thorough checks
%    case catch [mnesia:table_info(Tab, version) || Tab <- table_names()] of
%        {'EXIT', Reason} -> {error, Reason};
%        _ -> ok
%    end.
