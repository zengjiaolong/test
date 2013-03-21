%% Author: yxh
%% Created: 2010-10-19 
%% Description: TODO: Add description to emongo_tool
-module(db_mongoutil).
-compile(export_all).

-include("common.hrl").
-include("record.hrl").

%%查询数据库池Id
get_slave_mongo_poolId(PoolId) -> 
	 PoolId1 = list_to_atom(tool:to_list(PoolId)),
	 case PoolId1  of
		 slave_mongo -> ?SLAVE_POOLID;
		 log_mongo -> ?LOG_POOLID;
		 _ ->?MASTER_POOLID
	end.
	
%%从查询结果中取出指定的字段值列表
fetchProperieValues(Bin,Properties) ->
	BinSize = length(Bin),
	%%Properties格式为:[<<"id">>, <<"status">>, <<"nickname">>, <<"sex">>, <<"lv">>, <<"career">>]
	PropertiesSize = length(Properties),
	case BinSize of
		0 ->
			[];
		_ ->
			L = 
			case PropertiesSize of         %%返回所有字段属性值
				0 ->
					F = fun(Bin1) -> 
								F1 = fun(D) ->
											 {_,Value} = D,
											  case (is_float(Value) andalso (Value == trunc(Value))) of %%从emongo中取出来的数字型为浮点型,转化为整形
														 true -> trunc(Value);
														 false -> Value
											 end											 
									 end,
								[F1({X,Value}) || {X,Value} <- Bin1, X =/= <<"_id">>] end,%%排除第一个oid元素
					[F(B) || B <- Bin];
					%%Bin;
				_ ->                       %%返回所有指定字段属性值
					F = fun(Bin1) ->
								F1 = fun(D) ->
											 {_,Value} = D,
											 case (is_float(Value) andalso (Value == trunc(Value))) of %%从emongo中取出来的数字型为浮点型,转化为整形
												 true -> trunc(Value);
												 false -> Value
											 end
									 end,
								[F1(lists:keyfind(P1, 1, Bin1)) || P1 <-Properties]  end,
					[F(B) || B <- Bin]
			end,
			case BinSize  of
				1 ->                  %%Bin中只有一条记录,去掉第一个[], 返回形式如:[1424,741,<<"741ea4">>,<<"ww">>]
					[H] = L,
					H;
				_ ->				  %%Bin中有多条记录, 返回形式如:[[1424,741,<<"741ea4">>,<<"ww">>],[1424,741,<<"741ea4">>,<<"ww">>]]
					L
			end				
	end.


%%设置属性值,需要合并属性(emongo在更新字段时也要加上其它字段,不然这些字段会被清空)			 
setProperties(Bin,SetProperties) ->
	SetProperties1 = transferToList(SetProperties),
	F = fun({Key1,Value1}) ->
				{list_to_atom(binary_to_list(Key1)),Value1}
		end,
	L = [F({Key,Value}) || {Key,Value} <- Bin,lists:member(list_to_atom(binary_to_list(Key)),SetProperties1) == false],
	lists:append(L, SetProperties).
	
					
%%将元组列表转换为简单列表[{a,1},{b,2}]  -> [a,b]	
transferToList(State) ->
	F = fun(B) ->
				{Key,_} = B,
				Key
				end,
	[F(B) || B <- State].
	

%%拼接插入语句
make_insert_opertion(FieldValueList) ->
	[{to_dbdata(Key),to_dbdata(Value)} || {Key,Value}<- FieldValueList].

%%拼接插入语句
make_insert_opertion(TableName, FieldValueList) ->
	try
		[{to_dbdata(Key),to_dbdata(Value)} || {Key,Value}<- FieldValueList]
	catch
		_:_ ->
			 ?ERROR_MSG("make_insert_opertion error :~p/~p~n", [tool:to_list(TableName),FieldValueList])
	end.

%%拼接插入语句
%% make_insert_opertion(FieldList, ValueList) ->
%% 	make_conn_opertion(FieldList, ValueList).

