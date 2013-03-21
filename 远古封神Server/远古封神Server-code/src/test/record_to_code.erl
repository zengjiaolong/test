%%%--------------------------------------
%%% @Module  : yg_gateway
%%% @Author  : ygzj
%%% @Created : 2010.10.27 
%%% @Description: 将record 转换成 erl code
%%%			暂时先处理 player, 以便方便的按所需字段读写player字段值。
%%%			生成文件： "../src/lib/lib_player_rw.erl"
%%%--------------------------------------

-module(record_to_code).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").

%%
%% Exported Functions
%%
-compile(export_all). 

-define(CONFIG_FILE, "../config/gateway.config").

%%
%% API Functions
%%
start()->	
	convert_player(),
	case  get_db_config(?CONFIG_FILE) of
		[Host, Port, User, Password, DB, Encode] ->
			start_erlydb(Host, Port, User, Password, DB),
    		mysql:start_link(?DB_POOL, Host, Port, User, Password, DB, fun(_, _, _, _) -> ok end, Encode),
    		mysql:connect(?DB_POOL, Host, Port, User, Password, DB, Encode, true),
			table_fields_all(DB),
			get_all_tables(DB),
			ok;
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

convert_player() ->
	io:format("~n~n~n~n~n~nBegin create ../src/lib/lib_player_rw.erl!~n~n"),
	
	P_list = record_info(fields, player),
	O_list = record_info(fields, player_other),
