%%%--------------------------------------
%%% @Module  : db_mongo
%%% @Author  : ygzj
%%% @Created : 2010.10.25
%%% @Description: mongodb 数据库操作  
%%%--------------------------------------
-module(db_mongo).
-include("common.hrl").
-include("record.hrl").
-compile(export_all).

findAndModify(Collection, Table_name, Key) ->
	findAndModify(?MASTER_POOLID,Collection, Table_name, Key).

findAndModify(POOLID,Collection, Table_name, Key) ->
	Id = emongo:findAndModify(tool:to_list(POOLID),tool:to_list(Collection), tool:to_list(Table_name), tool:to_list(Key)),
	case Id of 
		undefined -> 0;
		_ -> Id
	end.

%%插入数据时会先检查哪些域没有数据，然后添加相应的域，默认值，mongo不能处理默认值
insert(Table_name, FieldList, ValueList) ->	
  insert(?MASTER_POOLID,Table_name, FieldList, ValueList).

insert(POOLID,Table_name, FieldList, ValueList) ->	
  stat_db_access(Table_name, insert),
  IdValue = findAndModify(POOLID, "auto_ids", Table_name, "id"), 
  FullKeyValuelist = fullKeyValue(Table_name,lists:zip([id|FieldList],[IdValue|ValueList])),
  Opertion = db_mongoutil:make_insert_opertion(Table_name,FullKeyValuelist),
  try
  		emongo:insert(tool:to_list(POOLID),tool:to_list(Table_name),Opertion)
  catch
	  _:_ ->
		  ?ERROR_MSG("db_mongo insert error :~p/~p~n", [POOLID,Table_name])
  end,
  trunc(IdValue).

%%填充默认域和默认值，mongo不能添加默认值
fullKeyValue(Table_name,KeyValuesList) ->
	try
		 FieldsDefaultValueList =  lib_player_rw:get_table_fields(Table_name),%%[{id,0},{name,""},{age,0}]
		 F1 = fun({Key,NewValue},NewValueList) ->
					 lists:keyreplace(Key, 1, NewValueList, {Key,NewValue})
			 end,
		 lists:foldl(F1, FieldsDefaultValueList, KeyValuesList)
	catch
		_:_ ->
			 ?ERROR_MSG("fullKeyValue error :~p/~p~n", [tool:to_list(Table_name),KeyValuesList])
	end.


%% 删除数据
delete(Table_name, Where_List) ->
	delete(?MASTER_POOLID,Table_name, Where_List).

delete(POOLID,Table_name, Where_List) ->
	stat_db_access(Table_name, delete),
	[Opertion] = db_mongoutil:make_delete_opertion(Where_List),
	emongo:delete(atom_to_list(POOLID),atom_to_list(Table_name),Opertion),
	1.

%% 获取一个数据
select_one(Table_name, Fields_sql_string) ->
	select_one(Table_name, Fields_sql_string, [], [], []).

%% 获取一个数据
select_one(Table_name, Fields_sql_string, Where_List) ->
	select_one(Table_name, Fields_sql_string, Where_List, [], []).

%% 获取一个数据
select_one(Table_name, Fields_sql_string, Where_List, Limit_sql_List) ->
	select_one(Table_name, Fields_sql_string, Where_List,[], Limit_sql_List).

%% 获取一个数据
select_row(Table_name, Fields_sql_string) ->
	select_row(Table_name, Fields_sql_string, [], [], []).

%% 获取一个数据
select_row(Table_name, Fields_sql_string, Where_List) ->
	select_row(Table_name, Fields_sql_string, Where_List, [], []).

%% 获取一个数据
select_row(Table_name, Fields_sql_string, Where_List, Limit_sql_List) ->
	select_row(Table_name, Fields_sql_string, Where_List, [], Limit_sql_List).

%% 获取记录个数(相当于mysql count()) 
select_count(Table_name, Where_List) ->
	select_count(?MASTER_POOLID, Table_name, Where_List).

select_count(PoolId, Table_name, Where_List) ->
	Data = emongo:count(tool:to_list(db_mongoutil:get_slave_mongo_poolId(PoolId)),tool:to_list(Table_name),db_mongoutil:make_where_opertion(Where_List)),
	case Data == undefined of
		true -> [0];
		_ -> [Data]
	end.

%%将"*","id,name,age" -> [] 或["id","name","age"]
transfer_fields(Table_name,Fields_sql_string) ->
	L = 
	case Fields_sql_string of
		"*" -> 
			get_all_fields(Table_name);
		"" ->  
			[];
		_ ->   
			string:tokens(tool:remove_string_black(Fields_sql_string),",")
	end,
	case L of
		[] -> [];
		_ ->
			[tool:to_atom(R) || R <- L]
	end.