%%拼接插入语句FieldList = [id,name,age,dd],ValueList = [1,"zs",10,10.0] -> [[{<<"id">>,1},{<<"name">>,"zs"},{<<"age">>,10},{<<"dd">>,10.0}]]
make_conn_opertion(FieldList, ValueList) ->
%% 	FieldList1 = list2dbDataList(FieldList),
%% 	ValueList1 = list2dbDataList(ValueList),
%% 	Size = length(FieldList),
%% 	[[{lists:nth(I,FieldList1),lists:nth(I,ValueList1)} || I <- lists:seq(1, Size)]].
	make_conn_opertion_loop(FieldList,ValueList,[]).

make_conn_opertion_loop([],_,FV) ->
	FV;
make_conn_opertion_loop(_,[],FV) ->
	FV;
make_conn_opertion_loop([F|FieldList],[V|ValueList],FV) ->
	make_conn_opertion_loop(FieldList,ValueList,[{to_dbdata(F),to_dbdata(V)}|FV]).


%%转化成emongo删除条件语句[{id, PlayerId}, {accname, Accname}] -> [[{<<"id">>,1},{<<"name">>,"zs"}]]
make_delete_opertion(Where_List) ->
	F = fun(E) ->
%% 				{Key,Value} = E,
%% 				{to_dbdata(Key),to_dbdata(Value)}
				case E of
					{Key,Value} ->  %%WhereList is [{id,1},{age,10}]
						{to_dbdata(Key),to_dbdata(Value)};
					{Key,Condition,Value1}  ->    %%WhereList is [{id,1},{age,<>,10}]
						case to_Condition(Condition) of
							ne  ->  {to_dbdata(Key),[{ne,to_dbdata(Value1)}]};
							gt  ->  {to_dbdata(Key),[{gt,to_dbdata(Value1)}]};
							gte ->  {to_dbdata(Key),[{gte,to_dbdata(Value1)}]};
							lt  ->  {to_dbdata(Key),[{lt,to_dbdata(Value1)}]};
							lte ->  {to_dbdata(Key),[{lte,to_dbdata(Value1)}]};
							in  ->  {to_dbdata(Key),[{in,split_list(Value1)}]};
							nin ->  {to_dbdata(Key),[{nin,split_list(Value1)}]}
						end;
					{Key,Condition,Value1,Value2}  ->    %%WhereList is [{id,1},{age,between,10,20},{age,or,10,20}]
						case to_Condition(Condition) of
							possible -> {to_dbdata(Key),[{in,[to_dbdata(Value1),to_dbdata(Value2)]}]};
							between  -> {to_dbdata(Key),[{gte,to_dbdata(Value1)},{lte,to_dbdata(Value2)}]};
							between1 -> {to_dbdata(Key),[{gt,to_dbdata(Value1)},{lte,to_dbdata(Value2)}]};
							between2 -> {to_dbdata(Key),[{gte,to_dbdata(Value1)},{lt,to_dbdata(Value2)}]}	
						end
				end
		end,	
	[[F(E) || E <- Where_List]].
	
%%emongo:count("master_mongo","player",[{<<"id">>,[{"$gt",0}]}]).
make_where_opertion(Where_List) ->
	list_to_key_valueBinaryList(Where_List).

