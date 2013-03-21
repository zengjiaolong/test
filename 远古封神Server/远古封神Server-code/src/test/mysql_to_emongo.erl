%%%--------------------------------------
%%% @Module  : mysql_to_emongo
%%% @Author  : ygzj
%%% @Created : 2010.10.20
%%% @Description: mysql->emongo数据库转换处理模块
%%%--------------------------------------
-module(mysql_to_emongo).
-compile([export_all]). 
-include("common.hrl").

-define(CONFIG_FILE, "../config/gateway.config").

-define(PoolId, mysql_conn_for_mongodb).

-define(AUTO_IDS, "auto_ids").

%% 启动转换程序,只转换基础数据 
start_base()->
	start("base_").

%% 启动转换程序注意，会将所有的表数据删除再转换数据 ,在正式的数据中不要调用此方法
start_all()->
	start(""),
	ok.

%%清档,删除原有的非基础数据和管理员数据
start_clear() ->
	TableList = lib_player_rw:get_all_tables(),
	F = fun(TableName) ->
				TableName1 = util:term_to_string(TableName),
				case TableName1 =/= "cards"  andalso TableName1 =/= "sys_acm"  andalso string:str(TableName1,"admin") =/= 1 
					andalso TableName1 =/= "auto_ids" andalso TableName1 =/= "shop" andalso TableName1 =/= "server" andalso string:str(TableName1,"base") =/= 1 of
					false -> skip;
					true ->
						emongo:delete(tool:to_list(?MASTER_POOLID), TableName1, [])
				end
		end,	
	[F(TableName) || TableName <- TableList],
	ok.

%% 启动转换程序
start(Prefix)->	
	case  get_mysql_config(?CONFIG_FILE) of
		[Host, Port, User, Password, DB_name, Encode] ->	
			mysql:start_link(?PoolId, Host, Port, User, Password, DB_name,  fun(_, _, _, _) -> ok end, Encode),
    		mysql:connect(?PoolId, Host, Port, User, Password, DB_name, Encode, true),
			case get_log_mongo_config(?CONFIG_FILE) of
				[MongoPoolId1, EmongoHost1, EmongoPort1, EmongoDatabase1, EmongoSize1] ->
					init_mongo([MongoPoolId1, EmongoHost1, EmongoPort1, EmongoDatabase1, EmongoSize1]),
					ok;
				_ -> log_emongo_config_fail
			end,
			
			case get_mongo_config(?CONFIG_FILE) of
				[MongoPoolId, EmongoHost, EmongoPort, EmongoDatabase, EmongoSize] ->
					init_mongo([MongoPoolId, EmongoHost, EmongoPort, EmongoDatabase, EmongoSize]),
					io:format("Mysql~p ==>Mongo ~p~n", [[Host, Port, User, Password, DB_name],[EmongoHost, EmongoPort, EmongoDatabase]]),					
    				read_write_tables(DB_name, Prefix),
					ok;
				_ -> emongo_config_fail
			end,
    		ok;
		_ -> mysql_config_fail
	end,
	halt(),
	ok.

get_mysql_config(Config_file)->
	try
		{ok,[L]} = file:consult(Config_file),
		{_, C} = lists:keyfind(gateway, 1, L),
		{_, Mysql_config} = lists:keyfind(mysql_config, 1, C),
		{_, Host} = lists:keyfind(host, 1, Mysql_config),
		{_, Port} = lists:keyfind(port, 1, Mysql_config),
		{_, User} = lists:keyfind(user, 1, Mysql_config),
		{_, Password} = lists:keyfind(password, 1, Mysql_config),
		{_, DB} = lists:keyfind(db, 1, Mysql_config),
		{_, Encode} = lists:keyfind(encode, 1, Mysql_config),
		[Host, Port, User, Password, DB, Encode]		
	catch
		_:_ -> no_config
	end.

