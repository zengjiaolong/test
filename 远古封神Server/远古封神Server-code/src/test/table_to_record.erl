%%%--------------------------------------
%%% @Module  : yg_gateway
%%% @Author  : ygzj
%%% @Created : 2010.10.27 
%%% @Description: 将mysql数据表 转换成 erl record
%%%			生成文件： "../include/table_to_record.hrl"
%%%--------------------------------------
-module(table_to_record).

%%
%% Include files
%%
-include("common.hrl").

-define(CONFIG_FILE, "../config/gateway.config").

-define(TMP_TABLE_PATH, "./tmptable/").
-define(SRC_TABLE_PATH, "../src/table/").
-define(RECORD_FILENAME, "../include/table_to_record.hrl").
-define(BEAM_PATH, "./"). 

-define(TABLES,
	[
		{server, server},
		{player, player},
		{goods, goods},
		{goods_attribute, goods_attribute},
		{goods_buff,goods_buff},
		{goods_cd,ets_goods_cd},
		{deputy_equip,ets_deputy_equip},
		{base_answer, ets_base_answer},
		{base_career, ets_base_career},
		{base_culture_state, ets_base_culture_state},
		{base_scene, ets_scene},
		{base_mon, ets_mon},
		{base_npc, ets_npc},
		{base_goods, ets_base_goods},
		{base_goods_add_attribute, ets_base_goods_add_attribute},
		{base_goods_suit_attribute, ets_base_goods_suit_attribute},
		{base_goods_suit,ets_base_goods_suit},
		{base_goods_strengthen, ets_base_goods_strengthen},
		{base_goods_strengthen_anti, ets_base_goods_strengthen_anti},
		{base_goods_strengthen_extra, ets_base_goods_strengthen_extra},
		{base_goods_practise, ets_base_goods_practise},		 
		{base_goods_compose, ets_base_goods_compose},
		{base_goods_inlay, ets_base_goods_inlay},
		{base_goods_idecompose,ets_base_goods_idecompose},
		{base_goods_icompose,ets_base_goods_icompose},
		{base_goods_drop_num, ets_base_goods_drop_num},
		{base_goods_drop_rule, ets_base_goods_drop_rule},
		{base_goods_ore,ets_base_goods_ore},
		{shop, ets_shop},
		{base_talk, talk},
		{base_task, task},
		{task_bag, role_task},
		{task_log, role_task_log},
		{base_skill, ets_skill, "人物技能数据"},
		{base_skill_pet, ets_pet_skill, "宠物技能数据"},
		{guild, ets_guild},
		{view_guild_member, ets_guild_member, "氏族成员"},
		{view_guild_apply, ets_guild_apply,   "氏族申请"},
		{guild_member, ets_insert_guild_member,"氏族成员，警告：此ets只能用于insert成员数据时用"},
		{guild_apply, ets_insert_guild_apply, "氏族失去你请记录，警告：此ets只能用于insert成员数据时用"},
		{guild_invite, ets_guild_invite},
		{guild_skills_attribute, ets_guild_skills_attribute},
		{log_guild, ets_log_guild},	
		{log_warehouse_flowdir, ets_log_warehouse_flowdir},	 
		{base_pet, ets_base_pet},
		{pet, ets_pet},
		{base_dungeon, dungeon},
		{log_dungeon, ets_dungeon},
		{master_apprentice, ets_master_apprentice},
		{master_charts, ets_master_charts},
		{meridian,ets_meridian},
		{base_meridian,ets_base_meridian},
		{log_sale_dir, ets_log_sale_dir},
		{online_gift,ets_online_gift},
		{base_online_gift,ets_base_online_gift},
		{base_carry,ets_carry_time},
		{base_map,ets_base_map},
		{base_box_goods, ets_base_box_goods},
		{log_box_open, ets_log_box_open},
		{log_box_player, ets_log_box_player},
		{box_scene, ets_box_scene},
		{feedback, feedback},
		{base_target_gift,ets_base_target_gift},
		{target_gift,ets_target_gift},
		{task_consign,ets_task_consign},
		{player_sys_setting, player_sys_setting, "玩家游戏系统设置"},
		{arena, ets_arena, "战场总排行表"},
		{arena_week, ets_arena_week, "战场周排行表"},
		{consign_task,ets_consign_task},
		{consign_player,ets_consign_player},
		{carry,ets_carry},
		{offline_award,ets_offline_award},
		{online_award,ets_online_award},
		{business,ets_business},
		{log_business_robbed,ets_log_robbed},
		{base_business,ets_base_business},
		{online_award_holiday,ets_online_award_holiday},
		{hero_card,ets_hero_card},
		{base_hero_card,ets_base_hero_card},
		{love,ets_love},
		{base_privity,ets_base_privity},
		{base_goods_fashion,ets_base_goods_fashion},
		{lucky_draw,ets_luckydraw},
		{target_lead,ets_targetlead},
		{achieve_statistics, ets_ach_stats, "玩家成就系统的统计数据"},
		{log_ach_finish, ets_log_ach_f, "玩家最近完成的成就记录"},
		{login_award,ets_login_award},
		{base_daily_gift,ets_base_daily_gift},
		{base_tower_award,ets_tower_award},
		{base_magic,ets_base_magic},	
		{cycle_flush,ets_cycle_flush}	,
		{war_player,ets_war_player},
		{war_team,ets_war_team},
		{war_vs,ets_war_vs},
		{war_state,ets_war_state},
		{appraise,ets_appraise},
		{pet_buy,ets_pet_buy},
		{pet_split_skill,ets_pet_split_skill},
		{base_pet_skill_effect,ets_base_pet_skill_effect},	
		{guild_union, guild_union, "氏族结盟归附情况申请表"},
		{vip_info,ets_vip},
		{log_f5_gwish, ets_f5_gwish, "玩家帮忙刷新任务的日志记录"},
		{novice_gift,ets_novice_gift},
		{pet_extra,ets_pet_extra},
		{pet_extra_value,ets_pet_extra_value},
		{war_award,ets_war_award},
		{castle_rush_info, ets_castle_rush_info, "攻城战信息"},	
		{castle_rush_join, ets_castle_rush_join, "攻城战氏族报名记录"},	
		{marry, ets_marry},
		{wedding,ets_wedding},
		{loveday,ets_loveday},		
		{guild_alliance, ets_g_alliance, "氏族联盟表"},
		{guild_alliance_apply, ets_g_alliance_apply, "氏族联盟申请表"},
		{find_exp,ets_find_exp},
		{mount,ets_mount},
		{mount_skill_exp,ets_mount_skill_exp},
		{mount_skill_split,ets_mount_skill_split},
		{mount_arena,ets_mount_arena},
		{mount_battle_result,ets_battle_result},
		{mount_arena_recent,ets_mount_recent},
		{log_mount_award,ets_log_award},
		{log_buy_goods, log_buy_goods, "市场求购记录日志表"},
		{td_single_award, ets_single_td_award},
		{coliseum_rank, ets_coliseum_rank, "竞技场排行"},
		{coliseum_info, ets_coliseum_info, "竞技场信息"},
		{player_other, ets_player_other, "记录玩家的额外字段数据"},
		{war2_record,ets_war2_record,"跨服单人竞技记录表"},
		{war2_elimination,ets_war2_elimination,"跨服单人淘汰赛记录表"},
		{war2_history,ets_war2_history,"跨服单人竞技历史记录"},
		{war2_bet,ets_war2_bet,"跨服单人竞技下注表"},
		{fs_era,ets_fs_era,"封神纪元信息"},
		{war2_pape,ets_war2_pape,"跨服战报"},
		{target,ets_target,"新玩家目标"}
	]
	   ).

