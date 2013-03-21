%%%--------------------------------------
%%% @Module  : db
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.21
%%% @Description: 数据库操作 
%%%--------------------------------------
-module(db).
-include("record.hrl").
%-export([find/1, find/2, find/3, set/3, do/1, match/1, delete/1, delete/2, bump/1, bump/2, reset/1]).
%
%%%查找字段在表里面的位置
%field_num(Field, [])
%  when is_atom(Field) ->
%	none;
%
%field_num(Field, Fields)
%  when is_atom(Field),
%	   is_list(Fields) ->
%	field_num(Field, Fields, 1).
%
%field_num(_Field, [], _N) ->
%    none;
%
%field_num(Field, [H|T], N) ->
%	if
%		Field == H ->
%			N;
%		true ->
%			field_num(Field, T, N+1)
%	end.
%
%%%通过主键查找，更新表的字段的值（只更新一个字段）
%set(Table, Key, {Field, Value}, Fun)
%  when is_atom(Table),
%       is_atom(Field) ->
%    Fields = mnesia:table_info(Table, attributes),
%    case field_num(Field, Fields) of
%	none ->
%	    {atomic, {error, field_not_found}};
%	N ->
%	    F = fun() ->
%			case mnesia:read({Table, Key}) of
%			    [] ->
%				    {error, key_not_found};
%			    [Data] ->
%				    case Fun(element(N + 1, Data), Value) of
%				        {error, Reason} ->
%					        {error, Reason};
%				        Value1 ->
%					        Data1 = setelement(N + 1, Data, Value1),
%					    mnesia:write(Data1)
%				    end;
%			    Any ->
%				    Any
%			end
%		end,
%	    mnesia:transaction(F)
%    end.
%
%set(Table, Key, {Field, _Value} = V)
%  when is_atom(Table),
%       is_atom(Field) ->
%    F = fun(_Old, New) -> New end,
%    set(Table, Key, V, F);
%
%%%通过主键查找，更新表的字段的值(更新多个字段)
%%%Table:表名
%%%Key:主键值
%%%Values:要更新值和字段[{field, vaule},...]
%set(Table, Key, Values)
%  when is_atom(Table),
%       is_list(Values) ->
%    Fields = mnesia:table_info(Table, attributes),
%    case find(Table, Key) of
%	    {atomic, [Data]} ->
%	        set(Data, Fields, Values);
%	    Any ->
%	        Any
%    end;
%
%set(Data, _Fields, []) ->
%    mnesia:transaction(fun() -> mnesia:write(Data) end);
%
%set(Data, Fields, [{Field, Value}|Rest])
%  when is_tuple(Data),
%       is_list(Fields),
%       is_atom(Field) ->
%    case field_num(Field, Fields) of
%	    none ->
%	        {atomic, {error, field_not_found}};
%	    N ->
%	        Data1 = setelement(N + 1, Data, Value),
%	        set(Data1, Fields, Rest)
%    end.
%
%%% 生成一个 {table_name, '_', ...} 的匹配
%make_pat(Table)
%  when is_atom(Table) ->
%    Fields = mnesia:table_info(Table, attributes),
%    make_pat(Fields, [Table]).
%
%make_pat([], Acc) ->
%    list_to_tuple(lists:reverse(Acc));
%
%make_pat([_H|T], Acc) ->
%    make_pat(T, ['_'|Acc]).
%
%%%查找整个表得所有值
%find(Table) when is_atom(Table) ->
%    Pat = make_pat(Table),
%    F = fun() -> mnesia:match_object(Pat) end,
%    mnesia:transaction(F).
%
%%%% 按主键值去查找
%find(Table, KeyVal)
%  when is_atom(Table) ->
%    F = fun() -> mnesia:read({Table, KeyVal}) end,
%    mnesia:transaction(F).
%
%%%% 按其他索引值去查找
%find(Table, Field, Value)
%  when is_atom(Table),
%       is_atom(Field) ->
%    Fields = mnesia:table_info(Table, attributes),
%    case field_num(Field, Fields) of
%	    none ->
%	        {atomic, {error, field_not_found}};
%    	N ->
%	        F = fun() ->  mnesia:index_read(Table, Value, N + 1) end,
%	        mnesia:transaction(F)
%    end.
%
%%%删除表
%delete(Table)
%  when is_atom(Table) ->
%    mnesia:clear_table(Table).
%
%%%删除指定得记录
%%%Table:表名
%%%KeyVal:主键
%delete(Table, KeyVal)
%  when is_atom(Table) ->
%    F = fun() -> mnesia:delete({Table, KeyVal}) end,
%    mnesia:transaction(F).
%
%%%配置
%match(Pat) ->
%    F = fun() -> mnesia:match_object(Pat) end,
%    mnesia:transaction(F).
%
%%%执行一个QLC操作
%%%qlc
%do(Q) ->
%    F = fun() -> qlc:e(Q) end,
%    {atomic, Val} = mnesia:transaction(F),
%    Val.
%
%%%计数器
%%%Type：表名
%bump(Type) ->
%    bump(Type, 1).
%
%bump(Type, Inc) ->
%    mnesia:dirty_update_counter(counter, Type, Inc).
%
%%%重置计数器
%reset(Type) ->
%    Counter = #counter {
%      type = Type,
%      value = 0
%     },
%    mnesia:transaction(fun() ->
%			       mnesia:write(Counter)
%		       end).
	