get_all_fieldsDefaultList(Table_name) ->
	FieldsValueList =  lib_player_rw:get_table_fields(Table_name),
	KeyList = [Key || {Key, _DefaultValue} <- FieldsValueList],
	DefaultValueList = [DefaultValue || {_Key, DefaultValue} <- FieldsValueList],
	{KeyList,DefaultValueList}.
																	
get_all_fields(Table_name) ->
	FieldsValueList =  lib_player_rw:get_table_fields(Table_name),
	[Key || {Key, _DefaultValue} <- FieldsValueList].
	

%% 获取一个数据
%% Fields_sql_List  : ["id","name","age"]
%% Where_List       : [{id,1},{name,"zs"}]
%% Limit_sql_List   : [{limit,1}]
%% Orderby_sql_List : [{timde,desc}]
select_one(Table_name, Fields_sql_string, Where_List, Orderby_sql_List, Limit_sql_List) ->
	stat_db_access(Table_name, select),
%%	?DEBUG("SELECT_ONE:~p / ~p ~n",[Table_name,Fields_sql_string]),
	[WhereOpertion,FieldOpertion] = db_mongoutil:make_select_opertion(transfer_fields(Table_name,Fields_sql_string), Where_List, Orderby_sql_List, Limit_sql_List),
	Result = emongo:find_one(tool:to_list(?MASTER_POOLID),tool:to_list(Table_name),WhereOpertion,FieldOpertion),
	R = 
		case Result of
			[] -> [];
			_ ->
				[R1] = Result,
				R1
		end,
	handle_one_result(Table_name,transfer_fields(Table_name,Fields_sql_string),R).

%% 获取从数据库中一个数据
%% Fields_sql_List  : ["id","name","age"]
%% Where_List       : [{id,1},{name,"zs"}]
%% Limit_sql_List   : [{limit,1}]
%% Orderby_sql_List : [{timde,desc}]
select_one(PoolId, Table_name, Fields_sql_string, Where_List, Orderby_sql_List, Limit_sql_List) ->
    stat_db_access(Table_name, select),
%%	?DEBUG("SELECT_ONE:~p / ~p ~n",[Table_name,Fields_sql_string]),
	[WhereOpertion,FieldOpertion] = db_mongoutil:make_select_opertion(transfer_fields(Table_name,Fields_sql_string), Where_List, Orderby_sql_List, Limit_sql_List),
	Result = emongo:find_one(tool:to_list(db_mongoutil:get_slave_mongo_poolId(PoolId)),tool:to_list(Table_name),WhereOpertion,FieldOpertion),
	R = 
		case Result of
			[] -> [];
			_ ->
				[R1] = Result,
				R1
		end,
	handle_one_result(Table_name,transfer_fields(Table_name,Fields_sql_string),R).

%% 获取从数据库中一个数据
%% Fields_sql_List  : ["id","name","age"]
%% Where_List       : [{id,1},{name,"zs"}]
%% Limit_sql_List   : [{limit,1}]
%% Orderby_sql_List : [{timde,desc}]
select_one_new(PoolId, Table_name, Fields_sql_string, Where_List, Orderby_sql_List, Limit_sql_List) ->
    stat_db_access(Table_name, select),
%%	?DEBUG("SELECT_ONE_NEW:~p / ~p ~n",[Table_name,Fields_sql_string]),
	[WhereOpertion,FieldOpertion] = db_mongoutil:make_select_opertion(transfer_fields(Table_name,Fields_sql_string), Where_List, Orderby_sql_List, Limit_sql_List),
	Result = emongo:find_one(tool:to_list(PoolId),tool:to_list(Table_name),WhereOpertion,FieldOpertion),
	R = 
		case Result of
			[] -> [];
			_ ->
				[R1] = Result,
				R1
		end,
	handle_one_result(Table_name,transfer_fields(Table_name,Fields_sql_string),R).

%%主数据库中取数据
select_row(Table_name, Fields_sql_string, Where_List, Orderby_sql_List, _Limit_sql_List) ->
	stat_db_access(Table_name, select),
%%	?DEBUG("SELECT_ROW:~p / ~p ~n",[Table_name,Fields_sql_string]),
	[WhereOpertion,FieldOpertion] = db_mongoutil:make_select_opertion(transfer_fields(Table_name,Fields_sql_string), Where_List, Orderby_sql_List, [1]),
	Result = emongo:find_one(tool:to_list(?MASTER_POOLID),tool:to_list(Table_name),WhereOpertion,FieldOpertion),
	R = 
		case Result of
			[] -> [];
			_ ->
				[R1] = Result,
				R1
		end,
	handle_row_result(Table_name,transfer_fields(Table_name,Fields_sql_string),R).