%% -record(erlydb_field,
%% 	{name, name_str, name_bin, type, modifier, erl_type,
%% 	 html_input_type,
%% 	 null, key,
%% 	 default, extra, attributes}).
%%
%% Exported Functions
%%
-compile(export_all). 

%%
%% API Functions
%%
start()->	
	case  get_db_config(?CONFIG_FILE) of
		[Host, Port, User, Password, DB, Encode] ->
			start_erlydb(Host, Port, User, Password, DB),
    		mysql:start_link(?DB_POOL, Host, Port, User, Password, DB, fun(_, _, _, _) -> ok end, Encode),
    		mysql:connect(?DB_POOL, Host, Port, User, Password, DB, Encode, true),
  			tables_to_record(),
			ok;
		_ -> mysql_config_fail
	end,
  	halt(),
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

%% @doc 生成指定的表名的beam文件
%% @spec code_gen/0
%%      unilog_mysql_pool:code_gen()

code_gen() ->
	code_gen(?TABLES).

code_gen(TableName) ->
	TableList = writeTempFile(TableName),
%% io:format("TableList=~p~n~n",[TableList]),
	erlydb:code_gen(TableList,{mysql, 
							   [{allow_unsafe_statements, true},
								{skip_fk_checks, true}]},
								[debug_info,{skip_fk_checks, true},
								 {outdir,"../ebin/"}]),
	clearTempFile(),
	ok.