%% 获取数据语句
%% emongo:find_all(test1,"b",[{id,10},{age,30}],[{limit,1},{orderby, [{"id", asc},{"name",desc}]},{fields,[<<"id">>,<<"name">>]}]).
%% between  [{id,10},{age,"between",30,40}]
%% between1 [{id,10},{age,"between1",30,40}]
%% or       [{id,10},{age,"or",30,40}]
%% in       [{id,10},{age,"in",[30,40]}],
%% nin      [{id,10},{age,"nin",[30,40]}]
make_select_opertion(Fields_sql_List, Where_List, Orderby_sql_List, Limit_sql_List) ->
	
	Orderby_sql_List1 = 
	case Orderby_sql_List == [] of
		true -> 
			case Limit_sql_List of 
				[] -> [];
				_ -> 
					Num1 = lists:nth(1,Limit_sql_List),
					case Num1 > 1 of
						false -> [];
						true -> %%%%注意，当Orderby_sql_List为空时limit无效，故要加 上一个排序字段,需要添加排序域
							FirstField = lists:nth(1,Fields_sql_List),
							list_to_orderbyList(list_to_orderBinaryList([{FirstField,asc}]))
					end
			end;		
		_ ->list_to_orderbyList(list_to_orderBinaryList(Orderby_sql_List))
	end,		
	
	Fields_sql_List1 = 
	case Fields_sql_List == [] of
		true -> [];
		_ -> 
			list_to_fieldList(list_to_binaryList(Fields_sql_List))
	end,
	
	%%注意，当Where_List为空, Orderby_sql_List不为空时查不出数据，两者都为空可以查出数据，
	Where_List1 =       
	case Where_List of
		[] -> 
			case Orderby_sql_List of 
				[] ->[];
				_ -> 
					List = lists:nth(1,Orderby_sql_List),
					{Field, _Type} = List,
					[{Field,"<>",null}] %%没有指定where条件，故从排序字段中取一个条件来
			end;
		_  -> Where_List
	end,
	Where_List2 = list_to_key_valueBinaryList(Where_List1),

	%%当Limit_sql_List1中的记录数为1或空时，Orderby_sql_List为空可以查出数据，但Limit_sql_List1中的记录数不为1时，
	%%Orderby_sql_List为空可以查 不出数据，故此时要添加默认的按查询域的第1个字段排序
	Limit_sql_List1 =
	case length(Limit_sql_List) of
		0 -> [];
		1 ->
			[Num] = Limit_sql_List,
			[{limit,Num}];
		2 ->
			Num = lists:nth(1,Limit_sql_List),
			Offset = lists:nth(2,Limit_sql_List),
			[{limit,Num},{offset,Offset}]
	end,
	
	[L] = [Fields_sql_List1++Limit_sql_List1++Orderby_sql_List1],
%% io:format("L__/~p/ ~n",[L]),	   
	[Where_List2,L].

make_select_sequence_opertion(Fields_sql_List, Where_List, Orderby_sql_List, Limit_sql_List) ->
	Orderby_sql_List1 = 
	case Orderby_sql_List == [] of
		true -> 
			case Limit_sql_List of 
				[] -> [];
				_ -> 
					Num1 = lists:nth(1,Limit_sql_List),
					case Num1 > 1 of
						false -> [];
						true -> %%%%注意，当Orderby_sql_List为空时limit无效，故要加 上一个排序字段,需要添加排序域
							FirstField = lists:nth(1,Fields_sql_List),
							list_to_orderbyList(list_to_orderBinaryList([{FirstField,asc}]))
					end
			end;		
		_ ->list_to_orderbyList(list_to_orderBinaryList(Orderby_sql_List))
	end,		
	
	Fields_sql_List1 = 
	case Fields_sql_List == [] of
		true -> [];
		_ -> 
			AddField = filter_sequence(Where_List),
			list_to_fieldList(list_to_binaryList(util:string_to_term("["++util:list_to_string(Fields_sql_List)++","++util:term_to_string(AddField)++"]")))
	end,
	
	%%注意，当Where_List为空, Orderby_sql_List不为空时查不出数据，两者都为空可以查出数据，
	Where_List1 =       
	case Where_List of
		[] -> 
			case Orderby_sql_List of 
				[] ->[];
				_ -> 
					List = lists:nth(1,Orderby_sql_List),
					{Field, _Type} = List,
					[{Field,"<>",null}] %%没有指定where条件，故从排序字段中取一个条件来
			end;
		_  -> Where_List
	end,
	Where_List2 = list_to_key_valueBinaryList(Where_List1),

	%%当Limit_sql_List1中的记录数为1或空时，Orderby_sql_List为空可以查出数据，但Limit_sql_List1中的记录数不为1时，
	%%Orderby_sql_List为空可以查 不出数据，故此时要添加默认的按查询域的第1个字段排序
	Limit_sql_List1 =
	case length(Limit_sql_List) of
		0 -> [];
		1 ->
			[Num] = Limit_sql_List,
			[{limit,Num}];
		2 ->
			Num = lists:nth(1,Limit_sql_List),
			Offset = lists:nth(2,Limit_sql_List),
			[{limit,Num},{offset,Offset}]
	end,
	
	[L] = [Fields_sql_List1++Limit_sql_List1++Orderby_sql_List1],
	[Where_List2,L].