%%从数据库中取数据
select_row(PoolId, Table_name, Fields_sql_string, Where_List, Orderby_sql_List, _Limit_sql_List) ->
    stat_db_access(Table_name, select), 
%%	?DEBUG("SELECT_ROW:~p / ~p ~n",[Table_name,Fields_sql_string]),
	[WhereOpertion,FieldOpertion] = db_mongoutil:make_select_opertion(transfer_fields(Table_name,Fields_sql_string), Where_List, Orderby_sql_List, [1]),
	Result = emongo:find_one(tool:to_list(db_mongoutil:get_slave_mongo_poolId(PoolId)),tool:to_list(Table_name),WhereOpertion,FieldOpertion),
	R = 
		case Result of
			[] -> [];
			_ ->
				[R1] = Result,
				R1
		end,
	handle_row_result(Table_name,transfer_fields(Table_name,Fields_sql_string),R).

handle_one_result(Table_name,Fields_sql_List,ResuList) ->
	case ResuList of
			[] ->
				null;
			_ ->
				[Value] = [proplists:get_value(tool:to_binary(tool:to_list(lists:nth(1,Fields_sql_List))),ResuList)],
				Value1 = float_to_integer(Value),
				transfer_default_result(Table_name,lists:nth(1,Fields_sql_List),Value1)
	end.

handle_row_result(Table_name,Fields_sql_List,ResuList) ->
	case ResuList  of 
		[] -> [];
		_ ->
			Size = length(Fields_sql_List),
			%%查询所有域情况，返回查询结果
			case Size of
				0 ->
					F = fun({Key,Value}) ->
								Value1 = float_to_integer(Value),
								transfer_default_result(Table_name,tool:to_atom(Key),Value1)
						end,
					[F({Key,Value}) || {Key,Value} <- ResuList,Key =/= <<"_id">>];
				%%只处理查询一个域的情况，其余返回指定域查询结果
				1 ->[Value] = [proplists:get_value(list_to_binary(tool:to_list(lists:nth(1,Fields_sql_List))),ResuList)],
					[float_to_integer(Value)];
				%%只处理查询多个域的情况，其余返回指定域查询结果
				_ ->
					F = fun(P) ->
								Value = proplists:get_value(list_to_binary(tool:to_list(P)),ResuList),
								case Value of
									undefined -> 
										transfer_default_result(Table_name,tool:to_atom(P),undefined);
									_ -> 
										float_to_integer(Value)
								end
						end,	
					[F(P) || P <- Fields_sql_List]
			end
	end.

%%处理查询结果，如果结果为Value==undefined则将Value转换为默认值
transfer_default_result(Table_name,Field,Value) ->
    FieldsDefaultValueList =  lib_player_rw:get_table_fields(Table_name),%%[{id,0},{name,""},{age,0}]
	case Value of
		undefined -> 
			case lists:keyfind(Field, 1, FieldsDefaultValueList) of
				{_Key,Value1} -> Value1;
				_ -> undefined
			end;
		_ -> Value
	end.

%% 获取所有数据
select_all(Table_name, Fields_sql_string) ->
	select_all(Table_name, Fields_sql_string, [], [], []).

%% 获取所有数据
select_all(Table_name, Fields_sql_string, Where_List) ->
	select_all(Table_name, Fields_sql_string, Where_List, [], []).

%% 获取所有数据
select_all(Table_name, Fields_sql_string, Where_List, Limit_sql_List) ->
	select_all(Table_name, Fields_sql_string, Where_List, [], Limit_sql_List).

%% 获取所有数据
%% Fields_sql_List   : ["id","name","age"]
%% Where_List        : [{id,1},{name,"zs"}]
%% Limit_sql_List    : [1,0]前面是limit,后面是初始行，用于分页查询
%% Orderby_sql_List  : [{timde,desc}]
select_all(Table_name, Fields_sql_string, Where_List, Orderby_sql_List, Limit_sql_List) ->
	stat_db_access(Table_name, select),
%%		?DEBUG("SELECT_ALL:~p / ~p  /~p ~n",[Table_name,Fields_sql_string,Where_List]),
	[WhereOpertion,FieldOpertion] = db_mongoutil:make_select_opertion(transfer_fields(Table_name,Fields_sql_string), Where_List, Orderby_sql_List, Limit_sql_List),
	L = emongo:find_all(tool:to_list(?MASTER_POOLID),tool:to_list(Table_name),WhereOpertion,FieldOpertion),
	handle_all_result(Table_name,transfer_fields(Table_name,Fields_sql_string), L).

%% 获取从数据库中所有数据
select_all(PoolId, Table_name, Fields_sql_string, Where_List, Orderby_sql_List, Limit_sql_List) ->
    stat_db_access(Table_name, select),