get_mongo_config(Config_file)->
	try
		{ok,[L]} = file:consult(Config_file),
		{_, C} = lists:keyfind(gateway, 1, L),
		{_, Emongo_config} = lists:keyfind(emongo_config, 1, C),
		{_, MongoPoolId} = lists:keyfind(poolId, 1, Emongo_config),
		{_, EmongoHost} = lists:keyfind(emongoHost, 1, Emongo_config),
		{_, EmongoPort} = lists:keyfind(emongoPort, 1, Emongo_config),
		{_, EmongoDatabase} = lists:keyfind(emongoDatabase, 1, Emongo_config),
		{_, EmongoSize} = lists:keyfind(emongoSize, 1, Emongo_config),
		[MongoPoolId, EmongoHost, EmongoPort, EmongoDatabase, EmongoSize]		
	catch
		_:_ -> no_config
	end.

get_log_mongo_config(Config_file)->
	try
		{ok,[L]} = file:consult(Config_file),
		{_, C} = lists:keyfind(gateway, 1, L),
		{_, Emongo_config} = lists:keyfind(log_emongo_config, 1, C),
		{_, MongoPoolId} = lists:keyfind(poolId, 1, Emongo_config),
		{_, EmongoHost} = lists:keyfind(emongoHost, 1, Emongo_config),
		{_, EmongoPort} = lists:keyfind(emongoPort, 1, Emongo_config),
		{_, EmongoDatabase} = lists:keyfind(emongoDatabase, 1, Emongo_config),
		{_, EmongoSize} = lists:keyfind(emongoSize, 1, Emongo_config),
		[MongoPoolId, EmongoHost, EmongoPort, EmongoDatabase, EmongoSize]		
	catch
		_:_ -> no_log_mongo_config
	end.

%%初始化emongoDB链接
init_mongo([MongoPoolId, EmongoHost, EmongoPort, EmongoDatabase, EmongoSize]) ->
	emongo_sup:start_link(),
	emongo_app:initialize_pools([MongoPoolId, EmongoHost, EmongoPort, EmongoDatabase, EmongoSize]),
%% 	emongo:insert(tool:to_list(?MASTER_POOLID),"b",[{id, 111},{name,"111ls"},{age,130}]),
%% 	Bin1 = emongo:find_one(tool:to_list(?MASTER_POOLID), "player", [{"id", 1424}]),
	ok.

%%读写操作，将mysql数据转换为emongo文档对象
%% SELECT column_name,data_type, column_key, extra FROM information_schema.columns WHERE table_schema='ygzj_dev' and table_name='adminkind'
read_write_tables(DB_name, Prefix) ->
	IsDir = filelib:is_dir("../logs/"),
	case IsDir of
		false -> file:make_dir("../logs");
		true -> skip
	end,
	FileName = "../logs/db_convert.txt",
	file:delete(FileName),
	timer:sleep(3*1000),
	{ok,IoDevice} = file:open(FileName, write),
	if Prefix =:= "" ->
			emongo:delete(tool:to_list(?MASTER_POOLID), ?AUTO_IDS, []);
		true ->
			no_action
	end,
	Sql = "SELECT table_name  FROM information_schema.tables WHERE table_schema='" ++ DB_name ++ "' and table_type ='BASE TABLE'",
	emongo:ensure_index(tool:to_list(?MASTER_POOLID), "auto_ids", [{<<"id">>,1}]),
	Data = mysql:fetch(?PoolId, list_to_binary(Sql)),
	R = handleResult(Data),%%R is [[<<"adminchange">>],[<<"admingroup">>],[<<"adminkind">>]]
	F = fun(D) ->
				[R1] = D, %%R1 is <<"adminchange">>
				R2 = binary_to_list(R1),
				Index = string:str(binary_to_list(R1), Prefix),
				if Prefix =:= "" orelse Index =:= 1 orelse R1 =:= <<"shop">> orelse R1 =:= <<"adminkind">>  ->
					if R1 =:= <<"adminkind">>  ->
						   %% 转换后，设置“资源管理”为不显示
						   emongo:update(tool:to_list(?MASTER_POOLID), <<"adminkind">>, 
										 [{<<"name">>,<<"资源管理">>}],[{"$set",[{<<"show">>, <<"NO">>}]}]),
						   ok;
						true -> no_action
					end,
					[TableName,IsCorrect] = transfer_tab(DB_name,R2),%%对表进行数据转换
				%%数据表转换如有问题则写日志文件
				if IsCorrect == 1 ->
						   io:format(IoDevice, "~s=>~p	 \t\n", [TableName,IsCorrect]),
						   file:write_file(FileName, IoDevice),
						   1;
					   true ->
						   0
					end	;
				   true -> 
					   0
				end				
		end,
	ResultSum = lists:sum([F(D) || D <- R]),
	if ResultSum == 0 ->
		   io:format(IoDevice, "~s	 \t\n", [ok]),
		   file:write_file(FileName, IoDevice);
	   true ->
		   skip
	end,
	file:close(IoDevice),
	%%更新base数据时同步更新其它非base表的索引
	if  Prefix =:= "base_" ->
			add_other_table_index(?MASTER_POOLID,DB_name,R);
		true ->
			skip
	end,
	ok.

