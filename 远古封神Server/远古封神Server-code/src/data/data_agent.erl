%%%----------------------------------------
%%% @Module  : data_agent
%%% @Author  : ygzj
%%% @Created : 2010.09.16
%%% @Description: 数据转换常用函数
%%%----------------------------------------
-module(data_agent).
-compile(export_all).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

dungeon_get_id_list() ->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->
   			MS = ets:fun2ms(fun(T) -> T#dungeon.id	end),			
   			case (catch ets:select(?ETS_BASE_DUNGEON, MS)) of
				{'EXIT', _Reason} -> [];
				Val -> Val
			end.
%% 			end;
%% 		_-> 
%% 			data_dungeon:get_id_list()
%% 	end.

%%获取普通副本列表
common_dungeon_get_id_list() ->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->
   			MS = ets:fun2ms(fun(T) when T#dungeon.id <998 -> T#dungeon.id	end),			
   			case (catch ets:select(?ETS_BASE_DUNGEON, MS)) of
				{'EXIT', _Reason} -> [];
				Val -> Val
			end.
%% 			end;
%% 		_-> 
%% 			data_dungeon:get_id_list()
%% 	end.

dungeon_get(Id) -> 
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
			case ets:lookup(?ETS_BASE_DUNGEON, Id) of
   				[] -> [];
   				[D] ->  D
			end.
%% 			end;			
%% 		_-> 
%% 			data_dungeon:get(Id)
%% 	end.		

mask_get(Id) ->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->
   			MS = ets:fun2ms(fun(T) when T#ets_scene.sid =:= Id-> T#ets_scene.mask	end),
   			case ets:select(?ETS_BASE_SCENE, MS) of
				[] -> [];
				[D] -> D
			end.
%% 			end;			
%% 		_-> 
%% 			data_mask:get(Id)
%% 	end.			

mon_get(Id) ->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->
   			MS = ets:fun2ms(fun(T) when T#ets_mon.mid =:= Id -> T end),
			case ets:select(?ETS_BASE_MON, MS) of
   				[] -> [];
   				[D] ->  D
			end.
%% 			end;			
%% 		_-> 
%% 			data_mon:get(Id)
%% 	end.	

npc_get(Id) ->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#ets_npc.nid =:= Id-> T end),
			case ets:select(?ETS_BASE_NPC, MS) of
   				[] -> [];
   				[D] -> D
			end.
%% 			end;			
%% 		_-> 
%% 			data_npc:get(Id)
%% 	end.	

scene_get_id_list() ->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->
   			MS = ets:fun2ms(fun(T) -> T#ets_scene.sid end),
   			ets:select(?ETS_BASE_SCENE, MS).			
%% 		_-> 
%% 			data_scene:get_id_list()
%% 	end.		

scene_get(SceneId) ->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->
			case ets:lookup(?ETS_BASE_SCENE, SceneId) of
   				[] -> [];
   				[D] -> D#ets_scene{mask = undefined}
			end.
%% 			end;			
%% 		_-> 
%% 			data_scene:get(Id)
%% 	end.

%%获取挂机场景ID列表
get_hook_scene_list()->[120,122,123,124,126].
	%% 	case config:get_read_data_mode(server) of
%% 		1 ->
%%    			MS = ets:fun2ms(fun(T) when T#ets_scene.type=:=10 -> T#ets_scene.sid end),
%%    			ets:select(?ETS_BASE_SCENE, MS).			
%% 		_-> 
%% 			data_scene:get_id_list()
%% 	end.


%% 获取场景怪物唯一信息
scene_get_unique_mon(SceneId) ->
	case ets:lookup(?ETS_BASE_SCENE_UNIQUE_MON, SceneId) of
   		[] -> 
			[];
   		[D] -> 
			D#ets_base_scene_unique_mon.mon
	end.

%% 获取指定职业的所有技能
%% Career 职业ID
skill_get_id_list(Career) ->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#ets_skill.career =:= Career -> T#ets_skill.id	end),
   			ets:select(?ETS_BASE_SKILL, MS).			
%% 	    _ ->
%%             data_skill:get_id_list(Id)
%% 	end.

%% 获取技能数据
%% Id 技能ID
%% Lv 技能等级
skill_get(Id, Lv) ->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
			case ets:lookup(?ETS_BASE_SKILL, Id) of
   				[] -> [];
   				[D] -> D#ets_skill{data = skill_get_data(D#ets_skill.data, Lv)}
			end.
%% 			end;
%% 		_ -> 
%%             data_skill:get(Id, Lv)
%% 	end.			

%% 获取每级技能的效果数据
%% D 所有等级的效果数据
%% Lv 等级
skill_get_data(D, Lv) ->
	try
		{[Res], _} = php_parser:unserialize(D),
		case lists:keyfind(Lv, 1, Res) of
			false -> [];
			{_, T} -> [{P, util:string_to_term(tool:to_list(S))} || {P, S} <- T]
		end
	catch
	    _:_ -> []
	end.		

%%取物品所有的技能 
get_goods_skill_all(Player, Now, AttType) ->
	GoodsRing4 = Player#player.other#player_other.goods_ring4,
	case GoodsRing4 /= [] andalso AttType == 0 of
		true ->
			GoodsBlessList = [{BlessLevel, BlessSkill} || {BlessLevel, BlessSkill} <- GoodsRing4, BlessLevel =/= 0, BlessSkill =/= 0],
			case GoodsBlessList of
				[] ->
					Player#player.other#player_other.battle_status;
				_ ->
					GoodsBuffCD = Player#player.other#player_other.goods_buf_cd,
					loop_goods_buff(GoodsBlessList, GoodsBuffCD, Now, Player#player.other#player_other.battle_status)
			end;
		false ->
			Player#player.other#player_other.battle_status
	end.

loop_goods_buff([], _GoodsBuffCD, _Now, RetBuff) ->
	RetBuff;
loop_goods_buff([{BlessLevel, BlessSkillId} | GoodsBlessList], GoodsBuffCD, Now, RetBuff) ->
	GoodsSkillInfo = data_skill:get(BlessSkillId, BlessLevel),
	case lists:keyfind(lastime, 1, GoodsSkillInfo#ets_skill.data) of
		false -> 
			loop_goods_buff(GoodsBlessList, GoodsBuffCD, Now, RetBuff);
		LastTimeData ->
			case LastTimeData of
				{lastime, [{T, Key, [EffectValue, Ratio, CD, Interval]}]} ->
					case lists:keyfind(BlessSkillId, 1, GoodsBuffCD) of
						false ->
							case tool:odds(Ratio, 100) of
								true ->
									Buff = {Key, [EffectValue, Ratio, CD, Interval], Now + T, BlessSkillId, BlessLevel},
									loop_goods_buff(GoodsBlessList, GoodsBuffCD, Now, [Buff | RetBuff]);
								false ->
									loop_goods_buff(GoodsBlessList, GoodsBuffCD, Now, RetBuff)
							end;
						{_SkillId, LastUserTime} ->
							%% 判断物品buff是否超过cd时间
							case Now > LastUserTime + CD andalso tool:odds(Ratio, 100) of
								true ->
									Buff = {Key, [EffectValue,Ratio, CD, Interval], Now + T, BlessSkillId, BlessLevel},
									loop_goods_buff(GoodsBlessList, GoodsBuffCD, Now, [Buff | RetBuff]);
								false ->
									loop_goods_buff(GoodsBlessList, GoodsBuffCD, Now, RetBuff)
							end
					end;
				_ ->
					[]
			end
	 end.

task_get_id_list() ->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) -> T#task.id	end),
   			ets:select(?ETS_BASE_TASK, MS).		
%% 		_-> 
%% 			data_task:get_id_list()
%% 	end.	

talk_get(Id) ->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#talk.id =:= Id -> T#talk.content end),
			case ets:select(?ETS_BASE_TALK, MS) of
   				[] -> [];
   				[D] -> D
			end.
%% 			end;			
%% 		_-> 
%% 			data_talk:get(Id)
%% 	end.		
		
%%新手任务id列表
task_get_novice_id_list()->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#task.type =:= 4-> T#task.id	end),
   			ets:select(?ETS_BASE_TASK, MS).
%% 		_-> 
%% 			data_task:get_novice_id_list()
%% 	end.
	
%%主线任务id列表
task_get_main_id_list()->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#task.type =:= 0 orelse T#task.type =:= 4 -> T#task.id	end),
   			ets:select(?ETS_BASE_TASK, MS).
%% 		_-> 
%% 			data_task:get_main_id_list()
%% 	end.
	
%%支线任务id列表
task_get_btanch_id_list()->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#task.type =:= 1 -> T#task.id	end),
   			ets:select(?ETS_BASE_TASK, MS).		
%% 		_-> 
%% 			data_task:get_btanch_id_list()
%% 	end.
	
%%日常任务id列表
task_get_daily_id_list()->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#task.type =:= 2, T#task.child =/= 3-> T#task.id	end),
   			ets:select(?ETS_BASE_TASK, MS).
%% 		_-> 
%% 			data_task:get_daily_id_list()
%% 	end.

%%普通日常任务id列表(日常打怪，副本)
task_get_normal_daily_id_list()->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#task.type =:= 2, (T#task.child=:=1 orelse T#task.child=:=6), T#task.kind=:=1-> T#task.id	end),
   			ets:select(?ETS_BASE_TASK, MS).				
%% 		_-> 
%% 			data_task:get_daily_id_list()
%% 	end.

%%日常帮会id列表
task_get_guild_id_list()->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#task.type =:= 3 -> T#task.id	end),
   			ets:select(?ETS_BASE_TASK, MS).			
%% 		_->
%% 			[]
%% %% 			data_task:get_daily_id_list()
%% 	end.

%%运镖任务id列表
task_get_carry_id_list(Realm)->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#task.type =:= 2, T#task.child =:= 3, (T#task.realm =:= Realm orelse T#task.realm =:= 0) -> T#task.id	end),
   			ets:select(?ETS_BASE_TASK, MS).		
%% 		_-> 
%% 			data_task:get_carry_id_list(Realm)
%% 	end.

task_get_guild_carry_id_list(Realm)->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#task.type =:= 2, T#task.child =:= 15, (T#task.realm =:= Realm orelse T#task.realm =:= 0) -> T#task.id	end),
   			ets:select(?ETS_BASE_TASK, MS).
%% 		_-> 
%% 			data_task:get_carry_id_list(Realm)
%% 	end.

%%运镖任务id列表
task_get_business_id_list()->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#task.type =:= 2, T#task.child =:= 4 -> T#task.id	end),
   			ets:select(?ETS_BASE_TASK, MS).		
%% 		_-> 
%% 			data_task:get_carry_id_list(Realm)
%% 	end.

%%循环任务列表
task_get_cycle_id_list()->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#task.type =:= 5 ,T#task.child =:= 22-> T#task.id	end),
   			TaskList = ets:select(?ETS_BASE_TASK, MS),
			[70100|TaskList].
%% 		_-> 
%% 			data_task:get_cycle_id_list()
%% 	end.

%%随机循环任务列表
task_get_random_cycle_id_list()->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->	
   			MS = ets:fun2ms(fun(T) when T#task.type =:= 5 ,T#task.child =:= 21-> T#task.id	end),
   			ets:select(?ETS_BASE_TASK, MS).
%% 		_-> 
%% 			data_task:get_cycle_id_list()
%% 	end.

%%封神贴任务列表
task_get_hero_card_id_list()->
	MS = ets:fun2ms(fun(T) when T#task.type =:= 2,T#task.child=:=17 -> T#task.id	end),
   			ets:select(?ETS_BASE_TASK, MS).

task_get(Id) ->
%% 	case config:get_read_data_mode(server) of
%% 		1 ->
			case ets:lookup(?ETS_BASE_TASK, Id) of
   				[] -> [];
   				[D] -> D
			end.
%% 			end;			
%% 		_-> 
%% 			data_task:get(Id)
%% 	end.		

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
convert_requirement(D) ->
	try
	{ok, D1, []}  = rfc4627:decode(D), 
	[{obj, Obj1},
     {obj, Obj2},
     {obj, Obj3}] = D1,
	{value,{"type", P1}} =  lists:keysearch("type",1, Obj1),
	{value,{"attr", V1}} =  lists:keysearch("attr",1, Obj1),
	{value,{"type", P2}} =  lists:keysearch("type",1, Obj2),
	{value,{"attr", V2}} =  lists:keysearch("attr",1, Obj2),
	{value,{"type", P3}} =  lists:keysearch("type",1, Obj3),
	{value,{"attr", V3}} =  lists:keysearch("attr",1, Obj3),
	[{util:string_to_term(tool:to_list(P1)), util:string_to_term(tool:to_list(V1))}, 
	 {util:string_to_term(tool:to_list(P2)), util:string_to_term(tool:to_list(V2))},
	 {util:string_to_term(tool:to_list(P3)), util:string_to_term(tool:to_list(V3))}]
	catch
		_:_ -> []
	end.

convert_elem(Data) ->
	try
		{ok, D, []}  = rfc4627:decode(Data),
		Fun = fun({obj, L}, [Index, Ret]) ->
			{value,{"id", Id}} = lists:keysearch("id",1, L),
			{value,{"x", X}} = lists:keysearch("x",1, L),
			{value,{"y", Y}} = lists:keysearch("y",1, L),
			{value,{"name", Name}} = lists:keysearch("name",1, L),
			NewRet = 
				[
			 		Index,
			 		util:string_to_term(tool:to_list(Id)), 
					Name, 
					util:string_to_term(tool:to_list(X)), 
					util:string_to_term(tool:to_list(Y))
				],
			[Index + 1, [NewRet | Ret]]
			
		end,
		[_Index, RetData] = lists:foldl(Fun, [1, []], D),
		RetData
	catch
		_:_ -> []
	end.	

convert_npc(Data) ->
	try
		{ok, NewData, []} = rfc4627:decode(Data),
		Fun = fun({obj, D}) ->
			{value, {"id", NpcId}} = lists:keysearch("id",1, D),
			{value, {"x", X}} = lists:keysearch("x",1, D),
			{value, {"y", Y}} = lists:keysearch("y",1, D),
			[
				util:string_to_term(tool:to_list(NpcId)), 
				util:string_to_term(tool:to_list(X)), 
				util:string_to_term(tool:to_list(Y))
			]
		end,
		lists:map(Fun, NewData)
	catch
		_:_ -> []
	end.	

convert_mon(D) ->
	try
	{ok, D1, []}  = rfc4627:decode(D), 
	lists:map(fun(D2) ->
			   {obj,L} = D2,
			   {value,{"id", Id}} =  lists:keysearch("id",1, L),
			   {value,{"x", X}} =  lists:keysearch("x",1, L),
			   {value,{"y", Y}} =  lists:keysearch("y",1, L),
			   {value,{"lv", Lv}} =  lists:keysearch("lv",1, L),
			    [util:string_to_term(tool:to_list(Id)), 
				 util:string_to_term(tool:to_list(X)), 
				 util:string_to_term(tool:to_list(Y)),
				 util:string_to_term(tool:to_list(Lv))
				]
			end, 
			D1)
	catch
		_:_ -> []
	end.	

convert_talk(D) ->
	try
	{ok, D1, []}  = rfc4627:decode(D), 
	lists:foldr(fun(D2, AccList) ->
				[get_talk_childs(D2) | AccList]
				end, 
				[],D1)
	catch
		_:_ -> []
	end.

get_talk_childs(D) ->
	try
	lists:foldr(fun(D2, AccList) ->
				Ret = 		
			   		case D2 of
						[A1, A2] -> 
							{util:string_to_term(tool:to_list(A1)),A2, []};
						[A1,A2,A3] -> 
							{util:string_to_term(tool:to_list(A1)),A2, [util:string_to_term(tool:to_list(A3))]}
					end,
				[Ret | AccList]
			end, 
			[],D)
	catch
		_:_ -> []
	end.


task_getItemCode(Item)->
	try
	case rfc4627:decode(Item) of
		{ok, null,[]} -> [];
		{ok, D1, []} -> 
			lists:foldr(fun(D2, AccList) ->
				  R1 =
					lists:foldr(fun(D3, AccList1) ->
							[util:string_to_term(tool:to_list(D3)) | AccList1]
						end, 
						[],D2),	
				[list_to_tuple(R1) | AccList]
				end, 
				[],D1)
	end
	catch
		_:_ -> []
	end.

task_getItemCodes(Item, Content) ->
	try
	ItemCode = task_getItemCode(Item),
	ContentCode = 
	case rfc4627:decode(Content) of
		{ok, null,[]} -> [];
		{ok, [D1], []} -> 
			lists:foldr(fun(D2, AccList) ->
				  [A0, A1, A2 | _] = D2,
				  case tool:to_list(A0) of
					  "item" -> [{util:string_to_term(tool:to_list(A1)), util:string_to_term(tool:to_list(A2))}| AccList];
					  _->  AccList
				  end
				end, 
				[],D1)
	end,
	ItemCode ++ ContentCode
	catch
		_:_ -> []
	end.
  
task_getTagCode(Str) ->
	case util:string_to_term(tool:to_list(Str)) of
		null -> [];
		I1 -> I1
	end.	
%% 	if(preg_match("/\[(\w+)\](.*?)\[\/\\1\]/i", $str, $result)){
%% 		$list = array();
%% 		if($result[1]=="career"){
%% 			$param = explode(":", $result[2]);
%% 			for($i=1;$i<=count($param);$i++){
%% 				$list[] = "{career, $i, ".intval($result[2])."}";
%% 			}
%% 		}
%% 		return "[".implode(",",$list)."]";
%% 	}else{
%% 		return intval($str);
%% 	}
%% }
%% 

task_valToTagCode(Val) ->	
	try
		util:string_to_term(tool:to_list(Val))
	catch
		_:_ -> 0
	end.

%% 	$val = preg_replace_callback("/\[(\w+)\](.*?)\[\/\\1\]/i", "valToTagCodeCallBack", $val);
%% 	return $val;
%% }
%% 
%% 
%% function valToTagCodeCallBack($result){
%% 	$tags = array('career', 'realm', 'rand', 'name', 'sex','npc');
%% 	if(in_array($result[1], $tags)){
%% 		$paramArr = $result[2]=="" ? array() : explode(":", $result[2]);
%% 		foreach($paramArr as &$val2){
%% 			$val2 = valToTagCode($val2);
%% 		}
%% 		array_unshift($paramArr, $result[1]);
%% 		return "lib_task:convert_select_tag(_PS, [".implode(",",$paramArr)."])";
%% 	}else if($result[1]=="erl"){
%% 		return $result[2];
%% 	}else{
%% 		return $result[0];
%% 	}
%% }
%% 

task_getConditionCode(Codition) ->
	try
	case rfc4627:decode(Codition) of
		{ok, null,[]} -> [];
		{ok, D1, []} -> 
			lists:foldr(fun(D2, AccList) ->
				  R1 =
					lists:foldr(fun(D3, AccList1) ->
							[util:string_to_term(tool:to_list(D3)) | AccList1]
						end, 
						[],D2),	
				[list_to_tuple(R1) | AccList]
				end, 
				[],D1)
	end
	catch
		_:_ -> []
	end.	
%% 	$list = array();
%% 	if(is_array($codition))
%% 	foreach($codition as $val){
%% 		if($val[0]=="task"){
%% 			$list[] = "{task, ".$val[1]."}";
%% 		}else if($val[0]=="task_one"){
%% 			$list[] = "{task_one, [".str_replace(":", ", ", $val[1])."]}";
%% 		}else if($val[0]=="daily_limit"){
%% 			$list[] = "{daily_limit, ".$val[1]."}";
%% 		}else if($val[0]=="guild_level"){
%% 			$list[] = "{guild_level, ".$val[1]."}";
%% 		}
%% 	}
%% 	return "[".implode(",",$list)."]";
%% }
%% 

task_getContentCode(Content, Endnpc, Endtalk) ->
	try
	ContentCode = 
	case rfc4627:decode(Content) of
		{ok, null,[]} -> [];
		{ok, D0, []} -> 
			Len =length(D0),
			{D1, _} = lists:mapfoldr(fun(D01, Sum) ->
							{{Len - Sum, D01},  Sum+1}
						  end, 
						  1,D0),			
			lists:foldr(fun({Key, D2}, AccList) ->
							 task_getContentCode_1(D2, Key) ++ AccList
						  end, 
						  [],D1)
	end,
	case task_valToTagCode(Endnpc) of 
		0  -> ContentCode;
		_ ->
			L= length(ContentCode),
			if 
				L > 1 ->
					L1=1;
			    true->
					L1=L
			end,
		   ContentCode ++ [[L1, 1, end_talk, Endnpc, Endtalk]]
	end
	catch
		_:_ -> []
	end.

task_getContentCode_1(Content, Key) ->
	try
		lists:foldr(fun(D2, AccList) ->
		  	[A0| _] = D2,
		  	case tool:to_list(A0) of
				  "kill" -> 
					  [_A0, A1, A2 | _] = D2,
					  [[Key, 0, kill, util:string_to_term(tool:to_list(A1)), util:string_to_term(tool:to_list(A2)),0] | AccList];
				  "talk" -> 
					  [_A0, A1, A2 | _] = D2,
					  [[Key, 0, talk, util:string_to_term(tool:to_list(A1)), util:string_to_term(tool:to_list(A2))] | AccList];
				  "item" -> 
					  [_A0, A1, A2 | _] = D2,
					  [[Key, 0, item, util:string_to_term(tool:to_list(A1)), util:string_to_term(tool:to_list(A2)),0] | AccList];
				 "collect" -> 
					  [_A0, A1, A2 | _] = D2,
					  [[Key, 0, collect, util:string_to_term(tool:to_list(A1)), util:string_to_term(tool:to_list(A2)),0] | AccList];
				  "open_store" ->
					  [[Key, 0, open_store] | AccList];
				"open_drugstore" ->
					 [_A0, A1, A2 | _] = D2,
					  [[Key, 0, open_drugstore, task_valToTagCode(A1), task_valToTagCode(A2)] | AccList];
				  "equip" -> 
					  [_A0, A1 | _] = D2,
					  [[Key, 0, equip, task_valToTagCode(A1)] | AccList];
				  "buy_equip" ->
					  [_A0, A1, A2 | _] = D2,
					  [[Key, 0, buy_equip, task_valToTagCode(A1), task_valToTagCode(A2)] | AccList];
				  "fishing" -> 
					  [_A0, A1, A2 | _] = D2,
					  [[Key, 0, fishing, util:string_to_term(tool:to_list(A1)), util:string_to_term(tool:to_list(A2)),0] | AccList];
				  "learn_skill" -> 
					  [_A0, A1 | _] = D2,
					  [[Key, 0, learn_skill, task_valToTagCode(A1)] | AccList];
				  "learn_lineup" ->
					  [_A0, A1| _] = D2,
					  [[Key, 0, learn_lineup, task_valToTagCode(A1)] | AccList];
				  "train_equip" ->
					  [_A0, A1 | _] = D2,
					  [[Key, 0, train_equip, util:string_to_term(tool:to_list(A1))] | AccList];
				  "pet" ->
					  [[Key, 0, pet] | AccList];
				  "select_nation" ->
					  [[Key, 0, select_nation] | AccList];
				  "friend" ->
					  [[Key, 0, friend] | AccList];
				  "guild" ->
					  [[Key, 0, guild] | AccList];
				  "master" ->
					  [[Key, 0, master] | AccList];
				  "trump" ->
					 [[Key,0,trump] | AccList];
				  "mount" ->
					 [[Key,0,mount] | AccList];
				  "up_skill" ->
					 [[Key,0,up_skill] | AccList];
				  "use_goods" ->
					  [_A0, A1 | _] = D2,
					  [[Key, 0, use_goods, task_valToTagCode(A1)] | AccList];
				  "shopping" ->
					  [_A0, A1 | _] = D2,
					  [[Key, 0, shopping, task_valToTagCode(A1)] | AccList];
				  "convoy" ->
					 [[Key,0,convoy] | AccList];
				 "appraisal" ->
					  [_A0, A1, A2 | _] = D2,
					  [[Key, 0, appraisal, task_valToTagCode(A1), util:string_to_term(tool:to_list(A2))] | AccList];
				 "arena" ->
					 [[Key,0,arena] | AccList];
				"question" ->
					  [_A0, A1 | _] = D2,
					  [[Key, 0, question, task_valToTagCode(A1)] | AccList];
				"up_level" ->
					  [_A0, A1 | _] = D2,
					  [[Key, 0, up_level, task_valToTagCode(A1)] | AccList];
				"arena_kill" -> 
					  [_A0, A1 | _] = D2,
					  [[Key, 0, arena_kill, task_valToTagCode(A1),0] | AccList];
				"hero_kill" -> 
					  [_A0, A1, A2 | _] = D2,
					  [[Key, 0, hero_kill, task_valToTagCode(A1),task_valToTagCode(A2),0] | AccList];
				"guild_war" ->
					 [[Key,0,guild_war] | AccList];
				"love" ->
					 [[Key,0,love] | AccList];
				"open_manor" ->
					 [[Key,0,open_manor] | AccList];
				"kill_enemy" -> 
					  [_A0, A1 | _] = D2,
					  [[Key, 0, kill_enemy, task_valToTagCode(A1),0] | AccList];
				"save_html" ->
					[[Key,0,save_html] | AccList];
				"magic" ->
					[[Key,0,magic] | AccList];
				"guild_bless"->
					[[Key,0,guild_bless] | AccList];
				"open_strength"->
					[[Key,0,open_strength] | AccList];
				"zhuxie"->
					[[Key,0,zhuxie] | AccList];
				"open_storehouse"->
					[[Key,0,open_storehouse] | AccList];
				"pet_eggs"->
					[[Key,0,pet_eggs] | AccList];
				"pet_skill"->
					[[Key,0,pet_skill] | AccList];
				"open_appraisal"->
					[[Key,0,open_appraisal] | AccList];
				"lover_task"->
					[[Key,0,lover_task] | AccList];
				"lover_flower"->
					[[Key,0,lover_flower] | AccList];
				"lover_train"->
					[[Key,0,lover_train] | AccList];
				"lover_hotspring"->
					[_A0, A1 | _] = D2,
					[[Key,0,lover_hotspring,task_valToTagCode(A1),0] | AccList];
				"passive_skill"->
					[[Key,0,passive_skill] | AccList];
				"mount_fight"->
					[[Key,0,mount_fight] | AccList];
				"mount_change"->
					[[Key,0,mount_change] | AccList];
				"arena_pk"->
					[[Key,0,arena_pk] | AccList];
				"fs_era"->
					[[Key,0,fs_era] | AccList];
				"train_kill" -> 
					[_A0, A1 | _] = D2,
					[[Key, 0, train_kill, task_valToTagCode(A1),0] | AccList];
				"mount_arena"->
					[[Key,0,mount_arena] | AccList];
				"love_show"->
					[[Key,0,love_show] | AccList];
				"nount_pk" -> 
					  [_A0, A1 | _] = D2,
					  [[Key, 0, nount_pk, task_valToTagCode(A1),0] | AccList];
				"arena_fight" -> 
					  [_A0, A1 | _] = D2,
					  [[Key, 0, arena_fight, task_valToTagCode(A1),0] | AccList];
				"use_peach" -> 
					  [_A0, A1 | _] = D2,
					  [[Key, 0, use_peach, task_valToTagCode(A1),0] | AccList];
				"online_time"->
					[[Key,0,online_time] | AccList];
				"online_100"->
					[[Key,0,online_100] | AccList];
				"buy_anything"->
					[[Key,0,buy_anything] | AccList];
				_->  AccList
			end
			end, 
		[],Content)
	catch
		_:_ -> []
	end.


%% 	$list = array();
%% 	if(is_array($content))
%%     foreach($content as $key => $phase){
%%         foreach($phase as $val){
%% 			if($val[0]=="kill"){
%% 				$list[] = "[$key,0, kill, ".$val[1].", ".$val[2].", 0]";
%% 			}else if($val[0]=="talk"){
%% 				$list[] = "[$key,0, talk, ".$val[1].", ".$val[2]."]";
%% 			}else if($val[0]=="item"){
%% 				$list[] = "[$key,0, item, ".$val[1].", ".$val[2].", 0]";
%% 			}else if($val[0]=="open_store"){
%% 				$list[] = "[$key,0, open_store]";
%% 			}else if($val[0]=="equip"){
%% 				$list[] = "[$key,0, equip, ".valToTagCode($val[1])."]";
%% 			}else if($val[0]=="buy_equip"){
%% 				$list[] = "[$key,0, buy_equip, ".valToTagCode($val[1]).", ".$val[2]."]";
%% 			}else if($val[0]=="fishing"){
%% 				$list[] = "[$key,0, fishing, ".$val[1].", ".$val[2].", 0]";
%% 			}else if($val[0]=="learn_skill"){
%% 				$list[] = "[$key,0, learn_skill, ".valToTagCode($val[1])."]";
%% 			}else if($val[0]=="learn_lineup"){
%% 				$list[] = "[$key,0, learn_lineup, ".valToTagCode($val[1])."]";
%% 			}else if($val[0]=="train_equip"){
%% 				$list[] = "[$key,0, train_equip, ".$val[1]."]";
%% 			}
%%         }
%%     }
%% 	if($endnpc!=0){
%% 		$list[] = "[".count($content).",1, end_talk, $endnpc, $endtalk]";
%% 	}
%% 	return "[".implode(",",$list)."]";
%% }


%%轻功数据
get_light_skill(Id,Lv) ->
	case Id of
		50000 ->
			case Lv of
				%%格式为:[角色等级,技能等级,修为,铜币,是否需要技能书(0不需要,1需要),CD时间,耗蓝,可跳距离(格为单位)]
				%%字段为:[Lv,Skill_Lv,Culture,Coin,Skill_Book,Cd,Mp,Distance]
				1 -> [30,1,4500,0,0,30,20,3];
				2 -> [31,2,0,0,0,30,30,4];
				3 -> [32,3,0,0,0,30,40,5];
				4 -> [33,4,0,0,0,30,50,6];
				5 -> [34,5,0,0,0,30,60,7];
				_ -> []
			end;
		_ ->
			[]
	end.

%%根据角色等级算出轻功可升等级
get_light_update_lv(Lv) ->
	if 
		Lv =< 29 ->
			0;
		Lv == 30 ->
			1;
		Lv == 31->
			2;
		Lv == 32->
			3;
		Lv == 33->
			4;
		Lv == 34->
			5;
		true ->
			5
	end.

%%幻化体验卡（新手任务专用）
get_turned_try_eft(Rnd,Type,Sex) ->
	[Mid,{Tid,Value,BuffId}] = 
		case Sex =:= 1 of
			true -> if Rnd =< 33 ->
						   [42011,{1006,30,1001}];
					   Rnd =< 66 ->
						   [41059,{1002,100,1000}];
					   true ->
						   [41010,{1009,50,1002}]
					end;
			false -> if Rnd =< 33 ->
							[41056,{1013,50,1005}];
						Rnd =< 66 ->
						   [41059,{1002,100,1000}];
						true ->
						   [41020,{1010,20,1003}]
					 end
		end,
	if Type =:= 1 ->
		   [Mid,{Tid,Value,BuffId}];
	   true ->
		   [Mid,{Tid,-Value,BuffId}]
	end.								

%% 幻化符
%%变身概率及对应属性数据
%%职业 1，2，3，4，5（分别是玄武--战士、白虎--刺客、青龙--弓手、朱雀--牧师、麒麟--武尊）
get_turned_eft(Rnd,Type,Career) ->
	[Mid,{Tid,Value,BuffId}] =
	if  
		Rnd =<10 ->
			case Career of
				1 ->
					[41057,{1000,100,1000}];%% 变异玄武	41057	防御+100	5%
				2 ->
					[41060,{1003,100,1000}];%% 变异白虎	41060	防御+100	5%
				3 ->
					[41058,{1001,100,1000}];%% 变异青龙	41058	防御+100	5%
				4 ->
					[41059,{1002,100,1000}];%% 变异朱雀	41059	防御+100	5%
				5 ->
					[41061,{1004,100,1000}]%% 变异麒麟	41061	防御+100	5%
			end;
		Rnd =<15 ->
			[42011,{1006,30,1001}]; %% 千年猴妖	42011	攻击+30	    5%
		Rnd =<20 ->
			[42015,{1008,50,1001}]; %% 穷奇巨兽   42015	攻击+50	    4%
		Rnd =<29 ->
			[41010,{1009,50,1002}]; %% 雷公	    41010	命中+50	    7%
		Rnd =<38 ->
			[41020,{1010,20,1003}];%% 狐小小	41020	闪避+20	    7%
		Rnd =<47 ->
			[41030,{1011,10,1004}]; %% 河伯	    41030	暴击+10	    7%
		Rnd =<52 ->
			[41040,{1012,30,1005}]; %% 蚩尤	    41040	全抗+30	    5%
		Rnd =<61 ->
			[41056,{1013,50,1005}]; %% 瑶池圣母	41056	全抗+50	    5%
		Rnd =<68 ->
			[20202,{1014,500,1006}]; %% 林镖头	41056	血+500   5%
		Rnd =<76 ->
			[20910,{1016,500,1006}]; %% 试炼女神	41056	血+500	    5%
		Rnd =<84 ->
			[20229,{1017,500,1006}]; %% 守墓神使	41056	血+500      5%
		Rnd =<92 ->
			[20247,{1018,1000,1006}]; %% 神坛左护法 41056	血+1000	    5%
		Rnd =<100 ->
			[20248,{1019,1000,1006}]  %% 神坛佑护法	41056	血+1000	    5%
	end,		
	if Type =:= 1 ->
		   [Mid,{Tid,Value,BuffId}];
	   true ->
		   [Mid,{Tid,-Value,BuffId}]
	end.	

%%怪物变身卡不加人物属性 
get_mon_change(Rnd, BuffId) ->
	MonId = 
		if Rnd =< 50 ->
			   1021;
		   true ->
			   1022
		end,
	[MonId,{MonId,0,BuffId}].
		
get_chr_snow_turned_eft(_Rnd,_Type,_Career) ->
	[28047,{40107,100,1000}].

%%圣诞变身效果
get_chr_turned_eft(_Rnd,_Type,Player) ->
	case Player#player.career of
		1 ->
			if Player#player.sex == 1 ->
				   [31216,{10941,100,1000}];%% 变异玄武	41057	防御+100	5%
			   true ->
				   [31216,{10942,100,1000}]%% 变异玄武	41057	防御+100	5%
			   end;
		2 ->
			if Player#player.sex == 1 ->
				   [31216,{10943,100,1000}];%% 变异玄武	41057	防御+100	5%
			   true ->
				   [31216,{10944,100,1000}]%% 变异玄武	41057	防御+100	5%
			end;
		3 ->
			if Player#player.sex == 1 ->
				   [31216,{10945,100,1000}];%% 变异玄武	41057	防御+100	5%
			   true ->
				   [31216,{10946,100,1000}]%% 变异玄武	41057	防御+100	5%
			end;
		4 ->
			if Player#player.sex == 1 ->
				   [31216,{10947,100,1000}];%% 变异玄武	41057	防御+100	5%
			   true ->
				   [31216,{10948,100,1000}]%% 变异玄武	41057	防御+100	5%
			end;
		_ ->
			if Player#player.sex == 1 ->
				   [31216,{10949,100,1000}];%% 变异玄武	41057	防御+100	5%
			   true ->
				   [31216,{10950,100,1000}]%% 变异玄武	41057	防御+100	5%
			end
	end.

%%根据ID获取名字
get_turned_name(MonId) ->
	Name = 
	case MonId of
		20128 ->
			"中心城护城护卫";
		20248 ->
			"神坛右护法";
		20247 ->
			"神坛左护法";
		20229 ->
			"守墓神使";
		20910 ->
			"试炼女神";
		20203 ->
			"氏族领地管理员";
		20202 ->
			"林镖头";
		41056 ->
			"瑶池圣母";
		41040 ->
			"蚩尤";
		41030 ->
			"河伯";
		41020 ->
			"狐小小";
		41010 ->
			"雷公";
		42015 ->
			"穷奇巨兽";
		42013 ->
			"赤尾狐";
		42011 ->
			"千年猴妖";
		42009 ->
			"裂地斧魔";
		41061 ->
			"变异麒麟";
		41060 ->
			"变异白虎";
		41059 ->
			"变异朱雀";
		41058 ->
			"变异青龙";
		41057 ->
			"变异玄武";
		28047 ->
			"圣诞雪人";
		_ ->
			""	  
	end,
	Name.
		
%%根据模型ID取变身数据
get_turned_buff_id(Mon_id) ->
	AllData = [{41057,{1000,100,1000}},{41058,{1001,100,1000}},{41059,{1002,100,1000}},{41060,{1003,100,1000}},{41061,{1004,100,1000}},{42009,{1005,20,1001}},
			   {42011,{1006,30,1001}},{42013,{1007,40,1001}},{42015,{1008,50,1001}},{41010,{1009,50,1002}},{41020,{1010,20,1003}},{41030,{1011,10,1004}},
			   {41040,{1012,30,1005}},{41056,{1013,50,1005}},{20202,{1014,500,1006}},{20203,{1015,500,1006}},{20910,{1016,500,1006}},{20229,{1017,500,1006}},
			   {20910,{1018,500,1006}},{20229,{1017,500,1006}},{20910,{1018,500,1006}},{20229,{1017,500,1006}},{20247,{1018,1000,1006}},{20248,{1019,1000,1006}},{20128,{1020,1000,1006}},
			   {28047,{40107,100,1000}}],	
	lists:keyfind(Mon_id, 1, AllData).	

get_chr_snow_buff_id(Mon_id) ->
	AllData = [{28047,{40107,100,1000}}],	
	lists:keyfind(Mon_id, 1, AllData).	

%%根据模型ID取变身数据
get_chr_turned_buff_id(_Mon_id,Career,Sex) ->
	_AllData = [
			   {31216,{10941,10000,1000}},{31216,{10942,10000,1000}},{31216,{10943,10000,1000}},{10944,{10944,10000,1000}},{10945,{10945,10000,1000}},
			   {31216,{10946,10000,1000}},{31216,{10947,10000,1000}},{31216,{10948,10000,1000}},{10949,{10949,10000,1000}},{10950,{10950,10000,1000}}],	
	if 
		Career == 1 ->
			if Sex == 1 ->
				   {31216,{10941,10000,1000}};
			   true ->
				   {31216,{10942,10000,1000}}
			end;
		Career == 2 ->
			if Sex == 1 ->
				   {31216,{10943,10000,1000}};
			   true ->
				   {31216,{10944,10000,1000}}
			end;
		Career == 3 ->
			if Sex == 1 ->
				   {31216,{10945,10000,1000}};
			   true ->
				   {31216,{10946,10000,1000}}
			end;
		Career == 4 ->
			if Sex == 1 ->
				   {31216,{10947,10000,1000}};
			   true ->
				   {31216,{10948,10000,1000}}
			end;
		true ->
			if Sex == 1 ->
				   {31216,{10949,10000,1000}};
			   true ->
				   {31216,{10950,10000,1000}}
			end
	end.
         		   
%%部落对应的颜色
get_realm_color(_Realm)->
	"#FFCF00". %%女娲

parse_fst_shop_goods_data([],Acc)->
	Acc;

parse_fst_shop_goods_data([D|Data],Acc)->
	case D of
		[busi,Price,Limit] ->
			[busi,Price,Limit]++Acc;
		_->
			parse_fst_shop_goods_data(Data,Acc)
	end.

%%神秘商店
get_rand_goods(Loc,N,Got,[ShopType,ShopSubtype]) ->
	case length(Got) =:= N of
		true ->	
			%%幸运大转盘，一定出现
			NewGot = [28750 | Got],
			lists:foldl(fun(Gid,Acc)->
						case ets:lookup(?ETS_BASE_GOODS, Gid) of
							[]->
								Acc;
							[G|_Rets] ->
								DataList = goods_util:parse_goods_other_data(G#ets_base_goods.other_data),
								if
										length(DataList) > 0 ->
											Data = parse_fst_shop_goods_data(DataList,[]),
											case Data of
												[busi,_Cost,LimitBuy] ->
													Ms = ets:fun2ms(fun(S) when S#ets_shop.shop_type=:=ShopType andalso S#ets_shop.shop_subtype=:=ShopSubtype
															  andalso S#ets_shop.goods_id=:=Gid -> S end),
													case ets:select(?ETS_BASE_SHOP,Ms) of
														[] ->
															Acc;
														_ ->
															[{Gid,LimitBuy}|Acc]
													end;
												_->
													Acc
											end;
										true ->
											Acc
								end
						end end, [], NewGot);
		false ->
			Rnd =  util:rand(1,100),
			Gid =
				case Loc of
%% 6~7
%% 21100	低阶锋芒灵石	5	2	3	10.00%
%% 21200	低阶坚韧灵石	3	1	3	10.00%
%% 28800	一级宝石袋	30	25	5	5.00%
%% 20500	4级强化保护符	10	8	5	15.00%
%% 20100	初级合成符	30	25	5	10.00%
%% 20200	初级镶嵌符	10	8	5	10.00%
%% 28002	高级铜币卡	10	8	9	10.00%
%% 21022	金色附魔石	4	3	9	20.00%
%% 21401	中级打孔石	20	5	3	10.00%

					6 ->
						if Rnd =< 10 ->
							   21100;
						   Rnd =< 20 ->
							   21200;
						   Rnd =< 25 ->
							   28800;
						   Rnd =< 40 ->
							   20500;
						   Rnd =< 50 ->
							   20100;
						   Rnd =< 60 ->
							   20200;
						   Rnd =< 70 ->
							   28002;
						   Rnd =< 90 ->
							   21022;
						   Rnd =< 100 ->
							   21401;
						   true ->
							   21100
						end;
%% 	12-13层	28800	一级宝石袋	30	25	9	10.00%	
%% 	20500	4级强化保护符	10	8	9	20.00%	
%% 	20100	初级合成符	30	25	5	20.00%	
%% 	20200	初级镶嵌符	10	8	5	10.00%	
%% 	28002	高级铜币卡	10	8	9	10.00%	
%% 	21022	金色附魔石	4	3	9	20.00%	
%% 	21401	中级打孔石	20	5	3	10.00%	100.00%
					12 ->
						if Rnd =< 10 ->
							   28800;
						   Rnd =< 30 ->
							   20500;
						   Rnd =< 50 ->
							   20100;
						   Rnd =< 60 ->
							   20200;
						   Rnd =< 70 ->
							   28002;
						   Rnd =< 90 ->
							   21022;
						   Rnd =< 100 ->
							   21401;
						   true ->
							   21100
						end;
%% 18-19层	28800	一级宝石袋	30	25	9	10.00%	
%% 	20501	5级强化保护符	40	30	3	10.00%	
%% 	20100	初级合成符	30	25	5	10.00%	
%% 	20201	中级镶嵌符	30	25	3	10.00%	
%% 	28002	高级铜币卡	10	8	9	10.00%	
%% 	21022	金色附魔石	4	3	9	20.00%	
%% 	21401	中级打孔石	20	5	3	5.00%	
%% 	21101	中阶锋芒灵石	30	24	3	10.00%	
%% 	21201	中阶坚韧灵石	20	16	9	10.00%	
%% 	21801	金色洗练石	88	68	2	5.00%	100.00%

					18 ->
						if Rnd =< 10 ->
							   28800;
						   Rnd =< 20 ->
							   20501;
						   Rnd =< 30 ->
							   20100;
						   Rnd =< 40 ->
							   20201;
						   Rnd =< 50 ->
							   28002;
						   Rnd =< 70 ->
							   21022;
						   Rnd =< 75 ->
							   21401;
						   Rnd =< 85 ->
							   21101;
						   Rnd =< 95 ->
							   21201;
						   Rnd =< 100 ->
							   21801;
						   true ->
							   21100
						end;

%%  24-25层					
%%	28801	二级宝石袋	120	96	3	5.00%
%% 	20501	5级强化保护符40	30	3	10.00%
%% 	20100	初级合成符	30	25	5	10.00%
%% 	20201	中级镶嵌符	30	25	3	10.00%
%% 	28002	高级铜币卡	10	8	9	10.00%
%% 	21402	高级打孔石	30	24	5	10.00%
%% 	21023	紫色附魔石	38	28	5	15.00%
%% 	21101	中阶锋芒灵石	30	24	3	10.00%
%% 	21201	中阶坚韧灵石	20	16	9	10.00%
%% 	21801	金色洗练石	88	68	2	10.00%


					24 ->
						if Rnd =< 5 ->
							   28801;
						   Rnd =< 15 ->
							   20501;
						   Rnd =< 25 ->
							   20100;
						   Rnd =< 35 ->
							   20201;
						   Rnd =< 45 ->
							   28002;
						   Rnd =< 55 ->
							   21402;
						   Rnd =< 70 ->
							   21101;
						   Rnd =< 80 ->
							   21023;
						   Rnd =< 90 ->
							   21201;
						   Rnd =< 100 ->
							   21801;
						   true ->
							   21801
						end
				end,
			%%不重复
			case lists:member(Gid, Got) of
				true ->
					get_rand_goods(Loc,N,Got,[ShopType,ShopSubtype]);
				false ->
					get_rand_goods(Loc,N,[Gid|Got],[ShopType,ShopSubtype])
			end
	end.