%%	?DEBUG("SELECT_ALL:~p / ~p  /~p ~n",[Table_name,Fields_sql_string,Where_List]),
	[WhereOpertion,FieldOpertion] = db_mongoutil:make_select_opertion(transfer_fields(Table_name,Fields_sql_string), Where_List, Orderby_sql_List, Limit_sql_List),
	L = emongo:find_all(tool:to_list(db_mongoutil:get_slave_mongo_poolId(PoolId)),tool:to_list(Table_name),WhereOpertion,FieldOpertion),
	handle_all_result(Table_name,transfer_fields(Table_name,Fields_sql_string), L).

%% 获取指定条件的信息并按条件对应返回结果
select_all_sequence(Table_name, Fields_sql_string, Where_List, Orderby_sql_List, Limit_sql_List) ->
	stat_db_access(Table_name, select),
%%	?DEBUG("SELECT_ALL_SEQ:~p / ~p  /~p ~n",[Table_name,Fields_sql_string,Where_List]),
	[WhereOpertion,FieldOpertion] = db_mongoutil:make_select_sequence_opertion(transfer_fields(Table_name,Fields_sql_string), Where_List, Orderby_sql_List, Limit_sql_List),
	L = emongo:find_all(tool:to_list(?MASTER_POOLID),tool:to_list(Table_name),WhereOpertion,FieldOpertion),
	handle_all_sequence_result(Table_name,transfer_fields(Table_name,Fields_sql_string), L, WhereOpertion, FieldOpertion).

%% 获取从数据库中所有数据
select_all_union(PoolId, Table_name, Fields_sql_string, Where_List, Orderby_sql_List, Limit_sql_List) ->
    stat_db_access(Table_name, select),
	[WhereOpertion,FieldOpertion] = db_mongoutil:make_select_opertion(transfer_fields(Table_name,Fields_sql_string), Where_List, Orderby_sql_List, Limit_sql_List),
	L = emongo:find_all(tool:to_list(PoolId),tool:to_list(Table_name),WhereOpertion,FieldOpertion),
	handle_all_result(Table_name,transfer_fields(Table_name,Fields_sql_string), L).

%%适用于通过唯一字段如Id,查询用户的其它唯一信息(vip,nickname)
handle_all_sequence_result(Table_name, Fields_sql_List, ResuList, WhereOpertion, FieldOpertion) ->
	case ResuList of
		[] -> [];
		_ ->
			[{_Field,[{in,CondictionData}]}] = WhereOpertion,
			[{fields, FieldList}] = FieldOpertion,

			ResuList1 =
			case length(Fields_sql_List) == 0 of 
				true ->
					F = fun(R) ->
								F1 = fun({Key,Value}) ->
											 Value1 = float_to_integer(Value),
											 transfer_default_result(Table_name,tool:to_atom(Key),Value1)
									 end,
								[F1({Key,Value}) || {Key,Value} <- R,Key =/= <<"_id">>]
						end,
					[F(R) || R <- ResuList];
				false ->
					F = fun(R) ->
								F1 = fun(P) ->
											 Value = proplists:get_value(list_to_binary(tool:to_list(P)), R),
											 Value1 = float_to_integer(Value),
											 transfer_default_result(Table_name,tool:to_atom(P),Value1)
									 end,
								[F1(P) || P <- FieldList]
						end,
					[F(R) || R <- ResuList]
			end,
			F3 = fun(Num) ->
						 Elem = lists:nth(Num, CondictionData),
						 R4 = [lists:sublist(R3, length(R3)-1) || R3 <- ResuList1, lists:nth(length(R3), R3) == Elem],
						 case R4 of
							 [] -> [];
							 [H|_Rest]->H
						 end								 
				 end,
			[F3(Num) || Num <- lists:seq(1, length(CondictionData))]
	end.

handle_all_result(Table_name, Fields_sql_List, ResuList) ->
	case ResuList of
		[] -> [];
		_ ->
			case Fields_sql_List == [] of 
				true ->
					F = fun(R) ->
								F1 = fun({Key,Value}) ->
											 Value1 = float_to_integer(Value),
											 transfer_default_result(Table_name,tool:to_atom(Key),Value1)
									 end,
								[F1({Key,Value}) || {Key,Value} <- R,Key =/= <<"_id">>]
						end,
					[F(R) || R <- ResuList];
				false ->
					F = fun(R) ->
								F1 = fun(P) ->
											 Value = proplists:get_value(list_to_binary(atom_to_list(P)), R),
											 Value1 = float_to_integer(Value),
											 transfer_default_result(Table_name,tool:to_atom(P),Value1)
									 end,
								[F1(P) || P <- Fields_sql_List]
						end,
					[F(R) || R <- ResuList]
			end
	end.
		