%% io:format("P_list: ~p ~n",[P_list]),
%% io:format("O_list: ~p ~n",[O_list]),
	File = "../src/lib/lib_player_rw.erl",
	
	file:write_file(File, ""),
	
	file:write_file(File, ""),
	file:write_file(File, "%%%------------------------------------------------\t\n",[append]),
	file:write_file(File, "%%% File    : lib_player_rw.erl\t\n",[append]),
	file:write_file(File, "%%% Author  : ygzj\t\n",[append]),
	Bytes0 = list_to_binary(io_lib:format("%%% Created : ~s\t\n", [time_format(now())])),
	file:write_file(File, Bytes0,[append]),
	file:write_file(File, "%%% Description: 从record生成的代码\t\n",[append]),
	file:write_file(File, "%%% Warning:  由程序自动生成，请不要随意修改！\t\n",[append]),	
	file:write_file(File, "%%%------------------------------------------------	\t\n",[append]),
	file:write_file(File, " \t\n",[append]),	
	file:write_file(File, "-module(lib_player_rw).\t\n",[append]),
	file:write_file(File, " \t\n",[append]),
	file:write_file(File, "%%  \t\n",[append]),
	file:write_file(File, "%% Include files  \t\n",[append]),
	file:write_file(File, "-include(\"common.hrl\"). \t\n",[append]),
	file:write_file(File, "-include(\"record.hrl\"). \t\n",[append]),
	file:write_file(File, "  \t\n",[append]),
	file:write_file(File, "%% \t\n",[append]),
	file:write_file(File, "%% Exported Functions \t\n",[append]),
	file:write_file(File, "%% \t\n",[append]),
	file:write_file(File, "-compile(export_all). \t\n",[append]),
	file:write_file(File, "  \t\n",[append]),	

	file:write_file(File, "%%获取用户信息(按[字段1,字段2,...])\t\n",[append]),
	file:write_file(File, "%% handle_call({'PLAYER',  [x ,y]}, _from, Status)\t\n",[append]),
	file:write_file(File, "get_player_info_fields(Player, List) ->\t\n",[append]),
	file:write_file(File, "	lists:map(fun(T) ->\t\n",[append]), 
	file:write_file(File, "			case T of\t\n",[append]),
	lists:foreach(fun(Field_name) ->
					Bytes00 = lists:concat(["				",Field_name," -> Player#player.",Field_name,";\t\n"]),
					file:write_file(File, Bytes00,[append])			  
				  end, 
				  P_list),
	lists:foreach(fun(Field_name) ->
					Bytes00 = lists:concat(["				",Field_name," -> Player#player.other#player_other.",Field_name,";\t\n"]),
					file:write_file(File, Bytes00,[append])			  
				  end, 
				  O_list),	
	file:write_file(File, "				_ -> undefined\t\n",[append]),
	file:write_file(File, "			end\t\n",[append]),						
	file:write_file(File, "		end, List).\t\n",[append]),
	file:write_file(File, " \t\n",[append]),
	
	file:write_file(File, "%%设置用户信息(按[{字段1,值1},{字段2,值2, add},{字段3,值3, sub}...])\t\n",[append]),
	file:write_file(File, "%% handle_cast({'SET_PLAYER',[{x, 10} ,{y, 20, add},  ,{hp, 20, sub}]}, Status)\t\n",[append]),
	file:write_file(File, "set_player_info_fields(Player, []) ->\t\n",[append]),
	file:write_file(File, "	Player;\t\n",[append]),
	file:write_file(File, "set_player_info_fields(Player, [H|T]) ->\t\n",[append]),
	file:write_file(File, "	NewPlayer =\t\n",[append]),
	file:write_file(File, "		case H of\t\n",[append]),
	lists:foreach(fun(Field_name) ->
					if Field_name =/= other ->
						Bytes1 = lists:concat(["				{",Field_name,", Val, add} -> Player#player{",Field_name,"=Player#player.",Field_name," + Val};\t\n"]),
						file:write_file(File, Bytes1,[append]),
						Bytes2 = lists:concat(["				{",Field_name,", Val, sub} -> Player#player{",Field_name,"=Player#player.",Field_name," - Val};\t\n"]),
						file:write_file(File, Bytes2,[append]),
						Bytes3 = lists:concat(["				{",Field_name,", Val, _} -> Player#player{",Field_name,"= Val};\t\n"]),
						file:write_file(File, Bytes3,[append]),
						Bytes4 = lists:concat(["				{",Field_name,", Val} -> Player#player{",Field_name,"= Val};\t\n"]),
						file:write_file(File, Bytes4,[append]);
					   true -> no_action
					end
				  end, 
				  P_list),
	lists:foreach(fun(Field_name) ->
					Bytes1 = lists:concat(["				{",Field_name,
										   ", Val, add} -> Player#player{other=Player#player.other#player_other{",Field_name,
										   " = Player#player.other#player_other.",Field_name," + Val}};\t\n"]),
					file:write_file(File, Bytes1,[append]),
					Bytes2 = lists:concat(["				{",Field_name,
										   ", Val, sub} -> Player#player{other=Player#player.other#player_other{",Field_name,
										   " = Player#player.other#player_other.",Field_name," - Val}};\t\n"]),
					file:write_file(File, Bytes2,[append]),
					Bytes3 = lists:concat(["				{",Field_name,
										   ", Val, _} -> Player#player{other=Player#player.other#player_other{",Field_name,
										   " =  Val}};\t\n"]),
					file:write_file(File, Bytes3,[append]),
					Bytes4 = lists:concat(["				{",Field_name,
										   ", Val} -> Player#player{other=Player#player.other#player_other{",Field_name,
										   " =  Val}};\t\n"]),
					file:write_file(File, Bytes4,[append])  
				  end, 
				  O_list),	

	file:write_file(File, "			_ -> Player\t\n",[append]),
	file:write_file(File, "		end,\t\n",[append]),	
	file:write_file(File, "	set_player_info_fields(NewPlayer, T).\t\n",[append]),
	io:format("Create ../src/lib/lib_player_rw.erl  finished!~n~n"),
	ok.


%%  根据表名获取其完全字段
table_fields_all(DB_name)->
	Filename = "../src/lib/lib_player_rw.erl",
	Sql = lists:concat(["SELECT table_name FROM information_schema.tables WHERE table_schema='", tool:to_list(DB_name), "' and table_type ='BASE TABLE'"]),
	try 
		case  db_sql:get_all(list_to_binary(Sql)) of 
			[] -> error1;
			A ->
				file:write_file(Filename, 
					list_to_binary(io_lib:format("\t\n\t\n%% 根据表名获取其完全字段\t\n",[])), 
					[append]),
				
				file:write_file(Filename, 
					list_to_binary(io_lib:format("get_table_fields(Table_name) ->\t\n",[])), 
					[append]),
				
				file:write_file(Filename, 
					list_to_binary(io_lib:format("	Table_fileds = [ \t\n",[])), 
					[append]),
				
				L = lists:flatten(A),
				F = fun(T) ->
%% io:format("~p~n",[T]),								
						Sql1 = lists:concat(["SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_schema= '", tool:to_list(DB_name), "' AND table_name= '", tool:to_list(T),  "'"]),
						case  db_sql:get_all(list_to_binary(Sql1)) of
							[] -> error2;
							B -> 
