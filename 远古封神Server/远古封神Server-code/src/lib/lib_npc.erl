%%%-----------------------------------
%%% @Module  : lib_npc
%%% @Author  : ygzj
%%% @Created : 2010.10.06
%%% @Description: npc
%%%-----------------------------------
-module(lib_npc).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-export(
    [
	 	init_base_npc/0,
		init_base_talk/0,
		init_base_map/0,
        get_name_by_npc_id/1,
        get_data/1,
        get_scene_by_npc_id/1,
       	get_npc/2,		
        get_unique_id/2,
		get_scene_by_realm_id/1
    ]
).

%%初始化基础Npc
init_base_npc() ->
    F = fun(Npc) ->
			D = list_to_tuple([ets_npc|Npc]),
			NpcInfo = D#ets_npc{
						icon = util:string_to_term(tool:to_list(D#ets_npc.icon)),
 						talk = util:string_to_term(tool:to_list(D#ets_npc.talk))
						},			
            ets:insert(?ETS_BASE_NPC, NpcInfo)
           end,
	L = db_agent:get_base_npc(),
	lists:foreach(F, L),
	ok.
	
%%初始化基础对话
init_base_talk() ->
    F = fun(Talk) ->
			D = list_to_tuple([talk|Talk]),			
			TalkInfo = D#talk{content=data_agent:convert_talk(D#talk.content)},
           	ets:insert(?ETS_BASE_TALK, TalkInfo)
           end,
	L = db_agent:get_base_talk(),
	lists:foreach(F, L),
    ok.

%%初始化场景分类
init_base_map()->
	F = fun(Scene) ->
			SceneInfo = list_to_tuple([talk|Scene]),
           	ets:insert(?ETS_BASE_MAP, SceneInfo)
           end,
	L = db_agent:get_base_map(),
	lists:foreach(F, L),
    ok.

%% 获取npc名称用npc数据库id
get_name_by_npc_id(NpcId)->
    case data_agent:npc_get(NpcId) of
        [] -> <<"">>;
        Npc -> Npc#ets_npc.name
    end.

%% 获取信息
get_data(NpcId) ->
    case data_agent:npc_get(NpcId) of
        [] -> ok;
        Npc -> Npc
    end.

%%获取一个NPC
get_npc(NpcUniqueId, SceneId) ->
   	MS = ets:fun2ms(fun(T) when T#ets_npc.id == NpcUniqueId, T#ets_npc.scene == SceneId andalso T#ets_npc.scene /= 99992 -> T end),
   	case ets:select(?ETS_SCENE_NPC, MS)	of
      		[] -> [];
        	[H|_] -> [H] 
    end.

%% 获取当前场景某类NPC信息 
get_scene_by_npc_id(NpcId) ->
   	MS = ets:fun2ms(fun(T) when T#ets_npc.nid == NpcId andalso T#ets_npc.scene /= 99992 -> 
			[
            T#ets_npc.scene,
            T#ets_npc.x,
            T#ets_npc.y		 
			] 
			end),
   	case ets:select(?ETS_BASE_SCENE_NPC, MS)	of
      		[] -> [];
			Info -> 
				Info
%%         	[[Scene, X, Y]|_] -> 
%% 				[Scene, X, Y] 
    end.

%% 获得NPC唯一id
get_unique_id(NpcId, SceneId) ->
    case ets:match(?ETS_SCENE_NPC, #ets_npc{id ='$1', nid = NpcId, scene = SceneId,  _ = '_'}) of
        [] -> 0;
        [[Id]|_] -> Id
    end.

get_scene_by_realm_id(Realm)->
	MS = ets:fun2ms(fun(T) when T#ets_base_map.realm == Realm orelse T#ets_base_map.realm == 0 ->  
			[
            T#ets_base_map.scene_id	 
			] 
			end),
   	case ets:select(?ETS_BASE_MAP, MS)	of
      		[] -> [];
			Info -> 
				Info
    end.