transfer_tab(DB_name,Table_name) ->
	Sql1 = "SELECT column_name,data_type,column_key,extra FROM information_schema.columns WHERE table_schema= '" ++ DB_name ++ "' AND table_name= '"++Table_name++"'",
	Sql2 = "SELECT * FROM " ++ Table_name,
	Result1 = mysql:fetch(?PoolId,list_to_binary(Sql1)),
	Result2 = mysql:fetch(?PoolId,list_to_binary(Sql2)),
	ColumnAndType = handleResult(Result1),%%ColumnAndType is [[<<"id">>,<<"int">>],[<<"name">>,<<"varchar">>],[<<"pid">>,<<"varchar">>],[<<"url">>,<<"varchar">>]],
	TableRecord   = handleResult(Result2),
	records_to_documents(DB_name,Table_name,ColumnAndType,TableRecord).

%%当调用start_base时将其它非base表的索引也同步过来,base表已在前面同步过
%%R is [[<<"adminchange">>],[<<"admingroup">>],[<<"adminkind">>]]
add_other_table_index(POOLID,DB_name,R) ->
	F = fun(D) ->
				[R1] = D, %%R1 is <<"adminchange">>
				binary_to_list(R1)%%R1 is "adminchange"
		end,	
	TableList = [F(D) || D <- R],
	OtherTables = [T || T <- TableList,string:str(T, "base") =/= 1],%%除掉所有base开头的表
	F1 = fun(TableName) ->
				 Sql1 = "SELECT column_name,data_type,column_key,extra FROM information_schema.columns WHERE table_schema= '" ++ DB_name ++ "' AND table_name= '"++TableName++"'",
				 Result1 = mysql:fetch(?PoolId,list_to_binary(Sql1)),
				 ColumnAndType = handleResult(Result1),%%ColumnAndType is [[<<"id">>,<<"int">>],[<<"name">>,<<"varchar">>],[<<"pid">>,<<"varchar">>],[<<"url">>,<<"varchar">>]],
				 
				 %%添加主键索引和唯一索引
				 lists:foreach(fun(FieldAndType) ->
									   [Name, _Type, Key, Extra] = FieldAndType,
									   if Key =:= <<"PRI">>,Extra =:= <<"auto_increment">> ->
											  emongo:ensure_index(tool:to_list(POOLID), TableName, [{Name,1}]),
											  emongo:ensure_index(tool:to_list(?LOG_POOLID), TableName, [{Name,1}]);
										  Key =:= <<"UNI">> orelse Key =:= <<"MUL">> orelse Key =:= <<"PRI">> ->
											  emongo:ensure_index(tool:to_list(POOLID), TableName, [{Name,1}]),
											  emongo:ensure_index(tool:to_list(?LOG_POOLID), TableName, [{Name,1}]);
										  true->
											  ok  
									   end
							   end,
							   ColumnAndType),
				 
				 %%添加处理联合索引
				 IndexSql = "SELECT column_name FROM information_schema.columns WHERE table_schema= '" ++ DB_name ++ "' AND table_name= '"++(TableName)++"' AND column_key ='MUL'",
				 IndexResult = handleResult(mysql:fetch(?PoolId,list_to_binary(IndexSql))),
				 case IndexResult of
					 [] -> skip;
					 _ ->
						 IndexResultSize = length(IndexResult),
						 F3 = fun(II) ->
									  [RR] = lists:nth(II,IndexResult),
									  {binary_to_list(RR),1}
							  end,
						 LL = [F3(II) || II <- lists:seq(1,IndexResultSize)],
						 emongo:ensure_index(tool:to_list(POOLID), TableName, LL),
						 emongo:ensure_index(tool:to_list(?LOG_POOLID), TableName, LL)
				 end	
		 end,	
	[F1(Table) || Table <- OtherTables],
	ok.