%% 								D = lists:flatten(B),
								{DL,_} =
								lists:mapfoldl(fun([Field, Data_type0, Default0], Sum) -> 
											Data_type =  tool:to_atom(Data_type0),
											Default = 
												case Default0 of
													undefined -> 
														case erlydb_field:get_erl_type(Data_type) of
															binary -> 
																"";
															integer -> 
																0;
															_ -> 0 
														end;													
													<<>> -> 
														case erlydb_field:get_erl_type(Data_type) of
															binary -> 
																"";
															integer -> 
																0;
															_ -> "" 
														end;
													<<"[]">> ->
															[];
													Val -> 
														case erlydb_field:get_erl_type(Data_type) of
															binary -> 
																lists:concat(["", binary_to_list(Val) ,""]);
															integer -> 
																tool:to_integer(binary_to_list(Val));	
															decimal ->
																tool:to_float(binary_to_list(Val));
															_ -> 
																lists:concat([binary_to_list(Val)])
														end																				
												end,	
%% TT = tool:to_atom(T),											
%% if TT == player ->
%% 	io:format("1___/~p/~p/~p/~p/~p/~p/ ~n", [tool:to_list(T), tool:to_atom(Field), Data_type, erlydb_field:get_erl_type(Data_type), Default0, Default]);
%%    true ->
%% 	   ok
%% end,											
												S = if Sum == length(B) -> 
														io_lib:format("{~s, ~p}",[tool:to_atom(Field), Default]);
													true -> 
														io_lib:format("{~s, ~p},",[tool:to_atom(Field), Default])
										 		end,				
												{S, Sum+1}
											end, 
										 1,B),
								E = io_lib:format('{~s,[~s]}', [tool:to_atom(T), lists:flatten(DL)]),
								file:write_file(Filename, 
										list_to_binary(io_lib:format("		~s,\t\n",[E])), 
										[append]),								
								ok
						end
					end,
				[F(T) || T <- L],
				file:write_file(Filename, 
					list_to_binary(io_lib:format('		{null,""}], \t\n',[])), 
					[append]),	
				
				file:write_file(Filename, 
					list_to_binary(io_lib:format('	case lists:keysearch(Table_name,1, Table_fileds) of \t\n',[])), 
					[append]),	
				file:write_file(Filename, 
					list_to_binary(io_lib:format('		{value,{_, Val}} -> Val; \t\n',[])), 
					[append]),	
				file:write_file(Filename, 
					list_to_binary(io_lib:format('		_ -> undefined \t\n',[])), 
					[append]),	
				file:write_file(Filename, 
					list_to_binary(io_lib:format('	end. \t\n',[])), 
					[append]),	
				ok
		end
	catch
		_:_ -> fail
	end.

%%生成所有的表
get_all_tables(DB_name) ->
	Filename = "../src/lib/lib_player_rw.erl",
	Sql = lists:concat(["SELECT table_name FROM information_schema.tables WHERE table_schema='", tool:to_list(DB_name), "' and table_type ='BASE TABLE'"]),
	try 
		case  db_sql:get_all(list_to_binary(Sql)) of 
			[] -> error1;
			A ->
				file:write_file(Filename, 
					list_to_binary(io_lib:format("\t\n\t\n%% 获取所有表名\t\n",[])), 
					[append]),
				
				file:write_file(Filename, 
					list_to_binary(io_lib:format("get_all_tables() ->\t\n",[])), 
					[append]),
				
				file:write_file(Filename, 
					list_to_binary(io_lib:format("	[ \t\n",[])), 
					[append]),
				
				L = lists:flatten(A),
				F = fun(T) ->
							file:write_file(Filename, 
										list_to_binary(io_lib:format("		~s,\t\n",[tool:to_atom(T)])), 
										[append])
					end,
				[F(T) || T <- L],
				file:write_file(Filename, 
					list_to_binary(io_lib:format('		null \t\n',[])), 
					[append]),				
				file:write_file(Filename,
					list_to_binary(io_lib:format("	]. \t\n",[])), 
				    [append]),
				ok
		end
	catch
		_:_ -> fail
	end.
			