%% @doc 通过beam生成erl文件，方便开发查看模块方法
%%		调用该方法之前，必须先调用code_gen()方法，生成表对应的beam文件
%% @spec code_gen_src/0
code_gen_src() ->
	lists:foreach(fun(TableName) ->
						  Beam = lists:concat([?BEAM_PATH, TableName,".beam"]),
						  case beam_lib:chunks(Beam, [abstract_code]) of
							  {ok,{_,[{abstract_code,{_,AC}}]}} ->
								  Code = erl_prettypr:format(erl_syntax:form_list(AC)),
								  file:write_file(lists:concat([?SRC_TABLE_PATH,TableName,".erl"]), list_to_binary(Code)),
								  io:format("build beam:~p to erl:~p success.~n", [TableName, TableName]);
							  {error, beam_lib, Reason} ->
								  io:format("code_gen_erl_file error, reason:~p~n", [Reason])
						  end
				  end, ?TABLES).	

%% @doc 为指定的表名生成module文件，给code_gen/0 使用
%% @spec writeTempFile/0 ->[TableFilePath]
%%	eg: TableFilePath -> "./tmptable/tuser_friend_log.erl"
writeTempFile(TableName)->
	clearTempFile(),
	ok = file:make_dir(?TMP_TABLE_PATH),
	lists:map(fun(F)-> 
					  Filename =  
						  ?TMP_TABLE_PATH ++ atom_to_list(F) ++ ".erl",
					  Bytes = list_to_binary( io_lib:format("-module(~w).", [F]) ),
					  file:write_file(Filename, Bytes),
					  Filename
			  end, TableName).

clearTempFile()->
	case file:list_dir(?TMP_TABLE_PATH) of
		{ok, Filenames} ->
			lists:foreach(fun(F)->
								  file:delete(?TMP_TABLE_PATH ++ F) end , Filenames);
		{error, _} -> ignore
	end,
	file:del_dir(?TMP_TABLE_PATH).

tables_to_record() ->
	Bakfile = re:replace(
		lists:flatten(lists:concat([?RECORD_FILENAME , "_", time_format(now())])),
		"[ :]","_",[global,{return,list}]),

	file:rename(?RECORD_FILENAME, Bakfile), 
	
	file:write_file(?RECORD_FILENAME, ""),
	file:write_file(?RECORD_FILENAME, "%%%------------------------------------------------\t\n",[append]),
	file:write_file(?RECORD_FILENAME, "%%% File    : table_to_record.erl\t\n",[append]),
	file:write_file(?RECORD_FILENAME, "%%% Author  : ygzj\t\n",[append]),
	Bytes = list_to_binary(io_lib:format("%%% Created : ~s\t\n", [time_format(now())])),
	file:write_file(?RECORD_FILENAME, Bytes,[append]),
	file:write_file(?RECORD_FILENAME, "%%% Description: 从mysql表生成的record\t\n",[append]),
	file:write_file(?RECORD_FILENAME, "%%% Warning:  由程序自动生成，请不要随意修改！\t\n",[append]),	
	file:write_file(?RECORD_FILENAME, "%%%------------------------------------------------	\t\n",[append]),
	file:write_file(?RECORD_FILENAME, " \t\n",[append]),

	io:format("~n~n"),
	
	lists:foreach(fun(Table)-> 
					case Table of 
						{Table_name, Record_name} -> table_to_record(Table_name, Record_name, "");
						{Table_name, Record_name, TableComment} -> table_to_record(Table_name, Record_name, TableComment);
						_-> no_action
					end	
			  	  end, 
				  ?TABLES),
	io:format("finished!~n~n"),	
	ok.