%%从emongo中取出来的数字型为浮点型,转化为整形，故要进行转换处理
float_to_integer(Value) ->
	case (is_float(Value) andalso (Value == trunc(Value))) of 
		true -> trunc(Value);
		false -> Value
	end.

%%两表联合查询 传七个参数
%%Table_name1 is guild_member
%%Fields_sql_List1 is [id,guild_id,guild_name],
%%Where_List1 is [{guild_id, GuildId}]
%%Condiction1 is "player_id"
%%Table_name2 is player
%%Fields_sql_List2 is [sex, jobs, lv, guild_position],
%%Condiction2 is "id"

select_one_from_uniontable(Table_name1,Fields_sql_List1,Where_List1,Condiction1,Table_name2,Fields_sql_List2,Condiction2) ->
	R1 = select_one(Table_name1, Fields_sql_List1, Where_List1),
	Value = proplists:get_value(db_mongoutil:to_dbdata(Condiction1), R1),
	Where_List2 = [{Condiction2,Value}],
	R2 = select_one(Table_name2, Fields_sql_List2, Where_List2),
	case (R1 == [] orelse R2 == []) of
		true -> [];
		false ->
			R1++R2
	end.


%%两张表或三张表关联查询
%%[{stu,[id,name,age]},{tea,[id,name,stuid,courseid]},{cour,[id,name]}],[{stu,[id,1]},{stu,[age,10]}],[{stu.id,tea.stuid},{tea.courseid,cour.id}],[],[]
select_all_from_multtable(Tablefield_List,Where_List,UnionList,_Orderby_sql_List, _Limit_sql_List) ->
	Tablefield_ListSize = length(Tablefield_List),
	case Tablefield_ListSize of
		2 ->%%两张表关联
			{Tab,TabFieldList} = lists:nth(1,Tablefield_List),
			TableWhereList = get_table_whereList(Tab,Where_List,[]),
			[WhereOpertion,FieldOpertion] = db_mongoutil:make_select_opertion(TabFieldList, TableWhereList, [], []),
			Result1 = emongo:find_all(tool:to_list(?MASTER_POOLID),tool:to_list(Tab),WhereOpertion,FieldOpertion),
			L = 
			case Result1 of
				[] ->[];
				_ ->
					F1 = fun(R) ->
								 {Tab2,TabFieldList2} = lists:nth(2,Tablefield_List),
								 UnionFiledList = get_table_unionList(Tab,UnionList),
								 Field1 = lists:nth(1,UnionFiledList),
								 Field2 = lists:nth(2,UnionFiledList),
								 Value = proplists:get_value(db_mongoutil:to_dbdata(Field1), R),
								 WhereList2 = get_table_whereList(Tab2,Where_List,[])++[{list_to_atom(Field2),Value}],
								 [WhereOpertion2,FieldOpertion2] = db_mongoutil:make_select_opertion(TabFieldList2, WhereList2, [], []),
								 Result2 = emongo:find_all(tool:to_list(?MASTER_POOLID),tool:to_list(Tab2),WhereOpertion2,FieldOpertion2),
								 case Result2 of
									 [] -> [];
									 _ ->
										 F2 = fun(R2) ->
													  handleOrderResult(Tab,TabFieldList,R)++R2
											  end,
										 [M] = [F2(handleOrderResult(Tab2,TabFieldList2,R2)) || R2 <- Result2,length(R2)>0],
										  M
								 end
						 end,
					[F1(R) || R <- Result1]
			end,
			case L of 
				[[]] -> [];
				[] -> [];
				_ ->
					 lists:filter(fun(T)-> T =/= [] end, L)
			end;
		3 ->%%三张表关联
			{Tab,TabFieldList} = lists:nth(1,Tablefield_List),
			TableWhereList = get_table_whereList(Tab,Where_List,[]),
			[WhereOpertion,FieldOpertion] = db_mongoutil:make_select_opertion(TabFieldList, TableWhereList, [], []),
			Result1 = emongo:find_all(tool:to_list(?MASTER_POOLID),tool:to_list(Tab),WhereOpertion,FieldOpertion),
			AllResult =  
			case Result1 of
				[] ->[];
				_ ->
					F1 = fun(R) -> %%第二张表的查询
								 {Tab2,TabFieldList2} = lists:nth(2,Tablefield_List),
								 UnionFiledList = get_table_unionList(Tab,UnionList),
								 Field1 = lists:nth(1,UnionFiledList),
								 Field2 = lists:nth(2,UnionFiledList),
								 Value = proplists:get_value(db_mongoutil:to_dbdata(Field1), R),
								 WhereList2 = get_table_whereList(Tab2,Where_List,[])++[{list_to_atom(Field2),Value}],
								 [WhereOpertion2,FieldOpertion2] = db_mongoutil:make_select_opertion(TabFieldList2, WhereList2, [], []),
								 Result2 = emongo:find_all(tool:to_list(?MASTER_POOLID),tool:to_list(Tab2),WhereOpertion2,FieldOpertion2),
								 L = 
								 case Result2 of
									 [] -> [];
									 _ ->
										 F2 = fun(R2) ->
													  handleOrderResult(Tab,TabFieldList,R)++R2
											  end,
										 [F2(handleOrderResult(Tab2,TabFieldList2,R2)) || R2 <- Result2,length(R2)>0]
								 end,
								 case L of
									 [] -> [];
									 _ ->
										 %%处理第三张表记录
										 F3 = fun(T1) ->
													  {Tab3,TabFieldList3} = lists:nth(3,Tablefield_List),
													  UnionFiledList3 = get_table_unionList(Tab2,UnionList),
													  Field3 = lists:nth(1,UnionFiledList3),
													  Field4 = lists:nth(2,UnionFiledList3),
													  Value4 = proplists:get_value(db_mongoutil:to_dbdata(Field3), T1),
													  WhereList4 = get_table_whereList(Tab3,Where_List,[])++[{list_to_atom(Field4),Value4}],
													  [WhereOpertion4,FieldOpertion4] = db_mongoutil:make_select_opertion(TabFieldList3, WhereList4, [], []),
													  Result3 = emongo:find_all(tool:to_list(?MASTER_POOLID),tool:to_list(Tab3),WhereOpertion4,FieldOpertion4),
													  L1 =
													  case Result3 of
														  [] -> [];
														  _ -> 
															  F3 = fun(R3) ->
																		   case R3 of
																			   [] -> [];
																			   _ ->
																				   T1++R3
																		   end
																   end,
															  [F3(handleOrderResult(Tab3,TabFieldList3,R3)) || R3 <- Result3,length(R3)>0]
													  end,
													  case L1 of
														  [] -> [];
														  [T] -> 
															  T
													  end
											  end,
										 [F3(T1) || T1 <- L]

								 end
						 end,
					[F1(R) || R <- Result1]
			end,
			case AllResult of
				[[]] -> [];
				[] -> [];
				_ ->
					[H] = AllResult,
					F4 = fun(H1) ->
								[Value||{_Key,Value} <- H1] 
						 end,
					[F4(H1) || H1 <- H,length(H1)>0]%%删除列表中的空元素
			end
	end.


