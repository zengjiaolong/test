%%%--------------------------------------
%%% @Module  : db_mysql
%%% @Author  : ygzj
%%% @Created : 2010.10.25
%%% @Description: mysql 数据库操作  
%%%--------------------------------------
-module(db_mysql).
-include("common.hrl").
-include("record.hrl").
-compile([export_all]).

%% 插入数据表
insert(Table_name, FieldList, ValueList) ->
  stat_db_access(Table_name, insert),
  Sql = db_sql:make_insert_sql(Table_name, FieldList, ValueList),
  db_sql:execute(Sql).
insert(Table_name, Field_Value_List) ->
  stat_db_access(Table_name, insert),
  Sql = db_sql:make_insert_sql(Table_name, Field_Value_List),
  db_sql:execute(Sql).

%% 修改数据表(replace方式)
replace(Table_name, Field_Value_List) ->
	stat_db_access(Table_name, replace),
	Sql = db_sql:make_replace_sql(Table_name, Field_Value_List),
	db_sql:execute(Sql).

%% 修改数据表(update方式)
update(Table_name, Field, Data, Key, Value) ->
	stat_db_access(Table_name, update),
	Sql = db_sql:make_update_sql(Table_name, Field, Data, Key, Value),
	db_sql:execute(Sql).
update(Table_name, Field_Value_List, Where_List) ->
	stat_db_access(Table_name, update),
	Sql = db_sql:make_update_sql(Table_name, Field_Value_List, Where_List),
	db_sql:execute(Sql).

%% 获取一个数据字段
select_one(Table_name, Fields_sql, Where_List, Order_List, Limit_num) ->
	stat_db_access(Table_name, select),
	Sql = db_sql:make_select_sql(Table_name, Fields_sql, Where_List, Order_List, Limit_num),
 	db_sql:get_one(Sql).
select_one(Table_name, Fields_sql, Where_List) ->
	stat_db_access(Table_name, select),
	Sql = db_sql:make_select_sql(Table_name, Fields_sql, Where_List),
	db_sql:get_one(Sql).

%% 获取一条数据记录
select_row(Table_name, Fields_sql, Where_List, Order_List, Limit_num) ->
	stat_db_access(Table_name, select),
	Sql = db_sql:make_select_sql(Table_name, Fields_sql, Where_List, Order_List, Limit_num),
 	db_sql:get_row(Sql).
select_row(Table_name, Fields_sql, Where_List) ->
	stat_db_access(Table_name, select),
	Sql = db_sql:make_select_sql(Table_name, Fields_sql, Where_List),
	db_sql:get_row(Sql).

%% 获取记录个数 
select_count(Table_name, Where_List) ->
	?DB_MODULE:select_row(Table_name, "count(1)", Where_List).

%% 获取所有数据
select_all(Table_name, Fields_sql, Where_List, Order_List, Limit_num) ->
	stat_db_access(Table_name, select),
	Sql = db_sql:make_select_sql(Table_name, Fields_sql, Where_List, Order_List, Limit_num),
	db_sql:get_all(Sql).
select_all(Table_name, Fields_sql, Where_List) ->
	stat_db_access(Table_name, select),
	Sql = db_sql:make_select_sql(Table_name, Fields_sql, Where_List),
	db_sql:get_all(Sql).

%% 删除数据
delete(Table_name, Where_List) ->
	stat_db_access(Table_name, delete),	
	Sql = db_sql:make_delete_sql(Table_name, Where_List),
	db_sql:execute(Sql).

%% 事务处理
transaction(Fun) ->
	db_sql:transaction(Fun).
  
%% --------------------------------------------------------------------------
%%统计数据表操作次数和频率
stat_db_access(Table_name, Operation) ->
	try
		Key = lists:concat([Table_name, "/", Operation]),
		[NowBeginTime, NowCount] = 
		case ets:match(?ETS_STAT_DB,{Key, Table_name, Operation , '$4', '$5'}) of
			[[OldBeginTime, OldCount]] ->
				[OldBeginTime, OldCount+1];
			_ ->
				[yg_timer:now(),1]
		end,	
		ets:insert(?ETS_STAT_DB, {Key, Table_name, Operation, NowBeginTime, NowCount}),
		ok
	catch
		_:_ -> no_stat
	end.
%% --------------------------------------------------------------------------