%%获取数据类型
get_field_type(Type) when is_binary(Type) ->
	get_field_type(binary_to_list(Type));
get_field_type(Type) ->
	case re:run(Type,"int",[caseless]) of
		{match,_} ->
			integer;
		_ ->
			case re:run(Type,"char",[caseless]) of
				{match,_} ->
					binary;
				_ ->
					''
			end
	end.
	
%% table_to_record:table_to_record(user, 1).
%% [A,B]=db_sql:get_row("show create table user;")
%% db_sql:get_row("select * from base_goods_type;")
table_to_record(Table_name, Record_name, TableComment) ->
	file:write_file(?RECORD_FILENAME, "\t\n",[append]),	
	Sql = lists:concat(["show create table ", Table_name]),
	try 
		case  db_sql:get_row(Sql) of  
			{db_error, _} ->
				error;
			[_, A | _]->
 				Create_table_list = re:split(A,"[\n]",[{return, binary}]), 
				Table_comment =
					case TableComment of
						"" -> get_table_comment(Create_table_list, Table_name);
						_ -> TableComment
					end,
							  
				file:write_file(?RECORD_FILENAME, 
								list_to_binary(io_lib:format("%% ~s\t\n",[Table_comment])), 
								[append]),
				file:write_file(?RECORD_FILENAME, 
								list_to_binary(io_lib:format("%% ~s ==> ~s \t\n",[Table_name, Record_name])), 
								[append]),
				file:write_file(?RECORD_FILENAME, 
								list_to_binary(io_lib:format("-record(~s, {\t\n",[Record_name])), 
								[append]),				
				%%code_gen([Table_name]),				
				%%Table_fields = erlang:apply(Table_name, db_fields, []),
				Sql2 = lists:concat(["desc ",Table_name]),
				Table_fields = db_sql:get_all(Sql2),
				lists:mapfoldl(fun(FieldInfo, Sum) ->
								[FieldName,Type,_Null,_Key,DefaultV,_Extra] = FieldInfo ,
								Field_comment = get_field_comment(Create_table_list, Sum),
								Default = 
									case DefaultV of
										undefined -> '';
										<<>> -> 
											case get_field_type(Type) of
												binary -> 
													lists:concat([" = \"\""]);
												integer -> 
													lists:concat([" = 0"]);
												_ -> '' 
											end;
										<<"[]">> ->
												lists:concat([" = ", binary_to_list(DefaultV)]);
										Val -> 
											case get_field_type(Type) of
												binary -> 
													lists:concat([" = <<\"", binary_to_list(Val) ,"\">>"]);
%% 												integer -> 
%% 													lists:concat([" = 0"]);
												_ -> 
													lists:concat([" = ", binary_to_list(Val)])
											end																				
									end,
								T1 = 
									if Sum == length(Table_fields) -> 
										   '';
										true -> ','
							   		end,  
								T2 = io_lib:format("~s~s~s",
																 [FieldName, 
																  Default,
																  T1]), 
								T3 = lists:duplicate(40-length(lists:flatten(T2)), " "),
								Bytes = list_to_binary(io_lib:format("      ~s~s%% ~s\t\n",
																 [T2, 
																  T3,
																  Field_comment])), 								
								file:write_file(?RECORD_FILENAME, 
										Bytes,
										[append]),								
								{
								[], 
								Sum+1
								}
								end,
							 	1, Table_fields),
				
				file:write_file(?RECORD_FILENAME, 
								list_to_binary(io_lib:format("    }).\t\n",[])), 
								[append]),	
				io:format("                 ~s ==> ~s ~n",[Table_name, Record_name]),
				ok
		end
	catch
		_:_ -> error
	end.

get_field_comment(Create_table_list, Loc) ->
	try
%% 	L1 = re:split(lists:nth(Loc+1, Create_table_list),"[ ]",[{return, list}]),
		L1 = binary_to_list(lists:nth(Loc+1, Create_table_list)),	
%%   io:format("L1 = ~p ~n", [L1]),		
		Loc1 = string:rstr(L1, "COMMENT "),