select_row_from_multtable(Tablefield_List,Where_List,UnionList,Orderby_sql_List, Limit_sql_List) ->
	Result = select_all_from_multtable(Tablefield_List,Where_List,UnionList,Orderby_sql_List, Limit_sql_List),
	case Result of
		[] -> [];
		_ ->
			[R] = Result,
			R
	end.
		
	
get_table_whereList(Table,[H|T],ConcatLists) ->
	case H of
		{Tab,WhereList} ->
			case Table == Tab of
				false ->
					get_table_whereList(Table,T,ConcatLists);
				true ->
					get_table_whereList(Table,T,[WhereList|ConcatLists])
			end;
		_ -> []
	end;
get_table_whereList(_Table,[],ConcatLists) ->
	case ConcatLists of
		[] ->
			[];
		_ ->
			F = fun(Concat) ->
						[Key,Value] = Concat,
						{Key,Value}
				end,
			[F(Concat) || Concat <- ConcatLists]
	end.
			
%%按域顺序返回查询结果，mongo是按表的字段顺序返回指定域的结果，不是按指定字段顺序返回结果
handleOrderResult(Table_name,FieldList,ResultList) ->
	FieldListSize = length(FieldList),
	F = fun(Field,Value) ->
				Value1 = float_to_integer(Value),
				transfer_default_result(Table_name,tool:to_atom(Field),Value1)
		end,
	[F(lists:nth(I, FieldList),proplists:get_value(db_mongoutil:to_dbdata(lists:nth(I, FieldList)), ResultList)) || I <- lists:seq(1,FieldListSize)].


%%要求按表对应的顺序关联
get_table_unionList(Table,UnionLists) ->
	F = fun(UnionField) ->
				{TabUnionField,Tab1UnionField} = UnionField,
				TabFieldString = atom_to_list(TabUnionField),
				TabFieldString1 = atom_to_list(Tab1UnionField),
				[Tab,Field] = string:tokens(TabFieldString,"."),
				[_Tab1,Field1]= string:tokens(TabFieldString1,"."),
				case atom_to_list(Table) == Tab of
					false -> [];
					true ->
						[Field,Field1]
				end
		end,
	L = [F(UnionField) || UnionField <- UnionLists],
	case L of
		[] -> [];
		[T] -> T;
		[T,[]] ->
			T;
		[[],T] ->
			T
	end.
	

