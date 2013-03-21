%% Author: xiaomai
%% Created: 2011-3-1
%% Description: TODO: 诛邪副本的处理接口
-module(lib_box_scene).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%%
%% Exported Functions
%%
-export([
		 get_box_scene_id/1,	 
		 get_box_scene_unique_id/1,
		 get_box_scene_unique_id_xy/1,
		 handle_box_scene/2,
		 build_box_scene/5,
		 is_box_scene_idsp/2,
		 is_box_scene_idsp_for_team/2,
		 is_box_scene_ids/1,
		 is_box_scene_ids_init/1,%%此方法只允许玩家登陆的时候场景初始化使用，其他情况请使用上面的方法，谨记！
		 get_box_scene/1,
		 get_box_scene_ets/1,
%% 		 update_box_scene_ets/1,
		 insert_box_scene_ets/1,
		 delete_box_scene_ets/1,
		 get_goods_type/1,
		 get_error_type/1,
		 get_spar_coord/1,
		 put_data_into_box_ets/1,
		 time_check/1,
		 broad_scene_goods/3,
		 get_open_box_info/1,
		 set_open_box_info/2,
		 handle_mon_and_goods/1%%此方法仅export，不提供对外调用（待定）
		]).

%%
%% API Functions
%%

%%获取诛邪副本的原始场景ID
get_box_scene_id(UniqueSceneId) ->
	UniqueSceneId rem 10000.
%% %%生成诛邪副本的场景唯一ID
get_box_scene_unique_id(SceneId) ->
	case ?DB_MODULE of
		db_mysql ->
			gen_server:call(mod_auto_id:get_autoid_pid(), {dungeon_auto_id, SceneId});
		_ ->
			db_agent:get_unique_dungeon_id(SceneId)
	end.
get_box_scene_unique_id_xy(SceneId) ->
	UniqueSceneId = get_box_scene_unique_id(SceneId),
	[X, Y] = get_box_scene_xy(),
	{UniqueSceneId, X, Y}.

%% get_box_scene_unique_id(PlayerId) ->
%% 	?BOX_SCENE_ID + PlayerId * ?BOX_SCENE_BASE_ID.
%% get_playerid_by_sceneid(SceneId) ->
%% 	tool:ceil((SceneId - ?BOX_SCENE_ID) / ?BOX_SCENE_BASE_ID).

put_data_into_box_ets(PlayerId) ->
	BoxSceneList = db_agent:get_box_scene(PlayerId),
	BoxScene0 = list_to_tuple([ets_box_scene] ++ BoxSceneList),