%%["a"] -> "a"
term_to_string(Term) ->
    binary_to_list(list_to_binary(io_lib:format("~p", [Term]))).

string_to_term(String) ->
    case erl_scan:string(String++".") of
        {ok, Tokens, _} ->
            case erl_parse:parse_term(Tokens) of
                {ok, Term} -> Term;
                _Err -> undefined
            end;
        _Error ->
            undefined
    end.


%%将mysql记录转换为emongo的document
%%TableName like  "test"
%%ColumnAndType like [[<<"id">>,<<"int">>],
%%                    [<<"row">>,<<"varchar">>],
%%                    [<<"r">>,<<"int">>]]
%%TableRecord like   [[1,111111,<<"111111">>],
%%               	  [2,9898,<<"9898bf">>]]
records_to_documents(DB_name,TableName,ColumnAndType,TableRecord) ->
	case length(TableRecord) of
		0 ->
			H0 = lists:map(fun(FieldAndType) ->
						[Name, _, _, _] = FieldAndType,		  
						{tool:to_atom(Name), 0}
						end,
					ColumnAndType),
			EmptyCollection = true, 
			H = [H0];
		_ -> 
			EmptyCollection = false, 
			F = fun(R) -> 
 				CtList = mergeList(ColumnAndType),
 				ColumnSize = length(CtList),
 				[{lists:nth(I,CtList),lists:nth(I,R)} || I <- lists:seq(1, ColumnSize)]
			end,
			H = [F(Record) || Record <-TableRecord ] %% H like [[{<<"id">>,1},{<<"name">>,<<"zs">>}],[[{<<"id">>,2},{<<"name">>,<<"ls">>}]]
	end,
	%%不删除cards表和sys_acm表及管理员表
	case TableName =/= "cards"  andalso TableName =/= "sys_acm"  andalso string:str(TableName, "admin") =/= 1 of
		false -> 
			IsCorrect = 0,
			skip;
		true -> 
			emongo:delete(tool:to_list(?MASTER_POOLID), TableName, []),
			Mysql_count = length(TableRecord),
			io:format("handle: ~p ...",[TableName]),
			insert_to_emongo(TableName, H),
			case EmptyCollection of
				true -> emongo:delete(tool:to_list(?MASTER_POOLID), TableName, []);
				false -> no_action
			end,
			%%添加主键索引和唯一索引
			lists:foreach(fun(FieldAndType) ->
								  [Name, _Type, Key, Extra] = FieldAndType,
								  if Key =:= <<"PRI">>,Extra =:= <<"auto_increment">> ->
										 emongo:ensure_index(tool:to_list(?MASTER_POOLID), TableName, [{Name,1}]),
										 create_max_id(TableName, Name);
									 Key =:= <<"UNI">> orelse Key =:= <<"MUL">> orelse Key =:= <<"PRI">> ->
										 emongo:ensure_index(tool:to_list(?MASTER_POOLID), TableName, [{Name,1}]);
									 true->
										 ok  
								  end
						  			end,
						  ColumnAndType),
			%%添加处理联合索引
			IndexSql = "SELECT column_name FROM information_schema.columns WHERE table_schema= '" ++ DB_name ++ "' AND table_name= '"++(TableName)++"' AND column_key ='MUL'",
			IndexResult = handleResult(mysql:fetch(?PoolId,list_to_binary(IndexSql))),
			case IndexResult of
				[] -> skip;
				_ ->
					IndexResultSize = length(IndexResult),
					F3 = fun(II) ->
								 [RR] = lists:nth(II,IndexResult),
								 {binary_to_list(RR),1}
						 end,
					LL = [F3(II) || II <- lists:seq(1,IndexResultSize)],
					emongo:ensure_index(tool:to_list(?MASTER_POOLID), TableName, LL)
			end,
			Mongo_count =
				case emongo:count(tool:to_list(?MASTER_POOLID),tool:to_list(TableName),[]) of
					undefined -> 0;
					Val -> Val
				end,
			if Mysql_count =:= Mongo_count ->
				   IsCorrect = 0,
				   io:format(" [~p]==>[~p] finished! ~n",[Mysql_count, Mongo_count]);
			   true ->
				   IsCorrect = 1,
				   io:format(" [~p]==>[~p] ERROR! ~n",[Mysql_count, Mongo_count]),
				   io:format("                                           ERROR ERROR ERROR ERROR! ~n",[])
			end
	end,	
	[TableName,IsCorrect].

%%将mysql:fetch(?DB,Bin)查询结果转换为[[A]]形式,
handleResult(Data) ->
	{_,Bin} = Data,
	{_,_,R,_,_} = Bin,    %%R is [[<<"adminchange">>],[<<"admingroup">>],[<<"adminkind">>]]
	R.

%%将列表转换形式[[<<"id">>,<<"int">>],[[<<"name">>,<<"varchar">>],<<"age">>,<<"int">>]] ->	[<<"id">>,<<"name">>,<<"age">>]
mergeList(List) ->
	F = fun(L1) ->
				[Name,_Type, _Key, _Extra] = L1,
				Name
		end,
	[F(L) || L <- List].
	
%%插入数据	
insert_to_emongo(TableName,H) ->
%% emongo:insert(tool:to_list(?MASTER_POOLID),"test",[{id, 111},{name,"111ls"},{age,130}]),
	F = fun(R) ->
				emongo:insert(tool:to_list(?MASTER_POOLID),TableName,R)
		end,
	[F(R) || R <- H],
	ok.

%% 创建最大自增id
create_max_id(TableName, Name) ->
	try
		Sql = "select max(" ++ tool:to_list(Name) ++ ") from " ++ tool:to_list(TableName),
		Result = mysql:fetch(?PoolId,list_to_binary(Sql)),
		[[MaxId]] = handleResult(Result),
		MaxId_1 = 
		case MaxId of
			null -> 0;
			undefined -> 0;
			_ -> MaxId
		end,
		emongo:delete(tool:to_list(?MASTER_POOLID), ?AUTO_IDS, [{name, TableName}]),
		emongo:insert(tool:to_list(?MASTER_POOLID), ?AUTO_IDS, [{name, TableName}, {Name, MaxId_1}])
	catch 
		_:_ -> error
	end,
	ok.

%%转换指定表的数据
%%TabList is [base_goods,shop]
start_tab(TabList) ->
	DB_name1 = 
	case  get_mysql_config(?CONFIG_FILE) of
		[Host, Port, User, Password, DB_name, Encode] ->	
			mysql:start_link(?PoolId, Host, Port, User, Password, DB_name,  fun(_, _, _, _) -> ok end, Encode),
    		mysql:connect(?PoolId, Host, Port, User, Password, DB_name, Encode, true),
			case get_mongo_config(?CONFIG_FILE) of
				[MongoPoolId, EmongoHost, EmongoPort, EmongoDatabase, EmongoSize] ->
					init_mongo([MongoPoolId, EmongoHost, EmongoPort, EmongoDatabase, EmongoSize]),
					DB_name;
				_ -> 
					[]
			end;
		_ -> 
			[]
	end,
	%%开始转换数据
	case TabList of
		[] -> skip;
		_ ->
			case DB_name1 of
				[] ->
					skip;
				_ ->
					[transfer_tab(DB_name1, util:term_to_string(Table_name))|| Table_name <- TabList]
			end
	end.