%%更新指定数据 
%% Fields_sql_List   : [{name,"zs1"},{age,20}]
%% Where_List        : [{id,1},{name,"zs"}]
%% emongo:update(test1,"player", [{<<"id">>,2031}],[{"$set",[{<<"online_flag">>,1},{<<"last_login_time">>,1288584018}]},{"$inc",[]}]).
update(Table_name, Fields_sql_List, Where_List) ->
	update(?MASTER_POOLID, Table_name, Fields_sql_List, Where_List).

update(POOLID, Table_name, Fields_sql_List, Where_List) ->
	stat_db_access(Table_name, update),
%%	?DEBUG("UPDATE:~p / ~p  /~p ~n",[Table_name,Fields_sql_List,Where_List]),
	[WhereOpertion,Fieldopertion] = db_mongoutil:make_update_opertion(Fields_sql_List, Where_List),
	emongo:update(tool:to_list(POOLID),tool:to_list(Table_name),WhereOpertion,Fieldopertion),
	1.

%%更新指定数据 
%% Fields_sql_List   : [name,age]
%% Value_List        : ["zs",10]
%% Where_List        : [{id,1},{name,"zs"}]
%% Fieldstring       : "id",
%% FieldValue        : 12001
%% emongo:update(test1,"player", [{<<"id">>,2031}],[{"$set",[{<<"online_flag">>,1},{<<"last_login_time">>,1288584018}]},{"$inc",[]}]).
update(Table_name, Fields_sql_List, Value_List, Fieldstring, FieldValue) ->
	update(?MASTER_POOLID, Table_name, Fields_sql_List, Value_List, Fieldstring, FieldValue).

update(POOLID, Table_name, Fields_sql_List, Value_List, Fieldstring, FieldValue) ->
	stat_db_access(Table_name, update),
%%	?DEBUG("UPDATE:~p / ~p  /~p ~n",[Table_name,Fields_sql_List,Value_List]),
	%%启动更新coin_sum字段进程 
	Fields_List = db_mongoutil:make_conn_opertion(Fields_sql_List,Value_List),
	Where_List = [{Fieldstring,FieldValue}],
	[WhereOpertion,Fieldopertion] = db_mongoutil:make_update_opertion(Fields_List, Where_List),
	emongo:update(tool:to_list(POOLID),tool:to_list(Table_name),WhereOpertion,Fieldopertion),
	1.

%% 修改数据表(replace方式)
%% Field_Value_List : [{id,1},{name,"zs1"},{age,20}] 其中id为主键 
replace(Table_name, Field_Value_List) ->
	replace(?MASTER_POOLID, Table_name, Field_Value_List) .

replace(POOLID, Table_name, Field_Value_List) ->
	stat_db_access(Table_name, replace),
	[_WhereOpertion,Fieldopertion] = db_mongoutil:make_replace_opertion(Field_Value_List),
	Opertion = db_mongoutil:make_insert_opertion(Table_name,Field_Value_List),
	{Index,Value} =  lists:nth(1,Field_Value_List),
	case isExistId(Table_name,Index,Value) of
		false -> %%插入数据
			emongo:insert(atom_to_list(POOLID),atom_to_list(Table_name),Opertion);
		true -> %%更新数据
			emongo:update(atom_to_list(POOLID),atom_to_list(Table_name),[{tool:to_binary(tool:to_list(Index)),Value}],Fieldopertion)
	end,	
	1.


%%更改数据库列名
%%Table_name表名 player
%%OrderByKey一键 "id"
%%OldField原有的列名 "id"
%%NewField新的列名 "id1"
%%sleep根据数据大小调节删除和更新的时间间隔
column_rename(Table_name, OrderByKey, OldField, NewField) ->
	[WhereOpertion,FieldOpertion] = db_mongoutil:make_select_opertion(transfer_fields(Table_name,"*"), [{OrderByKey,"<>",null}], [{OrderByKey,asc}],[]),
	Result = emongo:find_all(tool:to_list(?MASTER_POOLID),tool:to_list(Table_name),WhereOpertion,FieldOpertion),
	case Result of 
		[] -> skip; %%表中没有数据
		_ -> 
			%%先取其中一条数据，判断列名是否存在
			RR = lists:nth(1,Result),
			case isExistColumn(OldField,RR) of
				false -> skip; %%不存在要更新的列名
				true -> %%删除原来表的数据，再重新插入
					emongo:delete(tool:to_list(?MASTER_POOLID), tool:to_list(Table_name)),
					timer:sleep(1000*60),
					F = fun(R) -> 
								F1 = fun({Key,Value}) ->
											 case tool:to_list(Key) == tool:to_list(OldField)  andalso tool:to_list(OldField) =/= tool:to_list(NewField) of
												 false -> {Key,Value};
												 true -> {list_to_binary(tool:to_list(NewField)),Value}
											 end
									 end,
								R1 = [F1({Key,Value}) || {Key,Value} <- R,Key =/= <<"_id">>],
								insert([Table_name,R1])
						end,
					[F(R)|| R <- Result]
			end
	end.