%%   io:format("Loc = ~p ~n", [Loc1]),	
		case Loc1 > 0 of
			true -> 
				L2 = string:substr(L1, Loc1 + 8),
				L3 = lists:subtract(L2, [39,44]),
				lists:subtract(L3, [39]);
			_ -> ""
		end
	catch
		_:_ -> ""
	end.

get_table_comment(Create_table_list, Table_name) ->
	try
%% 	L1 = re:split(lists:nth(Loc+1, Create_table_list),"[ ]",[{return, list}]),
		Len  = length(Create_table_list),	
		L1 = binary_to_list(lists:nth(Len, Create_table_list)),	
%%   io:format("L1 = ~p ~n", [L1]),		
		Loc1 = string:rstr(L1, "COMMENT="),
%%   io:format("Loc = ~p ~n", [Loc1]),	
		case Loc1 > 0 of
			true -> 
				L2 = string:substr(L1, Loc1 + 8),
				L3 = lists:subtract(L2, [39,44]),
				lists:subtract(L3, [39]);
			_ -> Table_name
		end
	catch
		_:_ -> Table_name
	end.	
  
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




%% ------------------------------------------------------------------------------------------------------
%% *********************************从mysql表生成的诛邪系统物品概率碰撞表 start ****************************
%% ------------------------------------------------------------------------------------------------------
get_date_box() ->
	Careers = lists:seq(1,5),
	lists:map(fun get_data_box_career/1, Careers).
get_data_box_career(Career) ->
%% 	DataFileName = lists:concat(["../src/data/data_box_", Career, ".erl"]),
%% 	Bakfile = re:replace(
%% 		lists:flatten(lists:concat([DataFileName , "_", time_format(now())])),
%% 		"[ :]","_",[global,{return,list}]),
%% 	
%% 	file:rename(DataFileName, Bakfile), 
%% 	
%% 	file:write_file(DataFileName, ""),
%% 	file:write_file(DataFileName, "%%%------------------------------------------------\t\n",[append]),
%% 	file:write_file(DataFileName, "%%% File    : data_box_X.erl\t\n",[append]),
%% 	file:write_file(DataFileName, "%%% Author  : xiaomai\t\n",[append]),
%% 	Bytes = list_to_binary(io_lib:format("%%% Created : ~s\t\n", [time_format(now())])),
%% 	file:write_file(DataFileName, Bytes,[append]),
%% 	file:write_file(DataFileName, "%%% Description: 从mysql表生成的诛邪系统物品概率碰撞表\t\n",[append]),
%% 	file:write_file(DataFileName, "%%% Warning:  由程序自动生成，请不要随意修改！\t\n",[append]),	
%% 	file:write_file(DataFileName, "%%%------------------------------------------------	\t\n",[append]),
%% 	file:write_file(DataFileName, " \t\n",[append]),
%% 	ModuleName = lists:concat(["-module(data_box_",Career,")."]),
%% 	file:write_file(DataFileName, ModuleName,[append]),
%% 	file:write_file(DataFileName, " \t\n\n",[append]),
%% 	file:write_file(DataFileName, "-export([get_goods_one/3]).",[append]),
%% 	file:write_file(DataFileName, " \t\n",[append]),
%% 	file:write_file(DataFileName, " \t\n",[append]),
%% 	file:write_file(DataFileName, "get_goods_one(HoleType, Career, RandomCount) ->\n\t",[append]),
	Counts = lists:seq(1,3),
	lists:map(fun(Elem)-> handle_data_box_each(Career, Elem) end, Counts),
%% 	ErCodeend = "GoodsInfo = lists:concat([\"Goods_info_\", HoleType, Elem, \"00\"]),
%% 	%%注意这里的返回值	
%% 	{BaseGoodsId} = lists:nth(RandomCount, GoodsInfo),
%% 	BaseGoodsId.",
%% 	file:write_file(DataFileName, ErCodeend,[append]),
	io:format("~n~n").