%%  根据表名获取其完全字段(前一版本)
table_fields_all_bak(DB_name)->
	Filename = "../src/lib/lib_player_rw.erl",
	Sql = lists:concat(["SELECT table_name FROM information_schema.tables WHERE table_schema='", tool:to_list(DB_name), "' and table_type ='BASE TABLE'"]),
	try 
		case  db_sql:get_all(list_to_binary(Sql)) of 
			[] -> error1;
			A ->
				file:write_file(Filename, 
					list_to_binary(io_lib:format("\t\n\t\n%% 根据表名获取其完全字段\t\n",[])), 
					[append]),
				
				file:write_file(Filename, 
					list_to_binary(io_lib:format("get_table_fields(Table_name) ->\t\n",[])), 
					[append]),
				
				file:write_file(Filename, 
					list_to_binary(io_lib:format("	Table_fileds = [ \t\n",[])), 
					[append]),
				
				L = lists:flatten(A),
				F = fun(T) ->
%% io:format("~p~n",[T]),								
						Sql1 = lists:concat(["SELECT column_name FROM information_schema.columns WHERE table_schema= '", tool:to_list(DB_name), "' AND table_name= '", tool:to_list(T),  "'"]),
						case  db_sql:get_all(list_to_binary(Sql1)) of
							[] -> error2;
							B -> 
								D = lists:flatten(B),
								{DL,_} =
								lists:mapfoldl(fun(F, Sum) -> 
												S = if Sum == length(D) -> 
														   io_lib:format("~s",[tool:to_atom(F)]);
													true -> 
															io_lib:format("~s,",[tool:to_atom(F)])
										 		end,				
												{S, Sum+1}
											end, 
										 1,D),
								E = io_lib:format('{~s,"~s"}', [tool:to_atom(T), lists:flatten(DL)]),
								file:write_file(Filename, 
										list_to_binary(io_lib:format("		~s,\t\n",[E])), 
										[append]),								
								ok
						end
					end,
				[F(T) || T <- L],
				file:write_file(Filename, 
					list_to_binary(io_lib:format('		{null,""}], \t\n',[])), 
					[append]),	
				
				file:write_file(Filename, 
					list_to_binary(io_lib:format('	case lists:keysearch(Table_name,1, Table_fileds) of \t\n',[])), 
					[append]),	
				file:write_file(Filename, 
					list_to_binary(io_lib:format('		{value,{_, Val}} -> Val; \t\n',[])), 
					[append]),	
				file:write_file(Filename, 
					list_to_binary(io_lib:format('		_ -> undefined \t\n',[])), 
					[append]),	
				file:write_file(Filename, 
					list_to_binary(io_lib:format('	end. \t\n',[])), 
					[append]),	
				ok
		end
	catch
		_:_ -> fail
	end.


%% --------------------------------------------------
%% time format
one_to_two(One) -> io_lib:format("~2..0B", [One]).

%% @doc get the time's seconds for integer type
%% @spec get_seconds(Time) -> integer() 
get_seconds(Time)->
	{_MegaSecs, Secs, _MicroSecs} = Time, 
	Secs.
	
time_format(Now) -> 
	{{Y,M,D},{H,MM,S}} = calendar:now_to_local_time(Now),
	lists:concat([Y, "-", one_to_two(M), "-", one_to_two(D), " ", 
						one_to_two(H) , ":", one_to_two(MM), ":", one_to_two(S)]).
date_format(Now) ->
	{{Y,M,D},{_H,_MM,_S}} = calendar:now_to_local_time(Now),
	lists:concat([Y, "-", one_to_two(M), "-", one_to_two(D)]).
date_hour_format(Now) ->
	{{Y,M,D},{H,_MM,_S}} = calendar:now_to_local_time(Now),
	lists:concat([Y, "-", one_to_two(M), "-", one_to_two(D), " ", one_to_two(H)]).
date_hour_minute_format(Now) ->
	{{Y,M,D},{H,MM,_S}} = calendar:now_to_local_time(Now),
	lists:concat([Y, "-", one_to_two(M), "-", one_to_two(D), " ", one_to_two(H) , "-", one_to_two(MM)]).
%% split by -
minute_second_format(Now) ->
	{{_Y,_M,_D},{H,MM,_S}} = calendar:now_to_local_time(Now),
	lists:concat([one_to_two(H) , "-", one_to_two(MM)]).

hour_minute_second_format(Now) ->
	{{_Y,_M,_D},{H,MM,S}} = calendar:now_to_local_time(Now),
	lists:concat([one_to_two(H) , ":", one_to_two(MM), ":", one_to_two(S)]).	