%%删除数据库列名
%%Table_name表名 player
%%OrderByKey一键 "id"
%%OldField原有的列名 "id"
%%NewField新的列名 "id1"
%%sleep根据数据大小调节删除和更新的时间间隔
column_remove(Table_name, OrderByKey, OldField) ->
	[WhereOpertion,FieldOpertion] = db_mongoutil:make_select_opertion(transfer_fields(Table_name,"*"), [{OrderByKey,"<>",null}], [{OrderByKey,asc}],[]),
	Result = emongo:find_all(tool:to_list(?MASTER_POOLID),tool:to_list(Table_name),WhereOpertion,FieldOpertion),
	case Result of 
		[] -> skip; %%表中没有数据
		_ -> 
			%%先取其中一条数据，判断列名是否存在
			RR = lists:nth(1,Result),
			case isExistColumn(OldField,RR) of
				false -> skip; %%不存在要更新的列名
				true -> %%删除原来表的数据，再重新插入
					emongo:delete(tool:to_list(?MASTER_POOLID), tool:to_list(Table_name)),
					timer:sleep(1000*60),
					F = fun(R) -> 
								F1 = fun({Key,Value}) ->
											 case tool:to_list(Key) == tool:to_list(OldField) of
												 true -> {};
												 false -> {Key,Value}
											 end
									 end,
								R1 = [F1({Key,Value}) || {Key,Value} <- R,Key =/= <<"_id">>],
								R2 = lists:filter(fun(T)-> T =/= {} end, R1),
								insert([Table_name,R2])
						end,
					[F(R)|| R <- Result]
			end
	end.

isExistColumn(OldField,R) ->
	lists:keymember(list_to_binary(tool:to_list(OldField)),1,R).
		

%%插入数据,不插入id,不插入默认值
insert([Table_name,Data]) ->
	emongo:insert(tool:to_list(?MASTER_POOLID),tool:to_list(Table_name),Data).
    

%%查找是否存在此id
isExistId(Table_name,Index,Value) ->
	L = select_one(Table_name,tool:to_list(Index),[{Index,Value}]),
	case L of
		null ->
			false;
		_ -> 
			true
	end.

%% 事务处理
transaction(Fun) ->
	Fun().
 
%%启动更新coin_sum字段进程 
coin_sum_process(Table_name, _Fields_sql_List, Where_List) ->
	%%先查出coin,bcion,将(coin+bcion)值赋予coin_sum
	timer:sleep(1000),%%睡眠1秒，便于前面更新数据动作完成
	Fields_sql_string = "id, coin, bcoin",
	Result = select_row(Table_name, Fields_sql_string, Where_List, [], []),
	if  Result == [] ->
			skip;
		true ->
			[Id,Coin,Bcoin] = Result,
			Coin_sum = Coin+Bcoin,
			Fields_sql_List1 = [{coin_sum, Coin_sum}],
			Where_List1 = [{id,Id}],
			update(Table_name, Fields_sql_List1, Where_List1)
	end.

%%对字段求和
sum(Table_name, Fields_sql_string, Where_List) ->
	sum(?MASTER_POOLID,Table_name, Fields_sql_string, Where_List).

sum(PoolId,Table_name, Fields_sql_string, Where_List) ->
	Result = select_all(PoolId,Table_name, Fields_sql_string, Where_List,[],[]),
	case Result of
		[] -> 0; 
		_ ->
			List = lists:flatten(Result),
			lists:sum(List)
	end.
	

%%统计数据表操作次数和频率
stat_db_access(Table_name, Operation) ->
	try
		Key = lists:concat([Table_name, "/", Operation]),
		[NowBeginTime, NowCount] = 
		case ets:match(?ETS_STAT_DB,{Key, Table_name, Operation , '$4', '$5'}) of
			[[OldBeginTime, OldCount]] ->
				[OldBeginTime, OldCount+1];
			_ ->
				[erlang:now(),1]
		end,
%%		io:format("-~p--- -~p   ~p ~n",[util:unixtime(),Key,NowCount]),  
		ets:insert(?ETS_STAT_DB, {Key, Table_name, Operation, NowBeginTime, NowCount}),
		ok
	catch
		_:_ -> no_stat
	end.

%%除重,返回Key集合
%%db_mongo:distinct(player,"nickname")
distinct(Table_name,Key) -> 
	distinct(?MASTER_POOLID,Table_name,Key).

distinct(PoolId,Table_name,Key) ->
	emongo:distinct(tool:to_list(PoolId),tool:to_list(Table_name),tool:to_list(Key)).  