%% 	io:format("put_data\n"),
	BoxScene = BoxScene0#ets_box_scene{mlist = util:string_to_term(tool:to_list(BoxScene0#ets_box_scene.mlist)),
									   glist = util:string_to_term(tool:to_list(BoxScene0#ets_box_scene.glist))},
%% 	io:format("-----------------------------------------PlayerId:~p\n", [BoxScene#ets_box_scene.player_id]),	
	insert_box_scene_ets(BoxScene).

handle_box_scene(Player, GoodsTypeId) ->
	case db_agent:get_box_scene(Player#player.id) of
		[] ->
			BoxScene = #ets_box_scene{player_id = Player#player.id,
									  scene = Player#player.scene, 
									  x = Player#player.x, 
									  y = Player#player.y,
									  goods_id = GoodsTypeId},
%% 			io:format("lib handle box scene 11..\n"),
			db_agent:insert_box_scene(BoxScene),
%% 			io:format("-----------------------------------------PlayerId:~p\n", [BoxScene#ets_box_scene.player_id]),
			insert_box_scene_ets(BoxScene);
		OldBoxSceneList ->
			OldBoxScene = list_to_tuple([ets_box_scene] ++ OldBoxSceneList),
			BoxScene = OldBoxScene#ets_box_scene{player_id = Player#player.id,
												 scene = Player#player.scene, 
												 x = Player#player.x, 
												 y = Player#player.y,
												 goods_id = GoodsTypeId},
%% 			io:format("lib handle box scene 22..\n"),
			ValueList = [{scene, Player#player.scene}, {x, Player#player.x}, {y, Player#player.y}, {goods_id, GoodsTypeId}],
			db_agent:update_box_scene(ValueList, Player#player.id),
%% 			io:format("-----------------------------------------PlayerId:~p\n", [BoxScene#ets_box_scene.player_id]),
			insert_box_scene_ets(BoxScene)
	end.
			  
%%初始化玩家的诛邪副本
build_box_scene(UniqueSceneId, SceneId, Player, BuildType, GoodsType) ->
	init_box_scene(UniqueSceneId, SceneId, Player, BuildType, GoodsType).

init_box_scene(UniqueSceneId, SceneId, Player, BuildType, GoodsType) ->
%% 	io:format("init box scene 111\n"),
	[X, Y] = get_box_scene_xy(),
%% 	io:format("init box scene 222\n"),
	case data_scene:get(SceneId) of
		[] ->
%% 			io:format("fail-->111\n"),
			fail;
		S ->
%% 			lib_scene:copy_scene(UniqueSceneId, ?BOX_SCENE_ID),
%% 			MonList = S#ets_scene.mon,
			case handle_box_scene_goods(Player, GoodsType, BuildType) of
				{fail, _Error} ->
%% 					io:format("fail-->2222\n"),
					fail;
				{ok, GoodsList} ->
					case get_box_scene_ets(Player#player.id) of
						[] ->
							fail;
						[OldBoxScene|_] ->
%% 							OldBoxScene = list_to_tuple([ets_box_scene] ++ OldBoxSceneList),
%% 							io:format("ok --->~p, build type:~p\n", [Player#player.id, BuildType]),
							case BuildType of
								{0, _Param} ->
									lib_scene:copy_scene(UniqueSceneId, SceneId),
									Num = OldBoxScene#ets_box_scene.num + 1,
									MonList = box_mon_to_ets([], S#ets_scene.mon),
									MList = util:term_to_string(MonList),
									GList = util:term_to_string(GoodsList),
									BoxScene = OldBoxScene#ets_box_scene{player_id = Player#player.id,
																		  mlist = MonList, 
																		 glist = GoodsList,
																		 num = Num},
									ValueList = [{mlist, MList}, {glist, GList}, {num, Num}],
									db_agent:update_box_scene(ValueList, Player#player.id),
%% 									io:format("-----------------------------------------PlayerId:~p\n", [BoxScene#ets_box_scene.player_id]),
									insert_box_scene_ets(BoxScene);
								_ ->
									Num = OldBoxScene#ets_box_scene.num,
									copy_scene(UniqueSceneId, OldBoxScene, S)
							end,
%% 							NewPlayer = Player#player{other = Player#player.other#player_other{pid_scene = self()}},
%% 							lib_player:save_online(NewPlayer),
							{S#ets_scene.name, UniqueSceneId, X, Y, Num}
					end
			end
	end.

copy_scene(UniqueSceneId, OldBoxScene, S) ->
%% 	io:format("copy scene start ~p,,,,~p\n", [S#ets_scene.npc, UniqueSceneId]),
	lib_scene:load_npc(S#ets_scene.npc, UniqueSceneId),
%% 	io:format("copy scene start 1111\n"),
	Mlist = box_ets_to_mon([], tool:to_list(OldBoxScene#ets_box_scene.mlist)),
%% 	io:format("copy scene start 22222\n"),
	lib_scene:load_mon(Mlist, UniqueSceneId),
%% 	io:format("copy scene\n"),
	ets:insert(?ETS_SCENE, S#ets_scene{id = UniqueSceneId, mon=[], npc=[], mask=[]}).

%%判断是否为诛邪副本 			
is_box_scene_idsp(SceneId, _PlayerId) ->
	BoxSceneId = get_box_scene_id(SceneId),
	BoxSceneId =:= ?BOX_SCENE_ID orelse BoxSceneId =:= ?BOXS_PIECE_ID.

%%判断是否为诛邪副本 			
is_box_scene_idsp_for_team(SceneId, PlayerId) ->
	case is_box_scene_idsp(SceneId, PlayerId) of
		true ->
 			true;
        false ->
			SceneId =:= ?BOX_SCENE_ONE_ID
	end.
   
is_box_scene_ids(SceneId) ->
	BoxSceneId = SceneId rem 1000,
	BoxSceneId =:= ?BOX_SCENE_ID orelse BoxSceneId =:= ?BOXS_PIECE_ID.

%% 此方法只允许玩家登陆的时候场景初始化使用，其他情况请使用上面的方法，谨记！
is_box_scene_ids_init(SceneId) ->
	case SceneId rem 1000 of
		?BOX_SCENE_ID ->
			case ets:lookup(?ETS_BASE_SCENE, ?BOX_SCENE_ID) of
				[] -> false;
				[S] -> {S#ets_scene.type =:= 8, ?BOX_SCENE_ID}
			end;
		?BOXS_PIECE_ID ->
			case ets:lookup(?ETS_BASE_SCENE, ?BOX_SCENE_ID) of
				[] -> false;
				[S] -> {S#ets_scene.type =:= 8, ?BOXS_PIECE_ID}
			end;
		_ ->
			false
	end.

%%由秘境令得出产生物品的类型
get_goods_type(GoodsTypeId) ->
	case GoodsTypeId of
		28028 ->
			1;
		28029 ->
			2;
		28030 ->
			3
	end.
%%给予物品时的错误码判断
get_error_type(Error) ->
	case Error of
		cell_num ->%%背包不足
			2;
		_ ->
			0
	end.

%%获取水晶信息
get_spar_coord(SparId) ->
	SparInfo = get_goods_coords(),
	case SparId >= 1 andalso SparId =< 20 of
		true ->
			{value, {NewSparId, X, Y}} = lists:keysearch(SparId, 1, SparInfo);
		false ->
			{NewSparId, X, Y} = {SparId, 0, 0}
	end,
	{NewSparId, X, Y}.

box_mon_to_ets(MList, []) ->
	MList;
box_mon_to_ets(MList, [[Id, X, Y, Lv]|MonList]) ->
	Mon = #ets_box_mon{mon_id = Id,
					   coord = {X, Y},
					   lv = Lv},
	box_mon_to_ets([Mon|MList], MonList).
box_ets_to_mon(MList, []) ->
	MList;
box_ets_to_mon(MList, [Mon|MonList]) ->
	#ets_box_mon{mon_id = Id,
				 coord = Coord,
				 lv = Lv} = Mon,
	{X, Y} = Coord,
	box_ets_to_mon([[Id, X, Y, Lv] | MList], MonList).

%%使用次数判断
time_check(Player) ->
	IsBoxScene = is_box_scene_idsp_for_team(Player#player.scene, Player#player.id),
	case IsBoxScene of
		false ->%%
	case is_pid(Player#player.other#player_other.pid_team) of
		true ->
			{fail, 25};
		false ->
			case lib_deliver:could_deliver(Player) of
				10 -> {fail, 29};
				11 -> {fail, 27};
				13 -> {fail, 29};
				14 -> {fail, 28};
				15 -> {fail, 29};
				16 -> {fail, 29};
				21 -> {fail, 29};
				22 -> {fail, 29};
				31 -> {fail, 26};
				32 -> {fail, 26};
				33 -> {fail, 26};
				34 -> {fail, 26};
				35 -> {fail, 26};
				38 -> {fail,26};
				_ ->
					ok
			end
	end;
		true ->%%在秘境里
			{fail, 26}
	end.


%%
%% Local Functions
%%	
%%处理诛邪副本的怪物和水晶
handle_mon_and_goods(_Mon) ->
	MonList = [],
	GoodsList = [],
	{MonList, GoodsList}.
insert_box_scene_ets(BoxScene) ->
	ets:insert(?ETS_BOX_SCENE, BoxScene).
%% update_box_scene_ets(BoxScene) ->
%% 	ets:insert(?ETS_BOX_SCENE, BoxScene).
delete_box_scene_ets(PlayerId) ->
	ets:delete(?ETS_BOX_SCENE, PlayerId).
get_box_scene_ets(PlayerId) ->
	ets:lookup(?ETS_BOX_SCENE, PlayerId).
get_box_scene(PlayerId) ->
	case get_box_scene_ets(PlayerId) of
		[] ->
			BoxScene = db_agent:get_box_scene(PlayerId),
			BoxSceneEts0 = list_to_tuple([ets_box_scene] ++ BoxScene),
			BoxSceneEts = BoxSceneEts0#ets_box_scene{player_id = PlayerId,
													 mlist = tool:to_list(BoxSceneEts0#ets_box_scene.mlist),
													 glist = tool:to_list(BoxSceneEts0#ets_box_scene.glist)},
%% 			io:format("-----------------------------------------PlayerId:~p\n", [BoxSceneEts#ets_box_scene.player_id]),
			insert_box_scene_ets(BoxSceneEts),
			BoxSceneEts;
		[BoxSceneEts|_] ->
			BoxSceneEts
	end.

%%获取诛邪副本的xy
get_box_scene_xy() ->
	[100, 21].
handle_box_scene_goods(Status, Type, BuildType) ->
%% 	io:format("handle box scene goods\n"),
	case BuildType of
		{0, ParamInit} ->
			{PurpleEList, PlayerPurpleNum, OpenCounter, PurpleTimeType, GoodsTraceInit} = ParamInit,
			{0, PupleETList} = PurpleEList,
%% 			io:format("get info:~p\n", [{PurpleEList, PlayerPurpleNum, OpenCounter, PurpleTimeType, GoodsTraceInit}]),
			[ResultType, Param] = 
				mod_box:open_box(Status, GoodsTraceInit, OpenCounter, PlayerPurpleNum, PurpleTimeType, Type, 4, PurpleEList, 2),
			case ResultType of
				ok ->
%% 			io:format("handle box scene goods11111\n"),
					{_OpenCount, _HoleType, _OpenType, GoodsNumList, NewOpenBoxCount, NewPurpleNum, BoxGoodsTrace, NewPurpleEList} = Param,
					send_set_open_box_info(Status, {BoxGoodsTrace, NewPurpleNum, PlayerPurpleNum, NewOpenBoxCount, NewPurpleEList, PupleETList}),
					handle_goods_list(GoodsNumList, Type);
				fail ->
%% 					io:format("handle box scene goods2222\n"),
					{fail, []}
			end;
		_ ->
%% 			io:format("handle box scene goods3333\n"),
			{ok, []}
	end.
			
handle_goods_list(GoodsNumList, Type) ->
	CoordList = get_goods_coords(),
	MergeGoodsList = merge_goods([], GoodsNumList),
	split_box_goods([],CoordList, MergeGoodsList, 20, Type).

split_box_goods(GList, [], [], 0, _Type) ->
	{ok, GList};
split_box_goods(GList, [], [], Num, _Type) when Num =/= 0->
	{fail, GList};
split_box_goods(GList, CoordList, MergeGoodsList, 0, _Type) when length(CoordList) =/= 0 orelse length(MergeGoodsList) =/= 0 ->
	{fail, GList};
split_box_goods(GList, _CoordList, _MergeGoodsList, Num, _Type) when Num =< 0 ->
	{fail, GList};
split_box_goods(GList, [{Id, X, Y}|CoordList], [GoodsId|MergeGoodsList], Num, Type)->
	Spar = #ets_spar{
					 spar_id = Id,
					 x = X,
					 y = Y,
					 type = Type,
					 goods_id = GoodsId},
	split_box_goods([Spar|GList], CoordList, MergeGoodsList, Num-1, Type).

%%获取水晶的坐标{编号ID, X, Y}
get_goods_coords() ->
	[{1, 29, 14}, {2, 25, 21}, {3, 22, 24}, {4, 23, 26}, {5, 22, 28},
	 {6, 21, 29}, {7, 12, 20}, {8, 18, 29}, {9, 17, 28}, {10, 16, 28},
	 {11, 16, 25}, {12, 17, 23}, {13, 18, 22}, {14, 14, 22}, {15, 13, 21},
	 {16, 11, 18}, {17, 10, 16}, {18, 9, 14}, {19, 11, 13}, {20, 7, 16}].

merge_goods(GoodsList, []) ->
	GoodsList;
merge_goods(GoodsList, [{GoodsTypeId, GoodsNum} | GoodsNumList]) ->
	case GoodsNum > 1 of
		true ->
			NewGoodsNum = GoodsNum - 1,
			NewGoodsNumList = [{GoodsTypeId, NewGoodsNum} | GoodsNumList];
		false ->
			NewGoodsNumList = GoodsNumList
	end,
	merge_goods([GoodsTypeId | GoodsList], NewGoodsNumList).

%%
broad_scene_goods(GoodsTypeId, Player, SceneType) ->
	EtsBoxGoodsType = mod_box:get_ets_boxgoods_type(),
	GoodsTypeInfo =  goods_util:get_goods_type(GoodsTypeId),
	case is_record(GoodsTypeInfo, ets_base_goods) =:= false of
		true ->
%% 			io:format("1111\n"),
			skip;
		false ->
			case lib_box:get_box_goods_ets(EtsBoxGoodsType, SceneType, GoodsTypeId) of
				[] ->
%% 					io:format("2222\n"),
					skip;
				[BoxGoods] ->
					ShowType = BoxGoods#ets_base_box_goods.show_type,
					%%添加日志
					add_box_scene_goods_log(GoodsTypeInfo, ShowType, SceneType, Player),
					case ShowType of
						1 ->
%% 							io:format("444\n"),
							#player{id = PlayerId,
									realm = Realm,
									nickname = PlayerName,
									career = Career,
									sex = Sex} = Player,
							BoxSceneType = get_box_scene_type(SceneType),
							Country = lib_player:get_country(Realm),
							Color = GoodsTypeInfo#ets_base_goods.color,
							ColorContent = goods_util:get_color_hex_value(Color),
							NameColor = data_agent:get_realm_color(Realm),
							Gid = 
								case Color =:= 4 of
									true ->%紫装
										Pattern = #goods{player_id = PlayerId, goods_id= GoodsTypeId, _ ='_'},
										NumList = goods_util:get_ets_list(?ETS_GOODS_ONLINE, Pattern),
										NewGoods = lists:max(NumList),
										NewGoods#goods.id;
									false -> %%一般的东西
										Pattern = #goods{player_id = PlayerId, goods_id= GoodsTypeId, _ ='_'},
										NumList = goods_util:get_ets_list(?ETS_GOODS_ONLINE, Pattern),
										NewGoods = lists:nth(1, NumList),
										NewGoods#goods.id
								end,
%% 							io:format("\n1111111111\n"),
							ConTent = io_lib:format("<font color='~s'>[~s]</font>的[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]人品大爆发，在~s中获得了<a href='event:2,~p,~p,1'><font color='~s'> <u> ~s </u> </font></a>宝物",
										  ["#FF0000",Country, PlayerId, PlayerName, Career, Sex, NameColor, PlayerName, BoxSceneType, Gid, PlayerId, ColorContent, GoodsTypeInfo#ets_base_goods.goods_name]),
							%%广播一下
%% 							io:format("broadcast the info\n"),
							lib_chat:broadcast_sys_msg(2, ConTent);
						_ ->
%% 							io:format("333\n"),
							skip
					end
			end
	end.
			
get_box_scene_type(SceneType) ->
	BoxSceneType = ["初级秘境", "中级秘境", "高级秘境"],
	Rest = lists:nth(SceneType, BoxSceneType),
	Rest.

%% send_get_open_box_info(Player) ->
%% 	io:format("SEND_GET_OPEN_BOX_INFO send~p,,~p \n", [self(), Player#player.other#player_other.pid]),
%% %% 	get_open_box_info(Player#player.id).
%% 	gen_server:call(Player#player.other#player_other.pid, {'SEND_GET_OPEN_BOX_INFO', Player#player.id}).

get_open_box_info(PlayerId) ->
	{PlayerPurpleNum, OpenCounter, PurpleTimeType, GoodsTraceInit} = lib_box:get_open_player_info(PlayerId),
	PupleETList = lib_box:get_purple_equip_list(),
	PurpleEList = {0, PupleETList},
	{PurpleEList, PlayerPurpleNum, OpenCounter, PurpleTimeType, GoodsTraceInit}.
	
%%{BoxGoodsTrace, NewPurpleNum, PlayerPurpleNum, NewOpenBoxCount, NewPurpleEList, PupleETList} = Param
send_set_open_box_info(Status, Param) ->
	gen_server:cast(Status#player.other#player_other.pid, {'SEND_SET_OPEN_BOX_INFO', Param}).
set_open_box_info(PlayerId, Param) ->
	{BoxGoodsTrace, NewPurpleNum, PlayerPurpleNum, NewOpenBoxCount, NewPurpleEList, PupleETList} = Param,
	lib_box:update_box_goods_trace(BoxGoodsTrace, NewPurpleNum, 
								   PlayerPurpleNum, NewOpenBoxCount, PlayerId),
	%%做紫装记录
	{NewPurpleGoods, _PurpleEListOld} = NewPurpleEList,
	lib_box:make_purple_equip_list_record(NewPurpleGoods, PupleETList).
%%添加秘境物品拾取的日志
add_box_scene_goods_log(GoodsTypeInfo, ShowType, HoleType, Player) ->
	#player{id = PlayerId,
			nickname = PlayerName} = Player,
	#ets_base_goods{goods_id = BaseGoodsId,
					goods_name = GoodsName} = GoodsTypeInfo,
	NowTime = util:unixtime(),
	Log_box_open = 
		#ets_log_box_open{
						  player_id = PlayerId,
						  player_name = PlayerName, 
						  hole_type = HoleType, 
						  goods_id = BaseGoodsId, 
						  goods_name = GoodsName, 
						  gid = 0, %%因为取不到GID，此处只能赋值0，表示秘境取所得
						  num = 1, 
						  show_type = ShowType,
						  open_time = NowTime
								 },
	spawn(fun()-> db_agent:insert_log_box_open(log_box_open, Log_box_open) end).
