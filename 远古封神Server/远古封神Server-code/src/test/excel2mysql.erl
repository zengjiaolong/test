-module(excel2mysql).

%%
%% Include files
%%
-include("common.hrl").
-compile(export_all).

-define(CONFIG_FILE, "../config/gateway.config").

-define(TMP_TABLE_PATH, "./tmptable/").
-define(SRC_TABLE_PATH, "../src/table/").
-define(RECORD_FILENAME, "../include/table_to_record.hrl").
-define(BEAM_PATH, "./"). 

-define(EXCEL_PATH, "../temp/excel2mysql/").

%%
%% API Functions
%%
start()->	
	case  get_db_config(?CONFIG_FILE) of
		[Host, Port, User, Password, DB, Encode] ->
			start_erlydb(Host, Port, User, Password, DB),
    		mysql:start_link(?DB_POOL, Host, Port, User, Password, DB, fun(_, _, _, _) -> ok end, Encode),
    		mysql:connect(?DB_POOL, Host, Port, User, Password, DB, Encode, true),
			excel_to_mysql_base_goods_practise();
		_ -> mysql_config_fail
	end,
	ok.

get_db_config(Config_file)->
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

%%
%% Local Functions
%%
start_erlydb(IP, Port, User, Password, Db) ->
	erlydb:start(mysql, [{pool_id, erlydb_mysql},
						{hostname, IP},
						 {port, Port},
						 {username, User}, 
						 {password, Password}, 
						 {database, Db},
						 {encoding, utf8},
						 {pool_size, 10}]).


excel_to_mysql_base_goods_practise() ->
	Practise_path = lists:concat([?EXCEL_PATH,'base_goods_practise']),
	case file:list_dir(Practise_path) of
		{ok, Filenames} ->
			lists:foreach(fun(F)->
					case string:rstr(F,".txt") > 0 of
						true ->
							base_goods_practise_0(Practise_path ++ "/" ++ F),
							ok;
						_-> no_action
					end,
					ok
					end , 
				lists:sort(Filenames));
		{error, _} -> ignore
	end,
	ok.

base_goods_practise_0(Filename) ->
	io:format("__1__~p~n",[Filename]),
	{ok,IoDevice} = file:open(Filename, [read]),
	try
%% 神弓(09)_绿色(1)_
%% 攻击力			单属性	
%% 最大	最小	命中	敏捷	体质
%% 9/1
%% max_attack/min_attack/hit/agile/physique
		
		{ok, _Line1} = file:read_line(IoDevice),
		{ok, _Line2} = file:read_line(IoDevice),
		{ok, _Line3} = file:read_line(IoDevice),
		{ok, Line4} = file:read_line(IoDevice),
		{ok, Line5} = file:read_line(IoDevice),
		[Line4_0] = string:tokens(Line4,"\n"),
		[Line5_0] = string:tokens(Line5,"\n"),		
%% 		io:format("     ~p~n     ~p~n", [Line4_0, Line5_0]),
		[Subtype, Color] = string:tokens(Line4_0,"/"),
		Attrs = string:tokens(Line5_0,"/"),
		base_goods_practise_1(IoDevice, 
							  tool:to_integer(Subtype),
							  tool:to_integer(Color),
							  Attrs
							  ),					  		
		file:close(IoDevice),
		ok
	catch
		_:_ -> file:close(IoDevice)
	end,
	ok.

base_goods_practise_1(IoDevice, Subtype, Color, Attrs) ->
%% 	io:format("     ~p~n", [[Subtype, Color, Attrs, Att_num]]),		
 	case file:read_line(IoDevice) of
 		{ok,Line}->
			[Line_0] = string:tokens(Line,"\n"),
			Vals0 = string:tokens(Line_0,","),
			[Grade0 | Vals] = Vals0,
			Grade = tool:to_integer(Grade0),
%% 			io:format("                   ~p~n", [Grade]),
			base_goods_practise_2(Subtype, Color, Attrs, Grade, Vals, 10),
			base_goods_practise_1(IoDevice, Subtype, Color, Attrs);
		eof-> 
			{ok, finshed};
		{error, Reason}->
			{error, Reason}
	end.

base_goods_practise_2(_Subtype, _Color, _Attrs, _Grade, [], _Step) ->
	ok;
base_goods_practise_2(Subtype, Color, Attrs, Grade, Vals, Step) ->
%% 	io:format("                   ~p/~p/~p~n", [Grade, Step, length(Vals)]),	
	case length(Attrs) of
		5 -> Att_num = 1,
			{L1, L2} = lists:split(length(Vals)-5, Vals),
%% 神弓(09)_绿色(1)_
%% 攻击力			单属性	
%% 最大	最小	命中	敏捷	体质
%% 9/1
%% max_attack/min_attack/hit/agile/physique	
io:format("Here_1_~n",[]),			 
			[Field1, Field2, Field3, Field4, Field5] = Attrs,
io:format("Here_2_~n",[]),			 
			[Val1, Val2, Val3, Val4, Val5] = L2,
io:format("Here_3_~n",[]),			 
			Field_Value_List = [{att_num, Att_num}, {subtype, Subtype}, {step, Step}, {color, Color}, {grade,Grade}]
								++ [{tool:to_atom(Field1), tool:to_integer(Val1)}]
								++ [{tool:to_atom(Field2), tool:to_integer(Val2)}]
								++ [{tool:to_atom(Field3), tool:to_integer(Val3)}]
								++ [{tool:to_atom(Field4), tool:to_integer(Val4)}]
								++ [{tool:to_atom(Field5), tool:to_integer(Val5)}],	
io:format("Here_4_/~p/~n",[Field_Value_List]),			 
			Sql = make_replace_sql(base_goods_practise, Field_Value_List),
%% 	io:format("                   ~p/~p/~p/~p~n", [Grade, Step, length(Vals), Sql]),
			db_sql:execute(Sql),
			base_goods_practise_2(Subtype, Color, Attrs, Grade, L1, Step-1),
			ok;
		7 -> _Att_num = 2,
			{L1, _L2} = lists:split(length(Vals)-7, Vals),
			base_goods_practise_2(Subtype, Color, Attrs, Grade, L1, Step-1),
			ok
	end,	
	ok.


make_replace_sql(Table_name, Field_Value_List) ->
 	{Vsql, _Count1} =
		lists:mapfoldl(
	  		fun(Field_value, Sum) ->	
				Expr = case Field_value of
						 {Field, Val} -> 
							 case is_binary(Val) orelse is_list(Val) of 
								 true -> io_lib:format("`~s`='~s'",[Field, re:replace(Val,"'","''",[global,{return,binary}])]);
							 	 _-> io_lib:format("`~s`='~p'",[Field, Val])
							 end
					end,
				S1 = if Sum == length(Field_Value_List) -> io_lib:format("~s ",[Expr]);
						true -> io_lib:format("~s,",[Expr])
					 end,
 				{S1, Sum+1}
			end,
			1, Field_Value_List),
	lists:concat(["replace into `", Table_name, "` set ",
	 			  lists:flatten(Vsql)
				 ]).