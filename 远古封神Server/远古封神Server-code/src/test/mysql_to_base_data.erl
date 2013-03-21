-module(mysql_to_base_data).
-export([
	start/0		 
]).

-include("record.hrl").

-define(CONFIG_FILE, "../config/gateway.config").
-define(PoolId, mysql_conn_for_mongodb).
-define(SAVE_PATH, "../src/data/").

start() ->
    case get_mysql_config(?CONFIG_FILE) of
        [Host, Port, User, Password, DB, Encode] ->
            mysql:start_link(?PoolId, Host, Port, User, Password, DB,  fun(_, _, _, _) -> ok end, Encode),
            mysql:connect(?PoolId, Host, Port, User, Password, DB, Encode, true),
            Now = time_format(now()),
			spawn(fun()-> create_data_dungeon(Now) end),
			spawn(fun()-> create_data_pet_skill(Now) end),
            create_data_scene(Now),
            create_data_task(Now),
			create_data_skill(Now);
        _ -> 
            mysql_config_fail
    end,
    halt().


create_data_pet_skill(Now) ->
	Name = "data_pet_skill",
	io:format("CREATE BASE DATA `~s` ...~n", [Name]),
	File = ?SAVE_PATH ++ Name ++ ".erl",
    file:write_file(File, "%%%---------------------------------------\n"),
    file:write_file(File, "%%% @Module  : " ++ Name ++ "\n", [append]),
    file:write_file(File, "%%% @Author  : ygfs\n", [append]),
    file:write_file(File, "%%% @Created : " ++ Now ++ "\n", [append]),
    file:write_file(File, "%%% @Description:  自动生成\n", [append]),
    file:write_file(File, "%%%---------------------------------------\n", [append]),
    file:write_file(File, "\n", [append]),
    file:write_file(File, "-module(" ++ Name ++ ").\n", [append]),
    file:write_file(File, "-export(\n", [append]),
    file:write_file(File, "\t[\n", [append]),
    file:write_file(File, "\t\tget/1\n", [append]),
    file:write_file(File, "\t]\n", [append]),
    file:write_file(File, ").\n", [append]),
    file:write_file(File, "-include(\"record.hrl\").\n", [append]),
    file:write_file(File, "\n", [append]),
	
	PetSkillFun = fun(D) ->
		Skill = list_to_tuple([ets_pet_skill | D]),
		file:write_file(File, io_lib:format("get(~p) ->\n", [Skill#ets_pet_skill.id]), [append]),
		file:write_file(File, "\t#ets_pet_skill{\n", [append]),
		file:write_file(File, io_lib:format("\t\tid = ~p,\n", [Skill#ets_pet_skill.id]), [append]),
		file:write_file(File, io_lib:format("\t\tname = <<\"~s\">>,\n", [Skill#ets_pet_skill.name]), [append]),
		file:write_file(File, io_lib:format("\t\ttype = ~p,\n", [util:string_to_term(binary_to_list(Skill#ets_pet_skill.type))]), [append]),
		file:write_file(File, io_lib:format("\t\tlv = ~p,\n", [Skill#ets_pet_skill.lv]), [append]),
		file:write_file(File, io_lib:format("\t\trate = ~p,\n", [Skill#ets_pet_skill.rate]), [append]),
		file:write_file(File, io_lib:format("\t\thurt_rate = ~p,\n", [Skill#ets_pet_skill.hurt_rate]), [append]),
		file:write_file(File, io_lib:format("\t\thurt = ~p,\n", [Skill#ets_pet_skill.hurt]), [append]),
		file:write_file(File, io_lib:format("\t\tcd = ~p,\n", [util:ceil(Skill#ets_pet_skill.cd / 1000)]), [append]),
		file:write_file(File, io_lib:format("\t\teffect = ~p,\n", [Skill#ets_pet_skill.effect]), [append]),
		file:write_file(File, io_lib:format("\t\tlastime = ~p,\n", [util:ceil(Skill#ets_pet_skill.lastime / 1000)]), [append]),
		file:write_file(File, io_lib:format("\t\tdata = ~p\n", [util:string_to_term(binary_to_list(Skill#ets_pet_skill.data))]), [append]),
		file:write_file(File, "\t};\n", [append]),
		file:write_file(File, "\n", [append])
	end,
	
	Sql = "SELECT * FROM `base_skill_pet` ORDER BY `id`",
	Data = handleResult(mysql:fetch(?PoolId, list_to_binary(Sql))),
	[PetSkillFun(D) || D <- Data],
	
	file:write_file(File, "get(_SkillId) ->\n", [append]),
	file:write_file(File, "\t[].\n", [append]),
	file:write_file(File, "\n", [append]).
	
	
create_data_skill(Now) ->
	Name = "data_skill",
	io:format("CREATE BASE DATA `~s` ...~n", [Name]),
	File = ?SAVE_PATH ++ Name ++ ".erl",
    file:write_file(File, "%%%---------------------------------------\n"),
    file:write_file(File, "%%% @Module  : " ++ Name ++ "\n", [append]),
    file:write_file(File, "%%% @Author  : ygfs\n", [append]),
    file:write_file(File, "%%% @Created : " ++ Now ++ "\n", [append]),
    file:write_file(File, "%%% @Description:  自动生成\n", [append]),
    file:write_file(File, "%%%---------------------------------------\n", [append]),
    file:write_file(File, "\n", [append]),
    file:write_file(File, "-module(" ++ Name ++ ").\n", [append]),
    file:write_file(File, "-export(\n", [append]),
    file:write_file(File, "\t[\n", [append]),
    file:write_file(File, "\t\tget/2,\n", [append]),
    file:write_file(File, "\t\tget_skill_id_list/1\n", [append]),
    file:write_file(File, "\t]\n", [append]),
    file:write_file(File, ").\n", [append]),
    file:write_file(File, "-include(\"record.hrl\").\n", [append]),
    file:write_file(File, "\n", [append]),
	
	SkillIdListFun = fun(_Time, Career) ->
		GSIL = io_lib:format("get_skill_id_list(~p) ->\n", [Career]),
		file:write_file(File, GSIL, [append]),
		Sql = io_lib:format("SELECT GROUP_CONCAT(DISTINCT `id` ORDER BY `id`) AS `ids` FROM `base_skill` WHERE `career` = ~p", [Career]),
		[[Data]] = handleResult(mysql:fetch(?PoolId, list_to_binary(Sql))),	
		D = binary_to_list(Data),
		file:write_file(File, "\t[" ++ D ++ "];\n", [append]),
		Career + 1
   	end,
	lists:foldl(SkillIdListFun, 1, lists:seq(1, 5)),
	file:write_file(File, "get_skill_id_list(_Career) ->\n", [append]),
	file:write_file(File, "\t[].\n", [append]),
	file:write_file(File, "\n", [append]),
	
	%% 技能效果值FUN
	SkillDataItemFun = fun({_Key, Val}, SDI) ->
		[Val | SDI]
	end,
	
	%% 技能效果FUN
	SkillDataFun = fun({Lv, SkillData}) ->
		file:write_file(File, io_lib:format("\t\t\t\t~p ->\n", [Lv]), [append]),
		[_LevelDesc, BaseAtt, Lastime, Shortime, Cast, Condition] = lists:foldl(SkillDataItemFun, [], SkillData),
		file:write_file(File, io_lib:format("\t\t\t\t\t[{condition, ~s}, {cast, ~s}, {shortime, ~s}, {lastime, ~s}, {base_att, ~s}];\n", [Condition, Cast, Shortime, Lastime, BaseAtt]), [append])
	end,
	
	SkillFun = fun(D) ->
		Skill = list_to_tuple([ets_skill | D]),
		file:write_file(File, io_lib:format("get(~p, SkillLv) ->\n", [Skill#ets_skill.id]), [append]),
		file:write_file(File, "\t#ets_skill{\n", [append]),
		file:write_file(File, io_lib:format("\t\tid = ~p,\n", [Skill#ets_skill.id]), [append]),
		file:write_file(File, io_lib:format("\t\tname = <<\"~s\">>,\n", [Skill#ets_skill.name]), [append]),
		file:write_file(File, io_lib:format("\t\tcareer = ~p,\n", [Skill#ets_skill.career]), [append]),
		file:write_file(File, io_lib:format("\t\tmod = ~p,\n", [Skill#ets_skill.mod]), [append]),
		file:write_file(File, io_lib:format("\t\ttype = ~p,\n", [Skill#ets_skill.type]), [append]),
		file:write_file(File, io_lib:format("\t\tobj = ~p,\n", [Skill#ets_skill.obj]), [append]),
		file:write_file(File, io_lib:format("\t\tarea = ~p,\n", [Skill#ets_skill.area]), [append]),
		file:write_file(File, io_lib:format("\t\tarea_obj = ~p,\n", [Skill#ets_skill.area_obj]), [append]),
		file:write_file(File, io_lib:format("\t\tassist_type = ~p,\n", [Skill#ets_skill.assist_type]), [append]),
		file:write_file(File, io_lib:format("\t\tlimit_action = ~p,\n", [Skill#ets_skill.limit_action]), [append]),
		file:write_file(File, io_lib:format("\t\thate = ~p,\n", [list_to_integer(binary_to_list(Skill#ets_skill.hate))]), [append]),
		
		{[Data], _} = php_parser:unserialize(Skill#ets_skill.data),
		file:write_file(File, "\t\tdata = \n", [append]),
		file:write_file(File, "\t\t\tcase SkillLv of\n", [append]),
		
		lists:foreach(SkillDataFun, Data),
		file:write_file(File, "\t\t\t\t_ ->\n", [append]),
		file:write_file(File, "\t\t\t\t\t[]\n", [append]),
		file:write_file(File, "\t\t\tend\n", [append]),
		
		file:write_file(File, "\t};\n", [append]),
		file:write_file(File, "\n", [append])
	end,
	
	Sql = "SELECT * FROM `base_skill`",
	Data = handleResult(mysql:fetch(?PoolId, list_to_binary(Sql))),
	lists:foreach(SkillFun, Data),
	
	file:write_file(File, "get(_SkillId, _SkillLv) ->\n", [append]),
	file:write_file(File, "\t[].\n", [append]),
	file:write_file(File, "\n", [append]).


create_data_dungeon(Now) ->
	Name = "data_dungeon",
	io:format("CREATE BASE DATA `~s` ...~n", [Name]),
	File = ?SAVE_PATH ++ Name ++ ".erl",
    file:write_file(File, "%%%---------------------------------------\n"),
    file:write_file(File, "%%% @Module  : " ++ Name ++ "\n", [append]),
    file:write_file(File, "%%% @Author  : ygfs\n", [append]),
    file:write_file(File, "%%% @Created : " ++ Now ++ "\n", [append]),
    file:write_file(File, "%%% @Description:  自动生成\n", [append]),
    file:write_file(File, "%%%---------------------------------------\n", [append]),
    file:write_file(File, "\n", [append]),
    file:write_file(File, "-module(" ++ Name ++ ").\n", [append]),
    file:write_file(File, "-export(\n", [append]),
    file:write_file(File, "\t[\n", [append]),
    file:write_file(File, "\t\tget/1\n", [append]),
    file:write_file(File, "\t]\n", [append]),
    file:write_file(File, ").\n", [append]),
    file:write_file(File, "-include(\"record.hrl\").\n", [append]),
    file:write_file(File, "\n", [append]),
	
	DungeonFun = fun(D) ->
		Dungeon = list_to_tuple([dungeon | D]),
		file:write_file(File, io_lib:format("get(~p) ->\n", [Dungeon#dungeon.id]), [append]),
		file:write_file(File, "\t#dungeon{\n", [append]),
		file:write_file(File, io_lib:format("\t\tid = ~p,\n", [Dungeon#dungeon.id]), [append]),
		file:write_file(File, io_lib:format("\t\tname = <<\"~s\">>,\n", [Dungeon#dungeon.name]), [append]),
		file:write_file(File, io_lib:format("\t\tdef = ~p,\n", [Dungeon#dungeon.def]), [append]),
		file:write_file(File, io_lib:format("\t\tout = ~s,\n", [Dungeon#dungeon.out]), [append]),
		file:write_file(File, io_lib:format("\t\tscene = ~p,\n", [util:string_to_term(binary_to_list(Dungeon#dungeon.scene))]), [append]),
		file:write_file(File, io_lib:format("\t\trequirement = ~p\n", [util:string_to_term(binary_to_list(Dungeon#dungeon.requirement))]), [append]),
		file:write_file(File, "\t};\n", [append]),

		file:write_file(File, "\n", [append])
	end,	

	Sql = "SELECT * FROM `base_dungeon`",
	Data = handleResult(mysql:fetch(?PoolId, list_to_binary(Sql))),

	lists:foreach(DungeonFun, Data),

	file:write_file(File, "get(_DungeonId) ->\n", [append]),
	file:write_file(File, "\t[].\n", [append]),
	file:write_file(File, "\n", [append]).

create_data_scene(Now) ->
	Name = "data_scene",
	io:format("CREATE BASE DATA `~s` ...~n", [Name]),
	File = ?SAVE_PATH ++ Name ++ ".erl",
    file:write_file(File, "%%%---------------------------------------\n"),
    file:write_file(File, "%%% @Module  : " ++ Name ++ "\n", [append]),
    file:write_file(File, "%%% @Author  : ygfs\n", [append]),
    file:write_file(File, "%%% @Created : " ++ Now ++ "\n", [append]),
    file:write_file(File, "%%% @Description:  自动生成\n", [append]),
    file:write_file(File, "%%%---------------------------------------\n", [append]),
    file:write_file(File, "\n", [append]),
    file:write_file(File, "-module(" ++ Name ++ ").\n", [append]),
    file:write_file(File, "-export(\n", [append]),
    file:write_file(File, "\t[\n", [append]),
	file:write_file(File, "\t\tget_id_list/0,\n", [append]),
	file:write_file(File, "\t\tget_hook_scene_list/0,\n", [append]),
	file:write_file(File, "\t\tdungeon_get_id_list/0,\n", [append]),
	file:write_file(File, "\t\tcommon_dungeon_get_id_list/0,\n", [append]),
	file:write_file(File, "\t\tdungeon_type2_get_id_list/0,\n", [append]),
	file:write_file(File, "\t\tscene_border_list/0,\n", [append]),
    file:write_file(File, "\t\tget/1\n", [append]),
    file:write_file(File, "\t]\n", [append]),
    file:write_file(File, ").\n", [append]),
    file:write_file(File, "-include(\"record.hrl\").\n", [append]),
	file:write_file(File, "\n", [append]),
	
	SceneIdListSql = "SELECT GROUP_CONCAT(DISTINCT `sid` ORDER BY `sid`) as `ids` FROM `base_scene`",
	[[SceneIdList]] = handleResult(mysql:fetch(?PoolId, list_to_binary(SceneIdListSql))),	
	SceneIdData = binary_to_list(SceneIdList),
	file:write_file(File, "%% 场景ID列表\n", [append]),
	file:write_file(File, "get_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ SceneIdData ++ "].\n\n", [append]),
	
	HookSceneIdListSql = "SELECT GROUP_CONCAT(DISTINCT `sid` ORDER BY `sid`) as `ids` FROM `base_scene` WHERE `type` = 10",
	[[HookSceneIdList]] = handleResult(mysql:fetch(?PoolId, list_to_binary(HookSceneIdListSql))),	
	HookSceneIdData = binary_to_list(HookSceneIdList),
	file:write_file(File, "%% 挂机场景ID列表\n", [append]),
	file:write_file(File, "get_hook_scene_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ HookSceneIdData ++ "].\n\n", [append]),
	
	DungeonSceneIdListSql = "SELECT GROUP_CONCAT(DISTINCT `id` ORDER BY `id`) as `ids` FROM `base_dungeon`",
	[[DungeonSceneIdList]] = handleResult(mysql:fetch(?PoolId, list_to_binary(DungeonSceneIdListSql))),	
	DungeonSceneIdData = binary_to_list(DungeonSceneIdList),
	file:write_file(File, "%% 副本场景ID列表\n", [append]),
	file:write_file(File, "dungeon_get_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ DungeonSceneIdData ++ "].\n\n", [append]),
	
	CommonDungeonSceneIdListSql = "SELECT GROUP_CONCAT(DISTINCT `id` ORDER BY `id`) as `ids` FROM `base_dungeon` WHERE `id` < 998",
	[[CommonDungeonSceneIdList]] = handleResult(mysql:fetch(?PoolId, list_to_binary(CommonDungeonSceneIdListSql))),	
	CommonDungeonSceneIdData = binary_to_list(CommonDungeonSceneIdList),
	file:write_file(File, "%% 普通副本场景ID列表\n", [append]),
	file:write_file(File, "common_dungeon_get_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ CommonDungeonSceneIdData ++ "].\n\n", [append]),
	
	Dungeon2SceneIdListSql = "SELECT GROUP_CONCAT(DISTINCT `sid` ORDER BY `sid`) as `ids` FROM `base_scene` WHERE `type` = 2",
	[[Dungeon2SceneIdList]] = handleResult(mysql:fetch(?PoolId, list_to_binary(Dungeon2SceneIdListSql))),	
	Dungeon2SceneIdData = binary_to_list(Dungeon2SceneIdList),
	file:write_file(File, "%% 副本类型为2的场景ID列表\n", [append]),
	file:write_file(File, "dungeon_type2_get_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ Dungeon2SceneIdData ++ "].\n\n", [append]),
	
	
	file:write_file(File, "%% 获取场景相邻关系数据\n", [append]),
	SceneBorderElemFun = fun([_SceneIndex, SceneId, _SceneName, _X, _Y], ElemText) ->
		ElemText ++ tool:to_list(SceneId) ++ ","					 
	end,
	SceneBorderFun = fun([SceneId, Elem], L) ->
		NewElem = data_agent:convert_elem(binary_to_list(Elem)),
		ElemSceneIdList = lists:foldl(SceneBorderElemFun, "", NewElem),
		NewElemSceneIdList = "[" ++ string:strip(ElemSceneIdList, right, $,) ++ "]",
		Comma = 
			if
				L =/= 1 ->
					",";
				true ->
					""
			end,
		file:write_file(File, io_lib:format("\t\t{~p, ~s}~s\n", [SceneId, NewElemSceneIdList, Comma]), [append]),
		L - 1
	end,
	SceneBorderSql = "SELECT `id`, `elem` FROM `base_scene` WHERE `type` in (0, 1, 10)",
	SceneBorderData = handleResult(mysql:fetch(?PoolId, list_to_binary(SceneBorderSql))),
	LenSceneBorderData = length(SceneBorderData),
	file:write_file(File, "scene_border_list() ->\n", [append]),
	file:write_file(File, "\t[\n", [append]),
	lists:foldl(SceneBorderFun, LenSceneBorderData, SceneBorderData),
	file:write_file(File, "\t].\n\n", [append]),
	
	
	NpcFun = fun([NpcId, X, Y], NpcText) ->
		Text = io_lib:format("[~p, ~p, ~p],", [NpcId, X, Y]),
		NpcText ++ Text
	end,
	
	MonFun = fun([MonId, X, Y, Type], MonText) ->
		Text = io_lib:format("[~p, ~p, ~p, ~p],", [MonId, X, Y, Type]),
		MonText ++ Text
	end,
	
	ElemFun = fun(S, [ElemText, Index]) ->
		[_Index, SceneId, SceneName, X, Y] = S,
		Text = io_lib:format("[~p, ~p, <<\"~s\">>, ~p, ~p],", [Index, SceneId, SceneName, X, Y]),
		[ElemText ++ Text, Index + 1]
   	end,
	
	SceneFun = fun(D) ->
		Scene = list_to_tuple([ets_scene | D]),
		file:write_file(File, io_lib:format("get(~p) ->\n", [Scene#ets_scene.sid]), [append]),
		file:write_file(File, "\t#ets_scene{\n", [append]),
		file:write_file(File, io_lib:format("\t\tsid = ~p,\n", [Scene#ets_scene.sid]), [append]),
		file:write_file(File, io_lib:format("\t\ttype = ~p,\n", [Scene#ets_scene.type]), [append]),
		file:write_file(File, io_lib:format("\t\tname = <<\"~s\">>,\n", [Scene#ets_scene.name]), [append]),
		file:write_file(File, io_lib:format("\t\tx = ~p,\n", [Scene#ets_scene.x]), [append]),
		file:write_file(File, io_lib:format("\t\ty = ~p,\n", [Scene#ets_scene.y]), [append]),
		file:write_file(File, io_lib:format("\t\tsafe = ~s,\n", [Scene#ets_scene.safe]), [append]),
		
		Npc = data_agent:convert_npc(binary_to_list(Scene#ets_scene.npc)),
		NewNpc = string:strip(lists:foldl(NpcFun, "", Npc), right, $,),
		file:write_file(File, io_lib:format("\t\tnpc = [~s],\n", [NewNpc]), [append]),
		
		Mon = data_agent:convert_mon(binary_to_list(Scene#ets_scene.mon)),
		NewMon = string:strip(lists:foldl(MonFun, "", Mon), right, $,),
		file:write_file(File, io_lib:format("\t\tmon = [~s],\n", [NewMon]), [append]),
		
		Elem = data_agent:convert_elem(binary_to_list(Scene#ets_scene.elem)),
		[ElemText, _Index] = lists:foldl(ElemFun, ["", 1], Elem),
		NewElem = string:strip(ElemText, right, $,),
		file:write_file(File, io_lib:format("\t\telem = [~s],\n", [NewElem]), [append]),
		
		Requirement = data_agent:convert_requirement(binary_to_list(Scene#ets_scene.requirement)),
		file:write_file(File, io_lib:format("\t\trequirement = ~p,\n", [Requirement]), [append]),
		
		file:write_file(File, io_lib:format("\t\tid = ~p\n", [Scene#ets_scene.id]), [append]),
		file:write_file(File, "\t};\n", [append]),
		file:write_file(File, "\n", [append])
	end,
	SceneSql = "SELECT * FROM `base_scene`",
	SceneData = handleResult(mysql:fetch(?PoolId, list_to_binary(SceneSql))),
	lists:foreach(SceneFun, SceneData),

	file:write_file(File, "get(_SceneId) ->\n", [append]),
	file:write_file(File, "\t[].\n", [append]),
    file:write_file(File, "\n", [append]).


create_data_task(Now) ->
	Name = "data_task",
	io:format("CREATE BASE DATA `~s` ...~n", [Name]),
	File = ?SAVE_PATH ++ Name ++ ".erl",
	%File = "../src/" ++ Name ++ ".erl",
    file:write_file(File, "%%%---------------------------------------\n"),
    file:write_file(File, "%%% @Module  : " ++ Name ++ "\n", [append]),
    file:write_file(File, "%%% @Author  : ygfs\n", [append]),
    file:write_file(File, "%%% @Created : " ++ Now ++ "\n", [append]),
    file:write_file(File, "%%% @Description:  自动生成\n", [append]),
    file:write_file(File, "%%%---------------------------------------\n", [append]),
    file:write_file(File, "\n", [append]),
    file:write_file(File, "-module(" ++ Name ++ ").\n", [append]),
    file:write_file(File, "-export(\n", [append]),
    file:write_file(File, "\t[\n", [append]),
	file:write_file(File, "\t\ttask_get_id_list/0,\n", [append]),
	file:write_file(File, "\t\ttask_get_novice_id_list/0,\n", [append]),
	file:write_file(File, "\t\ttask_get_main_id_list/0,\n", [append]),
	file:write_file(File, "\t\ttask_get_btanch_id_list/0,\n", [append]),
	file:write_file(File, "\t\ttask_get_daily_id_list/0,\n", [append]),
	file:write_file(File, "\t\ttask_get_normal_daily_id_list/0,\n", [append]),
	file:write_file(File, "\t\ttask_get_pk_mon_id_list/0,\n", [append]),
	file:write_file(File, "\t\ttask_get_dungeon_id_list/0,\n", [append]),
	file:write_file(File, "\t\ttask_get_guild_id_list/0,\n", [append]),
	file:write_file(File, "\t\ttask_get_carry_id_list/1,\n", [append]),
	file:write_file(File, "\t\ttask_get_guild_carry_id_list/1,\n", [append]),
	file:write_file(File, "\t\ttask_get_business_id_list/0,\n", [append]),
	file:write_file(File, "\t\ttask_get_cycle_id_list/0,\n", [append]),
	file:write_file(File, "\t\ttask_get_random_cycle_id_list/0,\n", [append]),
	file:write_file(File, "\t\ttask_get_hero_card_id_list/0\n", [append]),
	%file:write_file(File, "\t\tget/1\n", [append]),
    file:write_file(File, "\t]\n", [append]),
    file:write_file(File, ").\n", [append]),
    file:write_file(File, "-include(\"record.hrl\").\n", [append]),
	file:write_file(File, "\n", [append]),
	
	TaskIdFun = fun([TaskId], TaskIdText) ->
		Text = io_lib:format("~p,", [TaskId]),
		TaskIdText ++ Text
   	end,
	
	TaskIdListSql = "SELECT `id` FROM `base_task` ORDER BY `id`",
	TaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(TaskIdListSql))),
	TaskIdData = string:strip(lists:foldl(TaskIdFun, "", TaskIdList), right, $,),
	file:write_file(File, "%% 所有任务ID列表\n", [append]),
	file:write_file(File, "task_get_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ TaskIdData ++ "].\n\n", [append]),
	
	NoviceTaskIdListSql = "SELECT `id` FROM `base_task` WHERE `type` = 4 ORDER BY `id`",
	NoviceTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(NoviceTaskIdListSql))),
	NoviceTaskIdData = string:strip(lists:foldl(TaskIdFun, "", NoviceTaskIdList), right, $,),
	file:write_file(File, "%% 新手任务ID列表\n", [append]),
	file:write_file(File, "task_get_novice_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ NoviceTaskIdData ++ "].\n\n", [append]),
	
	MainTaskIdListSql = "SELECT `id` FROM `base_task` WHERE `type` = 0 or `type` = 4 ORDER BY `id`",
	MainTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(MainTaskIdListSql))),
	MainTaskIdData = string:strip(lists:foldl(TaskIdFun, "", MainTaskIdList), right, $,),
	file:write_file(File, "%% 主线任务ID列表\n", [append]),
	file:write_file(File, "task_get_main_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ MainTaskIdData ++ "].\n\n", [append]),
	
	BtanchTaskIdListSql = "SELECT `id` FROM `base_task` WHERE `type` = 1 ORDER BY `id`",
	BtanchTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(BtanchTaskIdListSql))),
	BtanchTaskIdData = string:strip(lists:foldl(TaskIdFun, "", BtanchTaskIdList), right, $,),
	file:write_file(File, "%% 支线任务ID列表\n", [append]),
	file:write_file(File, "task_get_btanch_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ BtanchTaskIdData ++ "].\n\n", [append]),
	
	DailyTaskIdListSql = "SELECT `id` FROM `base_task` WHERE `type` = 2 and `child` != 3 ORDER BY `id`",
	DailyTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(DailyTaskIdListSql))),
	DailyTaskIdData = string:strip(lists:foldl(TaskIdFun, "", DailyTaskIdList), right, $,),
	file:write_file(File, "%% 日常任务ID列表\n", [append]),
	file:write_file(File, "task_get_daily_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ DailyTaskIdData ++ "].\n\n", [append]),
	
	NormalDailyTaskIdListSql = "SELECT `id` FROM `base_task` WHERE `type` = 2 and (`child` = 1 or `child` = 6) and `kind` = 1 ORDER BY `id`",
	NormalDailyTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(NormalDailyTaskIdListSql))),
	NormalDailyTaskIdData = string:strip(lists:foldl(TaskIdFun, "", NormalDailyTaskIdList), right, $,),
	file:write_file(File, "%% 普通日常任务ID列表(日常打怪，副本)\n", [append]),
	file:write_file(File, "task_get_normal_daily_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ NormalDailyTaskIdData ++ "].\n\n", [append]),
	
	NormalTaskIdListSql = "SELECT `id` FROM `base_task` WHERE `type` = 2 and `child` = 1 and `kind` = 1 ORDER BY `id`",
	NormalTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(NormalTaskIdListSql))),
	NormalTaskIdData = string:strip(lists:foldl(TaskIdFun, "", NormalTaskIdList), right, $,),
	file:write_file(File, "%% 普通日常守护任务ID列表\n", [append]),
	file:write_file(File, "task_get_pk_mon_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ NormalTaskIdData ++ "].\n\n", [append]),
	
	DungeonTaskIdListSql = "SELECT `id` FROM `base_task` WHERE `type` = 2 and `child` = 6 and `kind` = 1 ORDER BY `id`",
	DungeonTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(DungeonTaskIdListSql))),
	DungeonTaskIdData = string:strip(lists:foldl(TaskIdFun, "", DungeonTaskIdList), right, $,),
	file:write_file(File, "%% 副本任务ID列表\n", [append]),
	file:write_file(File, "task_get_dungeon_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ DungeonTaskIdData ++ "].\n\n", [append]),
	
	GuildTaskIdListSql = "SELECT `id` FROM `base_task` WHERE `type` = 3 ORDER BY `id`",
	GuildTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(GuildTaskIdListSql))),
	GuildTaskIdData = string:strip(lists:foldl(TaskIdFun, "", GuildTaskIdList), right, $,),
	file:write_file(File, "%% 帮会任务ID列表\n", [append]),
	file:write_file(File, "task_get_guild_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ GuildTaskIdData ++ "].\n\n", [append]),
	

	
	file:write_file(File, "%% 运镖任务ID列表\n", [append]),
	CarryTaskFun = fun(Realm) ->
		CarryTaskIdListSql = io_lib:format("SELECT `id` FROM `base_task` WHERE `type` = 2 and `child` = 3 and (`realm` = 0 or `realm` = ~p) ORDER BY `id`", [Realm]),
		CarryTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(CarryTaskIdListSql))),
		CarryTaskIdData = string:strip(lists:foldl(TaskIdFun, "", CarryTaskIdList), right, $,),
		file:write_file(File, io_lib:format("task_get_carry_id_list(~p) ->\n", [Realm]), [append]),
		file:write_file(File, "\t[" ++ CarryTaskIdData ++ "];\n", [append])
	end,
	lists:foreach(CarryTaskFun, [1, 2, 3]),
	file:write_file(File, "task_get_carry_id_list(_Realm) ->\n", [append]),
	file:write_file(File, "\t[].\n\n", [append]),
	
	file:write_file(File, "%% 氏族运镖任务ID列表\n", [append]),
	GuildCarryTaskFun = fun(Realm) ->
		GuildCarryTaskIdListSql = io_lib:format("SELECT `id` FROM `base_task` WHERE `type` = 2 and `child` = 15 and (`realm` = 0 or `realm` = ~p) ORDER BY `id`", [Realm]),
		GuildCarryTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(GuildCarryTaskIdListSql))),
		GuildCarryTaskIdData = string:strip(lists:foldl(TaskIdFun, "", GuildCarryTaskIdList), right, $,),
		file:write_file(File, io_lib:format("task_get_guild_carry_id_list(~p) ->\n", [Realm]), [append]),
		file:write_file(File, "\t[" ++ GuildCarryTaskIdData ++ "];\n", [append])
	end,
	lists:foreach(GuildCarryTaskFun, [1, 2, 3]),
	file:write_file(File, "task_get_guild_carry_id_list(_Realm) ->\n", [append]),
	file:write_file(File, "\t[].\n\n", [append]),
	
	BusinessTaskIdListSql = "SELECT `id` FROM `base_task` WHERE `type` = 2 and `child` = 4 ORDER BY `id`",
	BusinessTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(BusinessTaskIdListSql))),
	BusinessTaskIdData = string:strip(lists:foldl(TaskIdFun, "", BusinessTaskIdList), right, $,),
	file:write_file(File, "%% 跑商任务ID列表\n", [append]),
	file:write_file(File, "task_get_business_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ BusinessTaskIdData ++ "].\n\n", [append]),
	
	CycleTaskIdListSql = "SELECT `id` FROM `base_task` WHERE `type` = 5 and `child` = 22 ORDER BY `id`",
	CycleTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(CycleTaskIdListSql))),
	CycleTaskIdData = string:strip(lists:foldl(TaskIdFun, "70100,", CycleTaskIdList), right, $,),
	file:write_file(File, "%% 循环任务ID列表\n", [append]),
	file:write_file(File, "task_get_cycle_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ CycleTaskIdData ++ "].\n\n", [append]),
	
	RandomCycleTaskIdListSql = "SELECT `id` FROM `base_task` WHERE `type` = 5 and `child` = 21 ORDER BY `id`",
	RandomCycleTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(RandomCycleTaskIdListSql))),
	RandomCycleTaskIdData = string:strip(lists:foldl(TaskIdFun, "", RandomCycleTaskIdList), right, $,),
	file:write_file(File, "%% 随机循环任务ID列表\n", [append]),
	file:write_file(File, "task_get_random_cycle_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ RandomCycleTaskIdData ++ "].\n\n", [append]),
	
	HeroCardTaskIdListSql = "SELECT `id` FROM `base_task` WHERE `type` = 2 and `child` = 17 ORDER BY `id`",
	HeroCardTaskIdList = handleResult(mysql:fetch(?PoolId, list_to_binary(HeroCardTaskIdListSql))),
	HeroCardTaskIdData = string:strip(lists:foldl(TaskIdFun, "", HeroCardTaskIdList), right, $,),
	file:write_file(File, "%% 封神贴任务ID列表\n", [append]),
	file:write_file(File, "task_get_hero_card_id_list() ->\n", [append]),
	file:write_file(File, "\t[" ++ HeroCardTaskIdData ++ "].\n\n\n", [append]),
	
%% 	TaskToolFun1 = fun({P1, P2, P3}, StartItemText) ->
%% 		Text = io_lib:format("{~p, ~p, ~p},", [P1, P2, P3]),
%% 		StartItemText ++ Text
%% 	end,
	
%% 	TaskFun = fun(T) ->
%% 		Task = list_to_tuple([task | T]),
%% 		file:write_file(File, io_lib:format("get(~p) ->\n", [Task#task.id]), [append]),
%% 		file:write_file(File, "\t#task{\n", [append]),
%% 		
%% 		StartItem = data_agent:task_getItemCode(Task#task.start_item),
%% 		NewStartItem = string:strip(lists:foldl(TaskToolFun1, "", StartItem), right, $,),
%% 		file:write_file(File, io_lib:format("\t\tstart_item = [~s],\n", [NewStartItem]), [append]),
%% 		
%% 		TalkItem = data_agent:task_getItemCode(Task#task.talk_item),
%% 		file:write_file(File, io_lib:format("\t\ttalk_item = ~p,\n", [TalkItem]), [append]),
%% 		
%% 		EndItem = data_agent:task_getItemCode(Task#task.end_item),
%% 		file:write_file(File, io_lib:format("\t\tend_item = ~p,\n", [EndItem]), [append]),
%% 		
%% 		StartNpc = data_agent:task_valToTagCode(Task#task.start_npc),
%% 		file:write_file(File, io_lib:format("\t\tstart_npc = ~p,\n", [StartNpc]), [append]),
%% 		
%% 		Condition = data_agent:task_getConditionCode(Task#task.condition),
%% 		file:write_file(File, io_lib:format("\t\tcondition = ~p,\n", [Condition]), [append]),
%% 		
%% 		Content = data_agent:task_getContentCode(Task#task.content, Task#task.end_npc, Task#task.end_talk),
%% 		file:write_file(File, io_lib:format("\t\tcontent = ~p,\n", [Content]), [append]),
%% 		
%% 		AwardItem = data_agent:task_getItemCode(Task#task.award_item),
%% 		NewAwardItem = string:strip(lists:foldl(TaskToolFun1, "", AwardItem), right, $,),
%% 		file:write_file(File, io_lib:format("\t\taward_item = [~s],\n", [NewAwardItem]), [append]),
%% 		
%% 		AwardSelectItem = data_agent:task_getItemCode(Task#task.award_select_item),
%% 		file:write_file(File, io_lib:format("\t\taward_select_item = ~p,\n", [AwardSelectItem]), [append]),
%% 		
%% 		AwardGift = data_agent:task_getItemCode(Task#task.award_gift),
%% 		file:write_file(File, io_lib:format("\t\taward_gift = ~p\n", [AwardGift]), [append]),
%% 		
%% 		file:write_file(File, "\t};\n", [append]),
%% 		file:write_file(File, "\n", [append])
%% 	end,
%% 	TaskSql = "SELECT * FROM `base_task`",
%% 	TaskData = handleResult(mysql:fetch(?PoolId, list_to_binary(TaskSql))),
%% 	lists:foreach(TaskFun, TaskData),
	
%% 	file:write_file(File, "get(_TaskId) ->\n", [append]),
%% 	file:write_file(File, "\t[].\n", [append]),
    file:write_file(File, "\n", [append]).
	


get_mysql_config(ConfigFile)->
	try
		{ok, [Content]} = file:consult(ConfigFile),
		{_, Config} = lists:keyfind(gateway, 1, Content),
		{_, MysqlConfig} = lists:keyfind(mysql_config, 1, Config),
		{_, Host} = lists:keyfind(host, 1, MysqlConfig),
		{_, Port} = lists:keyfind(port, 1, MysqlConfig),
		{_, User} = lists:keyfind(user, 1, MysqlConfig),
		{_, Password} = lists:keyfind(password, 1, MysqlConfig),
		{_, DB} = lists:keyfind(db, 1, MysqlConfig),
		{_, Encode} = lists:keyfind(encode, 1, MysqlConfig),
		[Host, Port, User, Password, DB, Encode]		
	catch
		_:_ -> no_config
	end.

%% 将mysql:fetch(?DB,Bin)查询结果转换为[[A]]形式,
handleResult(Data) ->
	{_, {_, _, R, _, _}} = Data,
	R.

one_to_two(One) -> io_lib:format("~2..0B", [One]).

time_format(Now) -> 
	{{Y,M,D},{H,MM,S}} = calendar:now_to_local_time(Now),
	lists:concat([Y, "-", one_to_two(M), "-", one_to_two(D), " ", 
						one_to_two(H) , ":", one_to_two(MM), ":", one_to_two(S)]).