%% handle_data_box_each(Elem, Career) ->
%% 	Sum = lists:seq(1,5),
%% 	lists:foldl(fun handle_data_box_each_one/2,{Elem}, Sum).
handle_data_box_each(Career, Elem) ->
	DataFileName = lists:concat(["../src/data/data_box_", Career, Elem, ".erl"]),
	Bakfile = re:replace(
		lists:flatten(lists:concat([DataFileName , "_", time_format(now())])),
		"[ :]","_",[global,{return,list}]),
	
	file:rename(DataFileName, Bakfile), 	
	file:write_file(DataFileName, ""),
	file:write_file(DataFileName, "%%%------------------------------------------------\t\n",[append]),
	file:write_file(DataFileName, "%%% File    : data_box_XX.erl\t\n",[append]),
	file:write_file(DataFileName, "%%% Author  : xiaomai\t\n",[append]),
	Bytes = list_to_binary(io_lib:format("%%% Created : ~s\t\n", [time_format(now())])),
	file:write_file(DataFileName, Bytes,[append]),
	file:write_file(DataFileName, "%%% Description: 从mysql表生成的诛邪系统物品概率碰撞表\t\n",[append]),
	file:write_file(DataFileName, "%%% Warning:  由程序自动生成，请不要随意修改！\t\n",[append]),	
	file:write_file(DataFileName, "%%%------------------------------------------------	\t\n",[append]),
	file:write_file(DataFileName, " \t\n",[append]),
	ModuleName = lists:concat(["-module(data_box_", Career, Elem, ")."]),
	file:write_file(DataFileName, ModuleName,[append]),
	file:write_file(DataFileName, " \t\n\n",[append]),
	file:write_file(DataFileName, "-export([get_goods_one/3]).",[append]),
	file:write_file(DataFileName, " \t\n",[append]),
	file:write_file(DataFileName, " \t\n",[append]),
	file:write_file(DataFileName, "get_goods_one(HoleType, Career, RandomCount) ->\n\t",[append]),

	Sql = 
		io_lib:format("select a.pro, a.goods_id from `base_box_goods` a, `base_goods` b where hole_type = ~p and b.goods_id = a.goods_id and b.career in (0,~p) order  by a.goods_id desc",
					  [Elem,Career]),
	Lists = db_sql:get_all(Sql),
	ElemName = lists:concat(["Goods_info_", Career, Elem, "00 = ["]),
	file:write_file(DataFileName,ElemName,[append]),
 	{_NewCount, _FileName} = lists:foldl(fun make_content_goods/2,{1, DataFileName},Lists),
%% 	io:format("the [~p]count is[~p]\n\n\n", [Career, NewCount]),
%%  	String = lists:concat(Result),
%%  	file:write_file(?FILENAME, string:substr(String,1, string:len(String)),[append]),
	
	file:write_file(DataFileName,"],\n\t",[append]),
	ErCodeEndOne = "
	%%注意这里的返回值	
	{BaseGoodsId} = lists:nth(RandomCount, ",
	ErCodeEndTwo = "),
	BaseGoodsId.",
	EndString = lists:concat([ErCodeEndOne,"Goods_info_",Career,Elem,"00",ErCodeEndTwo]),
	file:write_file(DataFileName, EndString,[append]).
	
make_content_goods(List, AccIn) ->
	[Pro, GoodsId] = List,
	{Count, DataFileName} = AccIn,
	NewPro = Pro*100000,
	NewProInt = tool:to_integer(NewPro),
	Sum = lists:seq(1, NewProInt),
	{NewCount, _GodosId, Result} = lists:foldl(fun get_content_array/2,{Count,GoodsId,[]},Sum),
	String = lists:concat(lists:reverse(Result)),
 	file:write_file(DataFileName, String,[append]),
%% 	file:write_file(DataFileName, "\n\t\t\t\t\t\t",[append]),
%% 	io:format("the elem is {~p,~p,~p,~p}\t\t", [Pro,NewProInt,NewCount,length(Result)]),
	{NewCount, DataFileName}.
get_content_array(_Elem,AccIn) ->
	{Count, GoodsId, ResultList} = AccIn,
	case tool:to_integer(Count) =:= 100000 of
		true ->
 			ResultElem = lists:concat(["{", GoodsId, "}"]);
		false ->
 			ResultElem = lists:concat(["{", GoodsId, "},"])
	end,
	{Count+1, GoodsId, [ResultElem|ResultList]}.
%% ------------------------------------------------------------------------------------------------------
%% *********************************从mysql表生成的诛邪系统物品概率碰撞表 end ****************************
%% ------------------------------------------------------------------------------------------------------