filter_sequence(WhereList) ->
	case WhereList of
		[] -> [];
		_  ->
			F = fun(Elem,ResultList) ->
						case lists:keyfind("in", 2, [Elem]) of
							false -> ResultList;
							{Field,_,_} ->
								ResultList ++ Field
						end
				end,
			lists:foldl(F, [], WhereList)
			
	end.

%%Fields_sql_List is [{last_login_time, Time}, {online_flag, 1}]
%%Where_List is [{id, PlayerId}]
%%emongo:update(test1, "b", [{"id",2}], [{"$inc", [{age,1}]},{"$set",[{name,"yxh"},{age,20}]}]).
make_update_opertion(Fields_sql_List, Where_List) ->
	make_update_opertion(Fields_sql_List, Where_List,[],[]).


make_update_opertion(Fields_sql_List, Where_List, SetList, OtherList) ->
	Where_List1 = list_to_key_valueBinaryList(Where_List),
	Fields_sql_List1 = transfer_to_updateList(Fields_sql_List, SetList, OtherList),
%% 	io:format("\r\nFields_sql_List, SetList, OtherList is ~p,~p,~p",[Fields_sql_List, SetList, OtherList]),
	[Where_List1,Fields_sql_List1].


%%SetList is [{"$set",[{name,"yxh"},{age,20}}]
%%OtherList is [{"$inc",[{money,100},{num,1}}]
%%结果为 [{"$inc",[{money,100},{num,1}]},{"$set",[{name,"yxh"},{age,20}]}]
transfer_to_updateList([H|T], SetList, OtherList) ->
		case H of
			{Key,Value} ->  %%WhereList is [{id,1},{age,10}]
				transfer_to_updateList(T,[{to_dbdata(Key),to_dbdata(Value)}|SetList],OtherList);
			{Key,Value,add} ->%%WhereList is [{id,1,add},{age,10,add}] id=id+1,age=age+10
				transfer_to_updateList(T,SetList,[{to_dbdata(Key),to_dbdata(Value)}|OtherList]);
			{Key,Value,sub} ->%%WhereList is [{id,1,sub},{age,10,sub}] id=id-1,age=age-10
				transfer_to_updateList(T,SetList,[{to_dbdata(Key),-to_dbdata(Value)}|OtherList]);
			{_,_,_} ->
				[]
		end;	
transfer_to_updateList([], SetList, OtherList) ->
	L1 = 
	case length(SetList) of
		0 -> [];
		_ -> list_to_setList(SetList)
	end,
	L2 = 
	case length(OtherList) of
		0 -> [];
		_ -> list_to_incList(OtherList)
	end,
	L1++L2.

%%拼接替换或插入操作
make_replace_opertion(Field_Value_List) ->
	make_update_opertion(Field_Value_List,[]).

%%将fieldList转换为binaryList [id,name,age] -> [<<"id">>,<<"name">>,<<"age">>]
list2dbDataList(List) ->
	F = fun(L) ->
				to_dbdata(L)
		end,
	[F(L) || L <- List].

%%查找最大id
%%emongo:find_one(test1,"b",[{<<"id">>,[{gt,0}]}],[{orderby,[{<<"id">>,desc}]},{limit,1},{fields,[<<"id">>]}]).
find_maxId(PoolID,Table_name) ->
	Data = emongo:find_one(PoolID, Table_name, [{<<"id">>,[{gt,0}]}], [{limit,1},{orderby, [{<<"id">>, desc}]}, {fields, [<<"id">>]}]),
	case Data of
		[] ->
			1;
		_ ->
			[D1] = Data,
			trunc(proplists:get_value(<<"id">>,D1))+1
	end.

%%将list转换为二进制list   [id,name,age] -> [<<"id">>,<<"name">>,<<"age">>]
list_to_binaryList(List) ->
	F = fun(E) ->
				to_dbdata(E)
		end,
	[F(E) || E <- List].


%%将list转换为二进制list   [{id,1},{name,"zs"},{age,10}] -> [{<<"id">>,1},{<<"name">>,"zs"},{<<"age">>,10}]
list_to_key_valueBinaryList(List) ->
	case List of
		[] -> [];
		_  -> 
			F = fun(E) ->
						case E of
							{Key,Value} ->  %%WhereList is [{id,1},{age,10}]
								{to_dbdata(Key),to_dbdata(Value)};
							{Key,Condition,Value1}  ->    %%WhereList is [{id,1},{age,<>,10}]
								case to_Condition(Condition) of
									ne  ->  {to_dbdata(Key),[{"$ne",to_dbdata(Value1)}]};
									gt  ->  {to_dbdata(Key),[{"$gt",to_dbdata(Value1)}]};
									gte ->  {to_dbdata(Key),[{"$gte",to_dbdata(Value1)}]};
									lt  ->  {to_dbdata(Key),[{"$lt",to_dbdata(Value1)}]};
									lte ->  {to_dbdata(Key),[{"$lte",to_dbdata(Value1)}]};
									in  ->  {to_dbdata(Key),[{in,split_list(Value1)}]};
									nin ->  {to_dbdata(Key),[{nin,split_list(Value1)}]}
								end;
							{Key,Condition,Value1,Value2}  ->    %%WhereList is [{id,1},{age,between,10,20},{age,or,10,20}]
								case to_Condition(Condition) of
									possible -> {to_dbdata(Key),[{in,[to_dbdata(Value1),to_dbdata(Value2)]}]};
									between  -> {to_dbdata(Key),[{"$gte",to_dbdata(Value1)},{lte,to_dbdata(Value2)}]};
									between1 -> {to_dbdata(Key),[{"$gt",to_dbdata(Value1)},{lte,to_dbdata(Value2)}]};
									between2 -> {to_dbdata(Key),[{"$gte",to_dbdata(Value1)},{lt,to_dbdata(Value2)}]}
								end
						end
				end,
			[F(E) || E <- List]
	end.

%%将list转换为二进制list   [{id,asc},{name,desc}] -> [{<<"id">>,asc},{<<"name">>,desc}]
list_to_orderBinaryList(List) ->
	case List of
		[] -> [];
		_  -> 
			F = fun(E) ->
						{Key,Value} = E,
						{to_dbdata(Key),Value}
				end,
			[F(E) || E <- List]
	end.

%%将list转换为带fields list   [<<"id">>,<<"name">>]- > [{fields,[<<"id">>,<<"name">>]}]
list_to_fieldList(List) ->
	[{fields,List}].

%%将list转换为带fields list   [<<"id">>,<<"name">>]- >  [{"$set", [{id,10},{name, "yxh1"}]}]
list_to_setList(List) ->
	[{"$set",List}].

%%将list转换为带fields list   [<<"id">>,<<"name">>]- >  [{"$set", [{id,10},{name, "yxh1"}]}]
list_to_incList(List) ->
	[{"$inc",List}].

%将list转换为带fields list   [<<"id">>,asc]- >  [{"$set", [{id,10},{name, "yxh1"}]}]
list_to_orderbyList(List) ->
	[{orderby,List}].

to_Condition(X) when X == "<>"  -> ne;
to_Condition(X) when X == ">"   -> gt;
to_Condition(X) when X == ">="  -> gte;
to_Condition(X) when X == "<"   -> lt;
to_Condition(X) when X == "<="  -> lte;
to_Condition(X) when X == "in"  -> in;
to_Condition(X) when X == "nin" -> nin;
to_Condition(X) when X == "or"  -> possible;
to_Condition(X) when X == "between"  -> between; %%大于等于  小于等于
to_Condition(X) when X == "between1"  -> between1;%%大于  小于等于
to_Condition(X) when X == "between2"  -> between2.%%大于等于  小于

to_dbdata(X) when is_binary(X)  -> X;
to_dbdata(X) when is_integer(X) -> X;
to_dbdata(X) when is_float(X)   -> X;
to_dbdata(X) when is_list(X)    -> list_to_binary(X);
to_dbdata(X) when is_atom(X)    -> list_to_binary(atom_to_list(X)).

	
split_list(ValueList) ->
	case ValueList == [] of
		true -> [];
		_ ->
			[to_dbdata(Value) || Value <- ValueList]			
	end.


		
					
	
	
				
				
			
			
		


