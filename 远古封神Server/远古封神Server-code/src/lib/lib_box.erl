%% Author: xiaomai
%% Created: 2010-11-18
%% Description: 诛邪系统处理方法
-module(lib_box).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%%概率扩大的倍数
-define(BASE_BOX_GOODS_PRO, 100000).
-define(LOG_BOX_OPEN_NUM, 50).
-define(INCREASE_BOX_GOODS_PRO, 0.0034).%%计算出的基础概率
-define(PURPLE_EQUIP_LIST_TIMESTAMP, 1000*60).%%N milliseconds 后删除紫装的列表记录
-define(YG_HOLE_NUM_LIMIT, 3).				%%远古妖洞开出的紫装的数量限制

%%诛邪系统中使用到的物品统计函数的传入参数，
%% method:open_box_count/1, 
%% Param:open_box_count_param
-record(open_box_count_param,{
							  player_id,			%%玩家Id
							  ets_box_goods_type,	%%当前box的ets是处于哪一份表的数据,1or2
							  purple_num,			%%当前已经开出的紫装数量
							  pro_list,				%%当前的诛邪概率表
							  pro_list_spec = [],	%%当前需要特殊诛邪概率表，如1~400次内的概率变化
							  pro_type = 0,			%%标注使用哪一套概率，0时使用pro_list，1时使用pro_list_spec
							  hole_type,			%%诛邪妖洞类型
							  open_type,			%%诛邪的次数类型
							  career,				%%玩家的职业
							  open_count,			%%当前已经开诛邪的次数
							  open_box_counter,		%%记录当天开的诛邪中有数量限制的物品到目前为止已经开出的数量
							  result_count = [],	%%开出的物品列表
							  player_purple_num,	%%当前开出的紫装数量, %%在400次之前开出紫装的数量，数量达到2之后不再累加
							  purple_time_type,		%%是否做20秒的紫装限制
							  spec_count_type = 0,	%%标注是否需要出紫装
							  box_goods_trace,		%%返回需要更新有熟练限制的物品的数据
							  yg_hole = 0			%%开诛邪是远古妖洞时，开出的紫装数量
							 }).

%%
%% Exported Functions
%%
-export([load_all_box/1,
		 load_all_box_log/0,
		 list_server_box_logs/0,			%%	28001  获取全服开宝箱记录
		 open_box/15,						%%	28002  开宝箱
%% 		 get_warehouse/2,					%%  28003  获取诛邪仓库数据
%% 		 put_goods_into_bag/4,				%%  28004  将物品放入背包
%% 		 discard_box_goods/4,				%%  28005  将物品丢弃(单个)
%% 		 discard_all_box_goods/2,			%%  28006  丢弃仓库中的所有物品
%% 		 put_all_goods_into_bag/2,			%%  28007  将所有物品放入背包
%% 		 get_box_remain_cells/1,			%%  28008  获取仓库的容量
%% 		 handle_warehouse/1,
%% 		 handle_each_box_goods_result/1,
		 handle_each_box_goods/6,
		 add_box_goods_group/2,
		 get_box_goods/1,
		 check_delete_boxgoods/3,
		 delete_box_goods/2,
		 delete_all_box_goods/2,
		 goods_box_to_bag/3,
		 load_all_box_goods_pro/1,
		 mod_box_handle_update_action/2,
		 mod_box_log_handle_update_action/0,
		 get_open_box_goldneeded/2,
		 get_all_box_goodstobag_needed/1,
		 handle_box_system_msg/9,
		 lib_box_goods_log_local/1,
		 check_outtime/1,
		 put_box_purple_time/1,
		 get_box_purple_time/0,
		 put_box_open_counter/1,
		 get_box_open_counter/0,
		 put_box_purple_num/1,
		 get_box_purple_num/0,
		 put_box_goods_trace/1,
		 get_box_goods_trace/0,
		 put_open_box_goods_type/1,
		 get_open_box_goods_type/0,
		 get_purple_equip_list/0,
		 put_purple_equip_list/1,
		 delete_purple_equip_list_record/1,
		 make_purple_equip_list_record/2,
		 init_log_box_player/1,
		 delete_box_player/1,
		 get_player_box_goods/1,
		 init_box_goods_player_info/3,
		 get_open_player_info/1,
		 update_box_goods_trace/5,
		 handle_box_goods_trace_result_a/4,
		 handle_box_goods_trace_result_b/5,
		 get_box_goods_ets/3,
		 delete_box_goods_log/3,
		 delete_all_box_goods_log/2,
		 set_OpenCount/1
		]).

%%
%% API Functions
%%
%% -----------------------------------------------------------------
%% 初始化诛邪....
%% -----------------------------------------------------------------
load_all_box(EtsBoxGoodsType) ->
	BoxGoodsGroup = db_agent:load_all_box(),
	lists:map(fun(BoxGoods)-> handle_each_box(EtsBoxGoodsType, BoxGoods) end, BoxGoodsGroup).
load_all_box_log() ->
	%%获取最近的0点时间
	LastZeroTime = check_outtime(0),
	WhereList = [{show_type, 1},{open_time, ">", LastZeroTime}],
	LogBoxOpenGroup = db_agent:load_log_box_open(log_box_open, WhereList),
	lists:map(fun handle_each_log_box_open/1, LogBoxOpenGroup).

handle_each_box(EtsBoxGoodsType, BoxGoods) ->
	BoxGoodsEts = list_to_tuple([ets_base_box_goods]++BoxGoods),
	ets_update_box_info(EtsBoxGoodsType, BoxGoodsEts).
handle_each_log_box_open(LogBoxOpen) ->
	LogBoxOpenEts = list_to_tuple([ets_log_box_open] ++ LogBoxOpen),
	ets_update_log_box_open(LogBoxOpenEts).

ets_update_box_info(EtsBoxGoodsType, BoxGoodsEts) ->
	case EtsBoxGoodsType of
		1 ->
	ets:insert(?ETS_BASE_BOX_GOODS_ONE, BoxGoodsEts);
		2 ->
			ets:insert(?ETS_BASE_BOX_GOODS_TWO, BoxGoodsEts)
	end.
			
ets_update_log_box_open(LogBoxOpenEts) ->
	ets:insert(?ETS_LOG_BOX_OPEN, LogBoxOpenEts).
get_box_goods_ets(EtsBoxGoodsType, HoleType, BaseGoodsId) ->
	Pattern = #ets_base_box_goods{hole_type = HoleType, goods_id = BaseGoodsId, _ = '_'},
	case EtsBoxGoodsType of
		1 ->
			ets:match_object(?ETS_BASE_BOX_GOODS_ONE, Pattern);
		2 ->
			ets:match_object(?ETS_BASE_BOX_GOODS_TWO, Pattern)
	end.

load_all_box_goods_pro(EtsBoxGoodsType) ->
	Counts = lists:seq(1,5),
	BoxStatus = #box_status{ets_box_goods_type = EtsBoxGoodsType},
	[NewBoxStatus] = lists:foldl(fun load_all_box_goods_pro_by_career/2,[BoxStatus], Counts),
	NewBoxStatus.
load_all_box_goods_pro_by_career(Career,AccIn) ->
	Sum = lists:seq(1,4),
	[BoxStatus] = AccIn,
	{NewAccIn,_Career} = lists:foldl(fun load_all_box_goods_pro_by_holetype/2, {BoxStatus, Career}, Sum),
	[NewAccIn].
load_all_box_goods_pro_by_holetype(HoleType, AccIn) ->
	{BoxStatus,Career} = AccIn,
	StatusElem = lists:concat([Career,HoleType]),
	NewResult = get_pro_list(BoxStatus#box_status.ets_box_goods_type, Career,HoleType),
%% 	NewResult = lists:reverse(Result),
	case StatusElem of
		"11" -> NewBoxStatus = BoxStatus#box_status{box_goods_11 = NewResult};
		"12" -> NewBoxStatus = BoxStatus#box_status{box_goods_12 = NewResult};
		"13" -> NewBoxStatus = BoxStatus#box_status{box_goods_13 = NewResult};
		"14" -> NewBoxStatus = BoxStatus#box_status{box_goods_14 = NewResult};
		"21" -> NewBoxStatus = BoxStatus#box_status{box_goods_21 = NewResult};
		"22" -> NewBoxStatus = BoxStatus#box_status{box_goods_22 = NewResult};
		"23" -> NewBoxStatus = BoxStatus#box_status{box_goods_23 = NewResult};
		"24" -> NewBoxStatus = BoxStatus#box_status{box_goods_24 = NewResult};
		"31" -> NewBoxStatus = BoxStatus#box_status{box_goods_31 = NewResult};
		"32" -> NewBoxStatus = BoxStatus#box_status{box_goods_32 = NewResult};
		"33" -> NewBoxStatus = BoxStatus#box_status{box_goods_33 = NewResult};
		"34" -> NewBoxStatus = BoxStatus#box_status{box_goods_34 = NewResult};
		"41" -> NewBoxStatus = BoxStatus#box_status{box_goods_41 = NewResult};
		"42" -> NewBoxStatus = BoxStatus#box_status{box_goods_42 = NewResult};
		"43" -> NewBoxStatus = BoxStatus#box_status{box_goods_43 = NewResult};
		"44" -> NewBoxStatus = BoxStatus#box_status{box_goods_44 = NewResult};
		"51" -> NewBoxStatus = BoxStatus#box_status{box_goods_51 = NewResult};
		"52" -> NewBoxStatus = BoxStatus#box_status{box_goods_52 = NewResult};
		"53" -> NewBoxStatus = BoxStatus#box_status{box_goods_53 = NewResult};
		"54" -> NewBoxStatus = BoxStatus#box_status{box_goods_54 = NewResult}
	end,
	{NewBoxStatus, Career}.

get_pro_list(EtsBoxGoodsType, Career, Holetype) ->
	ProHoleList = get_pro_goods_by_holetype(EtsBoxGoodsType, Holetype),
	{_Career, Lists} = lists:foldl(fun get_pro_goods/2, {Career, []}, ProHoleList),
	{_Count, Result} = lists:foldl(fun make_pro_list/2, {0, []}, Lists),
	lists:reverse(Result).

make_pro_list(Elem, AccIn) ->
	[Pro, BaseGoodsId] = Elem,
	{Count, Result} = AccIn,
	NewPro = Pro*?BASE_BOX_GOODS_PRO,
	NewProInt = tool:to_integer(NewPro),
	NewCount = Count + NewProInt,
	{NewCount, [{BaseGoodsId,NewCount}|Result]}.
	
get_pro_goods_by_holetype(EtsBoxGoodsType, HoleType) ->
	Pattern = #ets_base_box_goods{hole_type = HoleType, _ = '_'},
	case EtsBoxGoodsType of
		1 ->
			ets:match_object(?ETS_BASE_BOX_GOODS_ONE, Pattern);
		2 ->
			ets:match_object(?ETS_BASE_BOX_GOODS_TWO, Pattern)
	end.

get_pro_goods(BoxGoodsInfo, AccIn) ->
	{Career, GoodsList} = AccIn,
	#ets_base_box_goods{goods_id = BaseGoodsId,
						 pro = Pro}= BoxGoodsInfo,
	GoodsTypeInfo =  goods_util:get_goods_type(BaseGoodsId),
	if 
		is_record(GoodsTypeInfo, ets_base_goods) =:= false ->
			AccIn;
		true ->
			GoodsCareer = GoodsTypeInfo#ets_base_goods.career,
			case (GoodsCareer == 0 orelse GoodsCareer == Career) of
				true ->
					NewElem = [Pro, BaseGoodsId],
					{Career, [NewElem|GoodsList]};
				false ->
					AccIn
			end
	end.
%% -----------------------------------------------------------------
%% 28001 获取全服开宝箱记录
%% -----------------------------------------------------------------
list_server_box_logs() ->
	LogBoxOpenGroupInit = ets:tab2list(?ETS_LOG_BOX_OPEN),
	LogsLen = length(LogBoxOpenGroupInit),
	case  LogsLen > ?LOG_BOX_OPEN_NUM of
		true ->
			LogBoxOpenGroupSort = lists:sort(LogBoxOpenGroupInit),
			LogBoxOpenGroup = lists:sublist(LogBoxOpenGroupSort, LogsLen-?LOG_BOX_OPEN_NUM+1, ?LOG_BOX_OPEN_NUM);
		false ->
			LogBoxOpenGroup = LogBoxOpenGroupInit
	end,
	PackedLogBoxOpenGroup = lists:map(fun handle_list_each_box_logs/1, LogBoxOpenGroup),
	Len = length(PackedLogBoxOpenGroup),
	[Len, PackedLogBoxOpenGroup].
handle_list_each_box_logs(LogBoxOpen) ->
	#ets_log_box_open{id = LogId,
					  player_id = PlayerId,
					  player_name = PlayerName,
					  gid = GoodsId,
					  goods_id = BaseGoodsId, 
					  goods_name = GoodsName,
					  hole_type = HoleType
					  } = LogBoxOpen,
	PlayerNameBin = tool:to_binary(PlayerName),
	GoodsNameBin = tool:to_binary(GoodsName),
	PlayerNameLen = byte_size(PlayerNameBin),
	GoodsNameLen = byte_size(GoodsNameBin),
	<<LogId:32, PlayerId:32, GoodsId:32, BaseGoodsId:32, HoleType:16, PlayerNameLen:16,PlayerNameBin/binary,GoodsNameLen:16, GoodsNameBin/binary>>.

%% -----------------------------------------------------------------
%% 28002 开宝箱 Proto：1，直接开诛邪；2，副本秘境
%% -----------------------------------------------------------------
open_box(EtsBoxGoodsType, PlayerId, Gold, _GoodsPid, _PlayerPid, Career, BoxGoodsTrace, 
		 OpenCounter, PlayerPurpleNum, PurpleTimeType, HoleType, OpenType, ProList, PurpleEList, Proto) ->
	if HoleType < 1 orelse HoleType > 4 ->
		   [fail, {0, 0, [], HoleType}];
	   OpenType < 1 orelse OpenType > 4 ->
		   [fail, {0, 0, [], HoleType}];
	   true ->
		   GoldNeeded = get_open_box_goldneeded(HoleType, OpenType),
		   %%诛邪次数,4表示秘境
		   OpenCount = set_OpenCount(OpenType),
		   if 
			   (Gold =< 0 orelse GoldNeeded < 0 orelse Gold < GoldNeeded) andalso Proto =:= 1 -> %%元宝不够,在使用副本的时候，不判断这里
				  [fail, {2, 0, [], HoleType}];
			  true ->%%获取诛邪之后的物品列表
				  case open_box_goods(PlayerId, EtsBoxGoodsType, 0, ProList, HoleType, OpenType, Career, 
									  OpenCount, OpenCounter, PlayerPurpleNum, PurpleTimeType, {init, BoxGoodsTrace}, PurpleEList) of
					  [0, _GoodsNumList, _NewOpenBoxCount, _NewPurpleNum, _BoxGoodsTraceResult, _NewPurpleEList] ->
						  [fail, {0, 0, [], HoleType}];
					  [1, GoodsNumList, NewOpenBoxCount, NewPurpleNum, BoxGoodsTraceResult, NewPurpleEList] ->
						  [ok, {OpenCount, HoleType, OpenType, GoodsNumList, NewOpenBoxCount, NewPurpleNum, BoxGoodsTraceResult, NewPurpleEList}]
				  end
		   end
	end.
%% 
%% %%获取诛邪之后的物品列表
open_box_goods(PlayerId, EtsBoxGoodsType, PurpleNum, ProList, HoleType, OpenType, Career, 
			   OpenCount, OpenBoxCount, PlayerPurpleNum, PurpleTimeType, BoxGoodsTraceResult, PurpleEList) ->
	OpenCountParam = #open_box_count_param{player_id = PlayerId,
										   ets_box_goods_type = EtsBoxGoodsType,
										   purple_num = PurpleNum,
										   pro_list = ProList,
										   pro_list_spec = [],
										   pro_type = 0,
										   hole_type = HoleType,
										   open_type = OpenType,
										   career = Career,
										   open_count = OpenCount,
										   open_box_counter = OpenBoxCount,
										   result_count = [],
										   player_purple_num = PlayerPurpleNum,
										   purple_time_type = PurpleTimeType,
										   spec_count_type = 0,
										   box_goods_trace = BoxGoodsTraceResult,
										   yg_hole = 0},
	if 
		HoleType =:= 4 ->%%远古妖洞，无论怎么调用，都是概率不变的
			open_box_count(OpenCountParam, PurpleEList);
		(OpenBoxCount >= 201 andalso OpenBoxCount =< 249) andalso PlayerPurpleNum < 1 -> %%如果玩家在200次开诛邪的过程中，没有开出1件紫色装备
			NewProListSpec = get_new_box_goods_prolist(OpenBoxCount-200, EtsBoxGoodsType, HoleType, Career),
			NewOpenCountParam = OpenCountParam#open_box_count_param{pro_list_spec = NewProListSpec, pro_type = 1, spec_count_type = 1},
			open_box_count(NewOpenCountParam, PurpleEList);
		(OpenBoxCount >= 401 andalso OpenBoxCount =< 449) andalso PlayerPurpleNum < 2 ->
			NewProListSpec = get_new_box_goods_prolist(OpenBoxCount-400, EtsBoxGoodsType, HoleType, Career),
			NewOpenCountParam = OpenCountParam#open_box_count_param{pro_list_spec = NewProListSpec, pro_type = 1, spec_count_type = 1},
			open_box_count(NewOpenCountParam, PurpleEList);
		true ->
			open_box_count(OpenCountParam, PurpleEList)
	end.
%%PurpleNum:此次诛邪产生紫装则为1，否则为0，初始值为0
%%PlayerPurpleNum:玩家当前已开出紫装数，产生紫装后，此值会自动累加
open_box_count(OpenCountParam, PurpleEList) when is_record(OpenCountParam, open_box_count_param) andalso OpenCountParam#open_box_count_param.open_count == 99999 ->
	#open_box_count_param{result_count = ResultCount,
						  open_box_counter = OpenBoxCount,
						  purple_num = PurpleNum,
						  box_goods_trace = BoxGoodsTraceResult} = OpenCountParam,
	[0, ResultCount, OpenBoxCount, PurpleNum, BoxGoodsTraceResult, PurpleEList];
open_box_count(OpenCountParam, PurpleEList) when is_record(OpenCountParam, open_box_count_param) andalso OpenCountParam#open_box_count_param.open_count == 0 ->
	#open_box_count_param{result_count = ResultCount,
						  open_box_counter = OpenBoxCount,
						  purple_num = PurpleNum,
						  box_goods_trace = BoxGoodsTraceResult} = OpenCountParam,
	[1, ResultCount, OpenBoxCount, PurpleNum, BoxGoodsTraceResult, PurpleEList];
open_box_count(OpenCountParam, PurpleEList) when is_record(OpenCountParam, open_box_count_param) ->
	case open_box_one(a, OpenCountParam, PurpleEList) of
		[0, [], _NewBoxGoodsTraceResult, _NewPurpleEList, _NYgHole] ->
			NewOpenCountParam = OpenCountParam#open_box_count_param{open_count = 99999, result_count = []},
			open_box_count(NewOpenCountParam, PurpleEList);
		[NewPurpleNum, Result, NewBoxGoodsTraceResult, NewPurpleEList, NYgHole] ->
			case NewPurpleNum == 1 of
				true ->%%开出紫装了
					NewOpenCountParam = 
						OpenCountParam#open_box_count_param{purple_num = NewPurpleNum, 
															pro_type = 0,
															open_count = OpenCountParam#open_box_count_param.open_count-1,
															open_box_counter = OpenCountParam#open_box_count_param.open_box_counter+1,
															result_count = Result,
															spec_count_type = 0,
															player_purple_num = OpenCountParam#open_box_count_param.player_purple_num+1,
															box_goods_trace = NewBoxGoodsTraceResult,
															yg_hole = NYgHole},
					open_box_count(NewOpenCountParam, NewPurpleEList);
				false ->%%没开出紫装
					#open_box_count_param{ets_box_goods_type = EtsBoxGoodsType,
										  hole_type = HoleType,
										  career = Career,
										  open_box_counter = OpenBoxCount,
										  player_purple_num = PlayerPurpleNum} = OpenCountParam,
					if 
						HoleType =:= 4 ->%%远古妖洞，无论怎么调用，都是概率不变的
							NewOpenCountParam = 
							   OpenCountParam#open_box_count_param{purple_num = NewPurpleNum,
																   pro_list_spec = [],
																   pro_type = 0,
																   open_count = OpenCountParam#open_box_count_param.open_count-1,
																   open_box_counter = OpenCountParam#open_box_count_param.open_box_counter+1,
																   result_count = Result,
																   spec_count_type = 0,
																   box_goods_trace = NewBoxGoodsTraceResult,
																   yg_hole = NYgHole},
						   open_box_count(NewOpenCountParam, NewPurpleEList);
						(OpenBoxCount >= 201 andalso OpenBoxCount =< 249) andalso (PlayerPurpleNum < 1)  andalso 
						   (OpenCountParam#open_box_count_param.open_count-1 =/= 0) -> %%如果玩家在200次开诛邪的过程中，没有开出1件紫色装备
						   NewProListSpec = get_new_box_goods_prolist(OpenBoxCount-200, EtsBoxGoodsType, HoleType, Career),
						   NewOpenCountParam = 
							   OpenCountParam#open_box_count_param{purple_num = NewPurpleNum,
																   pro_list_spec = NewProListSpec,
																   pro_type = 1,
																   open_count = OpenCountParam#open_box_count_param.open_count-1,
																   open_box_counter = OpenCountParam#open_box_count_param.open_box_counter+1,
																   result_count = Result,
																   spec_count_type = 1,
																   box_goods_trace = NewBoxGoodsTraceResult},
						   open_box_count(NewOpenCountParam, NewPurpleEList);
					   (OpenBoxCount >= 401 andalso OpenBoxCount =< 449) andalso PlayerPurpleNum < 2 andalso 
						   (OpenCountParam#open_box_count_param.open_count-1 =/= 0) ->
						   NewProListSpec = get_new_box_goods_prolist(OpenBoxCount-400, EtsBoxGoodsType, HoleType, Career),
						   NewOpenCountParam = 
							   OpenCountParam#open_box_count_param{purple_num = NewPurpleNum,
																   pro_list_spec = NewProListSpec,
																   pro_type = 1,
																   open_count = OpenCountParam#open_box_count_param.open_count-1,
																   open_box_counter = OpenCountParam#open_box_count_param.open_box_counter+1,
																   result_count = Result,
																   spec_count_type = 1,
																   box_goods_trace = NewBoxGoodsTraceResult},
						   open_box_count(NewOpenCountParam, NewPurpleEList);
					   true ->
						   NewOpenCountParam = 
							   OpenCountParam#open_box_count_param{purple_num = NewPurpleNum,
																   pro_list_spec = [],
																   pro_type = 0,
																   open_count = OpenCountParam#open_box_count_param.open_count-1,
																   open_box_counter = OpenCountParam#open_box_count_param.open_box_counter+1,
																   result_count = Result,
																   spec_count_type = 0,
																   box_goods_trace = NewBoxGoodsTraceResult},
						   open_box_count(NewOpenCountParam, NewPurpleEList)
					end
			end
	end;
open_box_count(_OpenCountParam, _PurpleEList) ->
	[0, [], 0, 0, {init, []}].


open_box_one(b, OpenCountParam, PurpleEList) ->
	#open_box_count_param{purple_num = PurpleNum,
						  result_count = ResultCount,
						  box_goods_trace = BoxGoodsTraceResult,
						  yg_hole = YgHole} = OpenCountParam,
	[PurpleNum, ResultCount, BoxGoodsTraceResult, PurpleEList, YgHole];
open_box_one(a, OpenCountParam, PurpleEList) ->
	#open_box_count_param{player_id = PlayerId,
						  ets_box_goods_type = EtsBoxGoodsType,
						  purple_num = PurpleNum,
						  pro_type = ProType,
						  hole_type = HoleType,
						  open_type = OpenType,
						  result_count = ResultCount,
						  spec_count_type = SpecCountType,
						  purple_time_type = PurpleTimeType,
						  box_goods_trace = BoxGoodsTraceResult,
						  yg_hole = YgHole} = OpenCountParam,
	RandomCount = random:uniform(?BASE_BOX_GOODS_PRO),
	case ProType of
		0 ->
			ProList = OpenCountParam#open_box_count_param.pro_list,
			BaseGoodsId = get_goods_one(a, 0, ProList, RandomCount),
			case get_goods_num(PlayerId, EtsBoxGoodsType, PurpleNum, HoleType, OpenType, BaseGoodsId, 
							   ResultCount, PurpleTimeType, SpecCountType, BoxGoodsTraceResult, PurpleEList, ProType, YgHole) of
				{ok, NewPurpleNum, NewResultCount, NewBoxGoodsTraceResult, NewPurpleEList, NYgHole} ->
%% 					?DEBUG("000 ok, get_goods_num:~p", [NYgHole]),
					NewOpenCountParam = OpenCountParam#open_box_count_param{purple_num = NewPurpleNum,
																			result_count = NewResultCount,
																			box_goods_trace = NewBoxGoodsTraceResult,
																			yg_hole = NYgHole
																			},
					open_box_one(b, NewOpenCountParam, NewPurpleEList);

				{fail, NewResultCount, NewBoxGoodsTraceResult, NewPurpleEList} ->
%% 					?DEBUG("fail  00000:~p", [BaseGoodsId]),
					NewOpenCountParam = OpenCountParam#open_box_count_param{result_count = NewResultCount,
																  box_goods_trace = NewBoxGoodsTraceResult},
					open_box_one(a, NewOpenCountParam, NewPurpleEList)
			end;
		1 ->
			ProListSpec = OpenCountParam#open_box_count_param.pro_list_spec,
			BaseGoodsId = get_goods_one(a, 0, ProListSpec, RandomCount),
			case get_goods_num(PlayerId, EtsBoxGoodsType, PurpleNum, HoleType, OpenType, BaseGoodsId, 
							   ResultCount, PurpleTimeType, SpecCountType, BoxGoodsTraceResult, PurpleEList, ProType, YgHole) of
				{ok, NewPurpleNum, NewResultCount, NewBoxGoodsTraceResult, NewPurpleEList, NYgHole} ->
%% 					?DEBUG("111 ok, get_goods_num:~p", [NYgHole]),
					NewOpenCountParam = OpenCountParam#open_box_count_param{purple_num = NewPurpleNum,
																			result_count = NewResultCount,
																			box_goods_trace = NewBoxGoodsTraceResult,
																			yg_hole = NYgHole},
					open_box_one(b, NewOpenCountParam, NewPurpleEList);
				{fail, NewResultCount, NewBoxGoodsTraceResult, NewPurpleEList} ->
%% 					?DEBUG("fail  1111:~p", [BaseGoodsId]),
					NewOpenCountParam = OpenCountParam#open_box_count_param{result_count = NewResultCount,
																  box_goods_trace = NewBoxGoodsTraceResult},
					open_box_one(a, NewOpenCountParam, NewPurpleEList)
			end
	end.

get_goods_one(b, GoodsTypeId, _RestElem, _RandomCount) ->
	GoodsTypeId;
get_goods_one(a, GoodsTypeIdInit, [], _RandomCount) ->
	GoodsTypeIdInit;
get_goods_one(a, GoodsTypeIdInit, [Elem|RestElem], RandomCount) ->
	{GoodsTypeId, Pro} = Elem,
	case RandomCount =< Pro andalso Pro =/= 0 of
		true ->
			get_goods_one(b, GoodsTypeId, RestElem, RandomCount);
		false ->
			get_goods_one(a, GoodsTypeIdInit, RestElem, RandomCount)
	end.

%%合并相同 的物品
get_goods_num(PlayerId, EtsBoxGoodsType, PurpleNum, HoleType, OpenType, BaseGoodsId, 
			  ResultCount, PurpleTimeType, SpecCountType, BoxGoodsTraceResult, PurpleEList, ProType, YgHole) ->
%% 	?DEBUG("the goods num  is Goods:~p,YgHole:~p", [BaseGoodsId, YgHole]),
	GoodsTypeInfo = goods_util:get_goods_type(BaseGoodsId),
	case is_record(GoodsTypeInfo, ets_base_goods) of
		false ->
%% 			?DEBUG("is not the goods:~p", [BaseGoodsId]),
			{fail, ResultCount, BoxGoodsTraceResult, PurpleEList};
		true ->%%判断是否有数量限制
			 case get_box_goods_ets(EtsBoxGoodsType, HoleType, BaseGoodsId) of
				 [] ->
%% 					 ?DEBUG("fail [] can not get ets", []),
					 {fail, ResultCount, BoxGoodsTraceResult, PurpleEList};
				 [BoxGoods] ->
					 case BoxGoods#ets_base_box_goods.num_limit == 0 of
						 false ->%%有数量限制的
							 if
								 GoodsTypeInfo#ets_base_goods.color =:= 4 
								   andalso OpenType >= 2 andalso OpenType =< 3 
								   andalso HoleType =:= 4 andalso YgHole < ?YG_HOLE_NUM_LIMIT ->%%远古妖洞10次或者50次的，最多出现三件紫装
%% 									 ?DEBUG("get the purple goods 485, YgHole:~p ", [YgHole]),
									 get_goods_num_inner(BaseGoodsId, PurpleNum, ResultCount, BoxGoodsTraceResult, PurpleEList, YgHole+1);
								 true ->
									 case BoxGoodsTraceResult of
										 {_, []} ->%%没有记录喔
											 handle_make_goods_trace(0, 1, [], 
																	 PlayerId, EtsBoxGoodsType, GoodsTypeInfo,
																	 PurpleNum, BaseGoodsId, HoleType, ResultCount, BoxGoodsTraceResult, PurpleEList, ProType, YgHole);
										 {_, GoodsTrace} ->%%有记录，看看是不是对应的物品
%% 											 GoodsTrace = BoxGoodsTrace#ets_open_boxgoods_trace.goods_trace,
											 case lists:keyfind(BaseGoodsId, 1, GoodsTrace) of 
												 false ->%%里面没有对应的物品
													 handle_make_goods_trace(1, 1, GoodsTrace, 
																			 PlayerId, EtsBoxGoodsType, GoodsTypeInfo,
																			 PurpleNum, BaseGoodsId, HoleType, ResultCount, BoxGoodsTraceResult, PurpleEList, ProType, YgHole);
												 {_PlayerId,RecordNum} ->
													 if RecordNum >= BoxGoods#ets_base_box_goods.num_limit ->
%% 															?DEBUG("get box goods ets fail, RecordNum:~p, NumLimit:~p", [RecordNum, BoxGoods#ets_base_box_goods.num_limit]),
															{fail, ResultCount, BoxGoodsTraceResult, PurpleEList};
														true ->
															handle_make_goods_trace(2, RecordNum, GoodsTrace, 
																					PlayerId, EtsBoxGoodsType, GoodsTypeInfo,
																					PurpleNum, BaseGoodsId, HoleType, ResultCount, BoxGoodsTraceResult, PurpleEList, ProType, YgHole)
													 end
											 end
									 end
							 end;
						 true ->%%不用做判断,没数量限制
							 case GoodsTypeInfo#ets_base_goods.color == 4 of
								 true ->%%紫装啊^_^
									 if
										 OpenType =:= 1 andalso HoleType =:=  4 ->%%远古妖洞，一次的是不会出紫装的
%% 											 ?DEBUG("get box goods ets fail", []),
											 {fail, ResultCount, BoxGoodsTraceResult, PurpleEList};
										 OpenType >= 2 andalso OpenType =< 3 andalso HoleType =:= 4 andalso YgHole < ?YG_HOLE_NUM_LIMIT ->%%远古妖洞10次或者50次的，最多出现三件紫装
%% 											  ?DEBUG("get the purple goods 518, YgHole:~p ", [YgHole]),
											 get_goods_num_inner(BaseGoodsId, PurpleNum, ResultCount, BoxGoodsTraceResult, PurpleEList, YgHole+1);
										 true ->
											 case PurpleTimeType == 1 of
												 true ->%% N misc之内不能出第二件紫装，除非..
%% 													 case OpenType == 1 andalso SpecCountType == 1 of
													 case SpecCountType == 1 of
														 false ->%%只能在万年的时候出现紫装
%% 															 ?DEBUG("get box goods ets fail", []),
															 {fail, ResultCount, BoxGoodsTraceResult, PurpleEList};
														 true ->
															 judge_purple_num_box_goods(EtsBoxGoodsType, HoleType, PurpleNum, 
																						BaseGoodsId, ResultCount, BoxGoodsTraceResult, PurpleEList, ProType, YgHole)
													 end;
												 false ->
%% 													 if OpenType == 1 andalso SpecCountType == 1 ->
													 if SpecCountType == 1 ->
															judge_purple_num_box_goods(EtsBoxGoodsType, HoleType, PurpleNum, 
																					   BaseGoodsId, ResultCount, BoxGoodsTraceResult, PurpleEList, ProType, YgHole);
%% 														case OpenType == 1 of
%% 														true ->
														OpenType == 1 ->%%只要是一次诛邪的都不可以出现紫装
%% 															?DEBUG("get box goods ets fail", []),
															{fail, ResultCount, BoxGoodsTraceResult, PurpleEList};
														true ->
															judge_purple_num_box_goods(EtsBoxGoodsType, HoleType, PurpleNum,
																					   BaseGoodsId, ResultCount, BoxGoodsTraceResult, PurpleEList, ProType, YgHole)
													 end
											 end
									 end;
								 false ->
									 get_goods_num_inner(BaseGoodsId, PurpleNum, ResultCount, BoxGoodsTraceResult, PurpleEList, YgHole)
							 end
					 end
			 end
	end.

judge_purple_num_box_goods(EtsBoxGoodsType, HoleType, PurpleNum, 
						   BaseGoodsId, ResultCount, BoxGoodsTraceResult, PurpleEList, ProType, YgHole) ->
	 case PurpleNum of
		 0 ->
%% 			 {_PurpleGoodsId, PurpleEListOld} = PurpleEList,
			 case ProType of
				 0 ->%%一分钟是否做相同紫装的记录
					 case check_puple_equip_cover(BaseGoodsId, PurpleEList, HoleType) of
						 {false, NewPurpleEList} ->
%% 							 NewPurpleEList = {BaseGoodsId, PurpleEListOld},
							 {ok, 1, [{BaseGoodsId,1}|ResultCount], BoxGoodsTraceResult, NewPurpleEList, YgHole};
						 true ->
							 case get_box_goods_ets(EtsBoxGoodsType, HoleType, BaseGoodsId) of
								 [] ->%%没有？继续随机....
%% 									 ?DEBUG("get box goods ets fail", []),
									 {fail, ResultCount, BoxGoodsTraceResult, PurpleEList};
								 [BoxGoods] ->
									 ReplaceBaseGoodsId = BoxGoods#ets_base_box_goods.goods_id_replace,
									 get_goods_num_inner(ReplaceBaseGoodsId, PurpleNum, ResultCount, BoxGoodsTraceResult, PurpleEList, YgHole)
							 end
					  end;
				 1 ->%%一分钟是否做相同紫装的记录
					 NewPurpleEList = make_puple_equip_cover(BaseGoodsId, PurpleEList, HoleType),
					 {ok, 1, [{BaseGoodsId,1}|ResultCount], BoxGoodsTraceResult, NewPurpleEList, YgHole}
			 end;
		 1 ->%%已经开出来了,替换掉
			 case get_box_goods_ets(EtsBoxGoodsType, HoleType, BaseGoodsId) of
				 [] ->%%没有？继续随机....
%% 					 ?DEBUG("get box goods ets fail", []),
					 {fail, ResultCount, BoxGoodsTraceResult, PurpleEList};
				 [BoxGoods] ->
					 ReplaceBaseGoodsId = BoxGoods#ets_base_box_goods.goods_id_replace,
					 get_goods_num_inner(ReplaceBaseGoodsId, PurpleNum, ResultCount, BoxGoodsTraceResult, PurpleEList, YgHole)
			 end
	 end.
%%标识是否更新一分钟不能出现同一件紫装的判断
check_puple_equip_cover(BaseGoodsId, PurpleEList, HoleType)->
	{_PurpleGoodsId, PurpleEListOld} = PurpleEList,
	case HoleType of
		1 ->
			{false, PurpleEList};
		_ ->
			case lists:any(fun(Elem) -> Elem =:= BaseGoodsId end, PurpleEListOld) of
				true ->
					true;
				false ->
					NewPurpleEList = {BaseGoodsId, PurpleEListOld},
					{false, NewPurpleEList}
			end
	end.
%%之前出现过紫装，直接做判断处理
make_puple_equip_cover(BaseGoodsId, PurpleEList, HoleType) ->
	{_PurpleGoodsId, PurpleEListOld} = PurpleEList,
	case HoleType of
		1 ->
			PurpleEList;
		_ ->
			{BaseGoodsId, PurpleEListOld}
	end.

handle_make_goods_trace(TraceType, RecordNum, GoodsTrace, _PlayerId, EtsBoxGoodsType, GoodsTypeInfo, 
						PurpleNum, BaseGoodsId, HoleType, ResultCount, BoxGoodsTraceResult, PurpleEList, ProType, YgHole) ->
	case make_goods_num_trace(EtsBoxGoodsType, GoodsTypeInfo, PurpleNum, BaseGoodsId, HoleType, ResultCount, BoxGoodsTraceResult, PurpleEList, ProType) of
		{0, TraceResult} ->
			TraceResult;
		{1, TraceResult} ->
			case TraceType of
				0 ->
					NewGoodsTrace = [{BaseGoodsId, RecordNum}];
				1 ->
					NewGoodsTrace = [{BaseGoodsId, RecordNum}|GoodsTrace];
				2 ->
					NewGoodsTrace = lists:keyreplace(BaseGoodsId, 1, GoodsTrace, {BaseGoodsId, RecordNum+1})
			end,
%% 			BoxGoodsTraceEts = BoxGoodsTrace#ets_open_boxgoods_trace{goods_trace = NewGoodsTrace},
%% 			update_ets_open_boxgoods_trace(BoxGoodsTraceEts),
			{ok, NewPurpleNum, NewResultCount, NewPurpleEList} = TraceResult,
			{ok, NewPurpleNum, NewResultCount, {update, NewGoodsTrace}, NewPurpleEList, YgHole}
	end.
	
make_goods_num_trace(EtsBoxGoodsType, GoodsTypeInfo, PurpleNum, BaseGoodsId, HoleType, ResultCount, BoxGoodsTraceResult, PurpleEList, ProType) ->
	case GoodsTypeInfo#ets_base_goods.color == 4 of
		true ->%%紫装啊^_^
			case PurpleNum of
				0 ->%%直接在前面+
%% 					{_PurpleGoodsId, PurpleEListOld} = PurpleEList,
					case ProType of
						0 ->%%一分钟是否做相同紫装的记录
					 case check_puple_equip_cover(BaseGoodsId, PurpleEList, HoleType) of
						 {false, NewPurpleEList} ->
%% 							 NewPurpleEList = {BaseGoodsId, PurpleEListOld},
							 {1, {ok, 1, [{BaseGoodsId,1}|ResultCount], NewPurpleEList}};
						 true ->
							 case get_box_goods_ets(EtsBoxGoodsType, HoleType, BaseGoodsId) of
								 [] ->%%没有？继续随机....
%% 									 ?DEBUG("get box goods ets fail", []),
									 {0, {fail, ResultCount, BoxGoodsTraceResult, PurpleEList}};
								 [BoxGoods] ->
									 ReplaceBaseGoodsId = BoxGoods#ets_base_box_goods.goods_id_replace,
									 case lists:keysearch(ReplaceBaseGoodsId, 1, ResultCount) of
										 false ->
											 {1, {ok, PurpleNum, [{ReplaceBaseGoodsId,1}|ResultCount], PurpleEList}};
										 {value, {_BaseGooodsId, Num}} ->
											 {1, {ok, PurpleNum, lists:keyreplace(ReplaceBaseGoodsId, 1, ResultCount, {ReplaceBaseGoodsId, Num+1}), PurpleEList}}
									 end
							 end
					end;
						1 ->%%一分钟是否做相同紫装的记录
							NewPurpleEList = make_puple_equip_cover(BaseGoodsId, PurpleEList, HoleType),
							{1, {ok, 1, [{BaseGoodsId,1}|ResultCount], NewPurpleEList}}
					end;
				1 ->
					case get_box_goods_ets(EtsBoxGoodsType, HoleType, BaseGoodsId) of
						[] ->%%没有？继续随机....
%% 							?DEBUG("get box goods ets fail", []),
							{0, {fail, ResultCount, BoxGoodsTraceResult, PurpleEList}};
						[BoxGoods] ->
							ReplaceBaseGoodsId = BoxGoods#ets_base_box_goods.goods_id_replace,
							case lists:keysearch(ReplaceBaseGoodsId, 1, ResultCount) of
								false ->
									{1, {ok, PurpleNum, [{ReplaceBaseGoodsId,1}|ResultCount], PurpleEList}};
								{value, {_BaseGooodsId, Num}} ->
									{1, {ok, PurpleNum, lists:keyreplace(ReplaceBaseGoodsId, 1, ResultCount, {ReplaceBaseGoodsId, Num+1}), PurpleEList}}
							end
					end
			end;
		false ->
			case lists:keysearch(BaseGoodsId, 1, ResultCount) of
				false ->
					{1, {ok, PurpleNum, [{BaseGoodsId,1}|ResultCount], PurpleEList}};
				{value, {_BaseGooodsId, Num}} ->
					{1, {ok, PurpleNum, lists:keyreplace(BaseGoodsId, 1, ResultCount, {BaseGoodsId, Num+1}), PurpleEList}}
			end
	end.
get_goods_num_inner(BaseGoodsId, PurpleNum, ResultCount, BoxGoodsTraceResult, PurpleEList, YgHole) ->
	case lists:keysearch(BaseGoodsId, 1, ResultCount) of
		false ->
			{ok, PurpleNum, [{BaseGoodsId,1}|ResultCount], BoxGoodsTraceResult, PurpleEList, YgHole};
		{value, {_BaseGoodsId, Num}} ->
			{ok, PurpleNum, lists:keyreplace(BaseGoodsId, 1, ResultCount, {BaseGoodsId, Num+1}), BoxGoodsTraceResult, PurpleEList, YgHole}
	end.
get_new_box_goods_prolist(OpenBoxCount, EtsBoxGoodsType, HoleType, Career) ->
	ProHoleList = get_pro_goods_by_holetype(EtsBoxGoodsType, HoleType),
	DiffPro = OpenBoxCount * ?INCREASE_BOX_GOODS_PRO,
	{_Career, PurplePro, Lists} = 
		lists:foldl(fun get_pro_goods_spec/2, {Career, 0, []}, ProHoleList),
	{_Count, _PurplePro, _DiffPro, Result} = 
		lists:foldl(fun make_pro_list_sepc/2, {0, PurplePro, DiffPro, []}, Lists),
	lists:reverse(Result).

make_pro_list_sepc(Elem, AccIn) ->
	[Type, Pro, BaseGoodsId] = Elem,
	{Count, PurplePro, DiffPro, Result} = AccIn,
	case Type of
		0 ->
			case 1-6*DiffPro-12*PurplePro =< 0 of
				true ->
					NewPro = 0;
				false ->
					NewProBase = (1-6*DiffPro-12*PurplePro)/(1-6*DiffPro-6*PurplePro),
					NewPro = ?BASE_BOX_GOODS_PRO * Pro * NewProBase
			end;
		1 ->
			NewPro = ?BASE_BOX_GOODS_PRO * (Pro+DiffPro)
	end,
	NewProInt = tool:to_integer(NewPro),
	if NewPro == 0 ->
		    {Count, PurplePro, DiffPro, [{BaseGoodsId, 0}|Result]};
	   true ->
		   NewCount = Count + NewProInt,
		   {NewCount, PurplePro, DiffPro, [{BaseGoodsId, NewCount}|Result]}
	end.

get_pro_goods_spec(BoxGoodsInfo, AccIn) ->
	{Career, PurplePro, GoodsList} = AccIn,
	#ets_base_box_goods{goods_id = BaseGoodsId,
						 pro = Pro}= BoxGoodsInfo,
	GoodsTypeInfo =  goods_util:get_goods_type(BaseGoodsId),
	if 
		is_record(GoodsTypeInfo, ets_base_goods) =:= false ->
			AccIn;
		true ->
			GoodsCareer = GoodsTypeInfo#ets_base_goods.career,
			if GoodsCareer == 0 ->
				  NewElem = [0, Pro, BaseGoodsId],
				  {Career, PurplePro, [NewElem|GoodsList]}; 
			   GoodsCareer == Career ->
					NewElem = [1, Pro, BaseGoodsId],
					{Career, Pro, [NewElem|GoodsList]};
				true ->
					AccIn
			end
	end.

handle_box_system_msg(Realm, HoleType, PlayerId, PlayerName, _PlayerLevel, Career, Sex, CastListStr, BroadCastGoodsList) ->
	Country = lib_player:get_country(Realm),
	HoleTypeName = get_holetype_name(HoleType),
	NameColor = data_agent:get_realm_color(Realm),
	CastFrontContent = 
		io_lib:format("号外号外！<font color='~s'>[~s]</font>的[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]轻松清剿了~s妖洞的怪物，获得",
					  ["#FF0000", Country, PlayerId, PlayerName, Career, Sex, NameColor, PlayerName, HoleTypeName]),
	CastEndContent = "等海量宝物。",
	ConTent = lists:concat([CastFrontContent, CastListStr, CastEndContent]),
	%%广播一下
	lib_chat:boradcast_box_goods_msg(3, ConTent, BroadCastGoodsList).

handle_each_box_goods(EtsBoxGoodsType, PlayerId, PlayerName, HoleType, GoodsInfo, AccIn) ->
	{Gid, GoodsNum, BaseGoodsId, GoodsName} = GoodsInfo,
	{BroadCastGoodsList, CastListStr} = AccIn,
	case get_box_goods_ets(EtsBoxGoodsType, HoleType, BaseGoodsId) of
		[] ->
			{BroadCastGoodsList, CastListStr};
		[BoxGoods] ->
			ShowType = BoxGoods#ets_base_box_goods.show_type,
			NowTime = util:unixtime(),
			Log_box_open = #ets_log_box_open{
								player_id = PlayerId,
								player_name = PlayerName, 
								hole_type = HoleType, 
								goods_id = BaseGoodsId, 
						 		goods_name = GoodsName, 
								gid = Gid, 
								num = GoodsNum, 
								show_type = ShowType,
								open_time = NowTime
								 },
			case db_agent:insert_log_box_open(log_box_open, Log_box_open) of
				{mongo, Ret} ->
					case ShowType of
						1 ->
							%%系统广播
							Id = Ret,
							LogBoxOpenEts = Log_box_open#ets_log_box_open{id = Id},
							ets_update_log_box_open(LogBoxOpenEts),
							NewBroadCastGoodsList = [LogBoxOpenEts | BroadCastGoodsList],
							%%开始系统广播啦
							NewCastList = make_broadcast_msg(BaseGoodsId,Gid, PlayerId, CastListStr, GoodsName);
						_ ->
							NewBroadCastGoodsList = BroadCastGoodsList,
							NewCastList = CastListStr
					end;
				1 ->
					case ShowType of
						1 ->
							%%系统广播
							WhereList = [{player_id, PlayerId}, {player_name, PlayerName}, 
								 {hole_type, HoleType}, {goods_id, BaseGoodsId}, 
								 {gid, Gid}, {num, GoodsNum}],
							case db_agent:get_log_box_open_new(log_box_open, WhereList) of
								[] ->%%数据居然没有..
									NewBroadCastGoodsList = BroadCastGoodsList,
									NewCastList = CastListStr;
								LogBoxOpenNew ->
									LogBoxOpenEts = list_to_tuple([ets_log_box_open]++LogBoxOpenNew),
									ets_update_log_box_open(LogBoxOpenEts),
									NewBroadCastGoodsList = [LogBoxOpenEts | BroadCastGoodsList],
									%%开始系统广播啦
									NewCastList = make_broadcast_msg(BaseGoodsId,Gid, PlayerId, CastListStr, GoodsName)
							end;
						_ ->
							NewBroadCastGoodsList = BroadCastGoodsList,
							NewCastList = CastListStr
					end;
				_Other ->
					NewBroadCastGoodsList = BroadCastGoodsList, 
					NewCastList = CastListStr
			end,
			{NewBroadCastGoodsList, NewCastList}
	end.

make_broadcast_msg(BaseGoodsId, Gid, PlayerId, CastListStr, GoodsName) ->
	GoodsTypeInfoInit = goods_util:get_goods_type(BaseGoodsId),
	case is_record(GoodsTypeInfoInit, ets_base_goods) of
		true ->
			Color = GoodsTypeInfoInit#ets_base_goods.color,
			ColorContent = goods_util:get_color_hex_value(Color),
			case string:len(CastListStr) of
				0 ->
					MiscContent = io_lib:format("<a href='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a> ",
												[Gid, PlayerId, ColorContent, GoodsName]);
				_ ->
					MiscContent = io_lib:format("<a href='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a> ",
												[Gid, PlayerId, ColorContent, GoodsName])
			end,
			MiscContent++CastListStr;
		false ->
			CastListStr
	end.
			
%%往本地插记录
lib_box_goods_log_local(LogBoxOpenEts) ->
	ets_update_log_box_open(LogBoxOpenEts).


%% %%打包返回给客户端的开宝箱数据
%% handle_each_box_goods_result(GoodsElem) ->
%% 	{Gid, GoodsNum, BaseGoodsId, GoodsName} = GoodsElem,
%% 	GoodsNameBin = tool:to_binary(GoodsName),
%% 	Len = byte_size(GoodsNameBin),
%% 	<<Gid:32, GoodsNum:16,BaseGoodsId:32,Len:16,GoodsNameBin/binary>>.

%% get_boxgoods_trace(PlayerId) ->
%% 	case ets:lookup(?ETS_OPEN_BOXGOODS_TRACE, PlayerId) of
%% 		{error, _Reason} ->
%% 			[];
%% 		Match ->
%% 			Match
%% 	end.
%% update_ets_open_boxgoods_trace(BoxGoodsTraceEts) ->
%% 	?DEBUG("update ets_open_boxgoods_tract", []),
%% 	ets:insert(?ETS_OPEN_BOXGOODS_TRACE, BoxGoodsTraceEts).

%%开始往玩家仓库添加物品,GoodsList->物品列表{BaseGoodsId, Num}
add_box_goods_group(GoodsList, GoodsStatus) ->
	Result = lists:foldl(fun add_box_goods_each/2, {ok, 0, GoodsStatus#goods_status.player_id, []}, GoodsList),
	case Result of
		{ok, Num, _PlayerIdOk, NewGoodsList} ->
			NewGoodsStatus = 
				GoodsStatus#goods_status{box_remain_cells = 
											 GoodsStatus#goods_status.box_remain_cells - Num},
			{ok, [1, NewGoodsList], NewGoodsStatus};
		{fail, _Num, _PlayerIdFail, _NewGoodsList} ->
			{fail, [0, []], GoodsStatus}
	end.
%%处理每一份物品			
add_box_goods_each(GoodsElem, AccIn) ->
	{GoodsTypeId, GoodsNum} = GoodsElem,
	case AccIn of
		{fail, _Num, _PlayerId, _ReturnGoodsList} ->
			AccIn;
		{ok, Num, PlayerId, ReturnGoodsList} ->
			GoodsTypeInfoInit = goods_util:get_goods_type(GoodsTypeId),
			case is_record(GoodsTypeInfoInit, ets_base_goods) of
				false ->
					{fail, 0, PlayerId, ReturnGoodsList};
				true ->
					#ets_base_goods{type = Type,
									subtype = SubType} = GoodsTypeInfoInit,
					if Type == 25 andalso (SubType == 12 orelse SubType == 13) ->
						   GoodsTypeInfo = GoodsTypeInfoInit#ets_base_goods{bind = 2};
					   true ->
						   GoodsTypeInfo = GoodsTypeInfoInit#ets_base_goods{bind = 0}
					end,
					GoodsInfo = goods_util:get_new_goods(GoodsTypeInfo),
					{NewNum, NewReturnGoodsList} = 
						add_box_goods_base(GoodsTypeInfo, GoodsNum,GoodsInfo, Num, PlayerId),
					{ok, NewNum, PlayerId, NewReturnGoodsList++ReturnGoodsList}
			end
	end.
%%开始真正添加物品
add_box_goods_base(GoodsTypeInfo, GoodsNum, GoodsInfo, Num, PlayerId) ->
	case GoodsTypeInfo#ets_base_goods.max_overlap > 1 of
		true ->%%哇塞，物品原来是可以叠加的噢 
			#ets_base_goods{goods_id = BaseGoodsId,
							bind = Bind} = GoodsTypeInfo,
			GoodsList = goods_util:get_type_goods_list(PlayerId, BaseGoodsId, Bind, 7);
		false ->
			GoodsList = []
	end,
	add_box_goods_base_final(PlayerId, GoodsTypeInfo, GoodsNum, GoodsInfo, Num, GoodsList).
%%分开处理不同属性的物品
add_box_goods_base_final(PlayerId, GoodsTypeInfo, GoodsNum, GoodsInfo, Num, GoodsList) ->
	case GoodsTypeInfo#ets_base_goods.max_overlap > 1 of
		true ->
			%%现在原有的物品上叠加,返回剩余的物品个数
			[NewGoodsNum, _, _GoodsName, ReturnGoodsListOne] = 
				lists:foldl(fun update_overlap_goods/2,
							[GoodsNum, GoodsTypeInfo#ets_base_goods.max_overlap,
							 GoodsTypeInfo#ets_base_goods.goods_name, []], GoodsList), 
			%%新增物品
			[_, _, _, _, _, NewNum, ReturnGoodsListTwo] = 
				goods_util:deeploop(fun add_overlap_box_goods/2, NewGoodsNum,
									[PlayerId, GoodsTypeInfo#ets_base_goods.goods_name, GoodsInfo, 7, 
									 GoodsTypeInfo#ets_base_goods.max_overlap, Num, []]),
			ReturnGoodsList = ReturnGoodsListOne ++ ReturnGoodsListTwo;
		false ->
			Counts = lists:seq(1, GoodsNum),
			{_PlayerId, _GoodsName, _GoodsInfo, _Location, NewNum, ReturnGoodsList} = 
				lists:foldl(fun add_nolap_box_goods/2,
							{PlayerId, GoodsTypeInfo#ets_base_goods.goods_name,
							 GoodsInfo, 7, Num, []}, Counts)
	end,
	{NewNum, ReturnGoodsList}.
		

%% 更新原有的可叠加物品
update_overlap_goods(GoodsInfo, [Num, MaxOverlap, GoodsName, ReturnGoodsList]) ->
    case Num > 0 of
        true when GoodsInfo#goods.num =/= MaxOverlap andalso MaxOverlap > 0 ->
            case Num + GoodsInfo#goods.num > MaxOverlap of
                %% 总数超出可叠加数
                true ->
                    OldNum = MaxOverlap,
                    NewNum = Num + GoodsInfo#goods.num - MaxOverlap;
                false ->
                    OldNum = Num + GoodsInfo#goods.num,
                    NewNum = 0
            end,
            lib_goods:change_goods_num(GoodsInfo, OldNum),
			#goods{id = GoodsId,
				   goods_id = BaseGoodsId} = GoodsInfo,
			case NewNum of
				0 ->
					Elem = [{GoodsId, Num, BaseGoodsId, GoodsName}];
				_ ->
					Elem = [{GoodsId, Num - NewNum, BaseGoodsId, GoodsName}]
			end;
		true ->
			NewNum = Num,
			Elem = [];
        false ->
            NewNum = 0,
			Elem = []
	end,
    [NewNum, MaxOverlap, GoodsName, ReturnGoodsList++Elem].

%%添加可叠加的诛邪物品
add_overlap_box_goods(GoodsNum, 
					  [PlayerId, GoodsName, GoodsInfo, Location, MaxOverLap, Num, ReturnGoodsList]) ->
	case GoodsNum > MaxOverLap of
		true ->
			NewGoodsNum = GoodsNum - MaxOverLap,
			OldGoodsNum = MaxOverLap;
		false ->
			NewGoodsNum = 0,
			OldGoodsNum = GoodsNum
	end,
	case OldGoodsNum > 0 of
		true ->
			NewGoodsInfo = 
				GoodsInfo#goods{player_id = PlayerId, location = Location, cell = 0, num = OldGoodsNum},
			NewGoodsInfoEts = lib_goods:add_goods(NewGoodsInfo),
			%%{NewNum, GoodsId, GoodsNum,GoodsType, GoodsName}
			#goods{id = GoodsId,
				   num = ReturnGoodsNum,
				   goods_id = BaseGoodsId} = NewGoodsInfoEts,
			NewReturnGoodsList = [{GoodsId, ReturnGoodsNum, BaseGoodsId, GoodsName}|ReturnGoodsList],
			NewNum = Num +1;
		_ ->
			NewNum = Num,
			NewReturnGoodsList = ReturnGoodsList
	end,
	[NewGoodsNum, [PlayerId, GoodsName, GoodsInfo, Location, MaxOverLap, NewNum, NewReturnGoodsList]].
%%添加不可叠加的诛邪物品
add_nolap_box_goods(_Elem, AccIn) ->
	{PlayerId, GoodsName, GoodsInfo, Location, Num, ReturnGoodsList} = AccIn,
	NewGoodsInfo = GoodsInfo#goods{player_id = PlayerId, location = Location, cell = 0, num = 1},
	NewGoodsInfoEts = lib_goods:add_goods(NewGoodsInfo),
	#goods{id = GoodsId,
		   num = GoodsNum,
		   goods_id = BaseGoodsId} = NewGoodsInfoEts,
	NewReturnGoodsList = [{GoodsId, GoodsNum, BaseGoodsId, GoodsName}|ReturnGoodsList],
	NewNum = Num +1,
	{PlayerId, GoodsName, GoodsInfo, Location, NewNum, NewReturnGoodsList}.


%%获取诛邪仓库的物品数据
get_box_goods(PlayerId) ->
	Pattern = #goods{player_id = PlayerId, location = 7, _='_'},
	ets:match_object(?ETS_GOODS_ONLINE, Pattern).
%% handle_warehouse(BoxGoods) ->
%% 	#goods{id = Gid,
%% 		   num = GoodsNum,
%% 		   goods_id = BaseGoodsId} = BoxGoods,
%% 	GoodsNameBin = tool:to_binary([]),
%% 	Len = byte_size(GoodsNameBin),
%% 	<<Gid:32, GoodsNum:16, BaseGoodsId:32,Len:16, GoodsNameBin/binary>>.


%% %% -----------------------------------------------------------------
%% %% 28004 将物品放入背包
%% %% -----------------------------------------------------------------
%%开始把物品调入背包
goods_box_to_bag(PlayerId, ApplyList, GoodsStatus) ->
	Len = length(ApplyList),
	Counts = lists:seq(1,Len),
	NullCells = GoodsStatus#goods_status.null_cells,
	{Result, _NewPlayerId, _NewApplyList, NewNullCells} = 
		lists:foldl(fun handle_box_to_bag_each/2,{1, PlayerId, ApplyList,NullCells}, Counts),
	case Result of
		0 ->
			NewGoodsStatus = GoodsStatus;
		1 ->
			NewGoodsStatus = GoodsStatus#goods_status{null_cells = NewNullCells, 
													  box_remain_cells = GoodsStatus#goods_status.box_remain_cells + Len}
	end,
	{[Result], NewGoodsStatus}.

handle_box_to_bag_each(_Elem, AccIn) ->
	{Result, PlayerId, ApplyList, NullCells} = AccIn,
	case Result of
		0 ->
			{0, PlayerId, ApplyList, NullCells};
		1 ->
			[GoodsInfo|RestApplyList] = ApplyList,
			[Cell|RestNullCells] = NullCells,
			{GoodsId, GoodsNum} = GoodsInfo,
			case check_box_to_bag(GoodsId, GoodsNum,PlayerId) of
				{fail, _Res} ->
					{0, PlayerId, ApplyList, NullCells};
				{ok, NewGoodsInfo} ->
					db_agent:goods_box_to_bag(goods,[{cell, Cell}, {location, 4}],[{id,GoodsId}]),
					NewGoodsEts = NewGoodsInfo#goods{cell = Cell, location = 4},
					ets:insert(?ETS_GOODS_ONLINE, NewGoodsEts),
					{1, PlayerId, RestApplyList, RestNullCells}
			end
	end.

check_box_to_bag(GoodsId,GoodsNum,PlayerId) ->
	GoodsInfo = goods_util:get_goods(GoodsId),
	if
		%%物品不存在
		is_record(GoodsInfo, goods) =:= false ->
			{fail, 2};
		GoodsInfo#goods.player_id =/= PlayerId ->
			{fail, 3};
		GoodsInfo#goods.location =/= 7 ->
			{fail,4};
		GoodsInfo#goods.num =/= GoodsNum ->
			{fail, 5};
		true ->
			GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
			if
				is_record(GoodsTypeInfo, ets_base_goods) =:= false ->
					{fail, 4};
				true ->
					{ok, GoodsInfo}
			end
	end.

%% get_box_goods_by_gid(PlayerId, GoodsId,GoodsNum) ->
%% 	Pattern = #goods{id = GoodsId,player_id = PlayerId, num = GoodsNum, _ = '_'},
%% 	ets:match_object(Pattern).

%% %% -----------------------------------------------------------------
%% %% 28005 将物品丢弃
%% %% -----------------------------------------------------------------
%% discard_box_goods(PlayerId, GoodsPid, GoodsId, GoodsNum) ->
%% 	gen_server:call(GoodsPid, {'delete_box_goods', PlayerId, GoodsId, GoodsNum}).

%%检测是否能够删除该物品
check_delete_boxgoods(PlayerId, GoodsId, GoodsNum) ->
	GoodsInfo = goods_util:get_goods(GoodsId),
	if %物品不存在
		is_record(GoodsInfo, goods) =:= false ->
			{fail, 0};
		%%物品不属于该所有者
		GoodsInfo#goods.player_id =/= PlayerId ->
			{fail, 1};
		%%物品不是仓库的
		GoodsInfo#goods.location =/= 7 ->
			{fail, 2};
		%%物品数量出错
		GoodsInfo#goods.num =/= GoodsNum ->
			{fail, 3};
		true ->
			{ok, GoodsInfo}
	end.
%%删除合法的仓库内的物品（单个）
delete_box_goods(GoodsInfo, GoodsStatus) ->
	case GoodsInfo#goods.location =/= 7 of 
		ture when GoodsInfo#goods.id > 0 ->
			{fail,GoodsStatus};
		false  when GoodsInfo#goods.id > 0->
			lib_goods:delete_goods(GoodsInfo#goods.id),
			ets:delete(?ETS_GOODS_ONLINE, GoodsInfo#goods.id),
			NewGoodsStatus = 
				GoodsStatus#goods_status{box_remain_cells = GoodsStatus#goods_status.box_remain_cells+1},
			{ok, NewGoodsStatus};
		_ ->
			{fail,GoodsStatus}
	end.

%% %% -----------------------------------------------------------------
%% %% 28006 丢弃仓库中的所有物品
%% %% -----------------------------------------------------------------
%% discard_all_box_goods(PlayerId, GoodsPid) ->
%% 	gen_server:call(GoodsPid, {'delete_all_box_goods', PlayerId}).
%%删除合法的仓库内的物品(全部)
delete_all_box_goods(PlayerId, GoodsStatus) ->
	GoodsList = get_box_goods(PlayerId),
	%%启动额外的进程进行异步处理
	erlang:spawn(lib_goods, delete_all_box_goods, [PlayerId]),
	
	lists:foreach(fun(Goods) -> lib_goods:ets_delete_box_goods_attribute(Goods#goods.id) end, GoodsList),
	%%启动额外的进程进行异步处理
	erlang:spawn(lib_goods, delete_all_box_goods_attribute, [GoodsList]),
	Pattern = #goods{player_id = PlayerId, location = 7, _= '_'},
	ets:match_delete(?ETS_GOODS_ONLINE, Pattern),
	%%添加删除日志
	spawn(lib_box, delete_all_box_goods_log, [PlayerId, GoodsList]),
	NewGoodsStatus = GoodsStatus#goods_status{box_remain_cells = ?BOX_GOODS_STORAGE},
	{ok, NewGoodsStatus}.

%% -----------------------------------------------------------------
%% 28007 将所有物品放入背包
%% -----------------------------------------------------------------
%% put_all_goods_into_bag(PlayerId, GoodsPid) ->
%% 	ApplyList = get_all
%% 	ApplyLen = length(ApplyList),
%% 	BagNullNum = gen_server:call(GoodsPid,{'cell_num'}),
%% 	case ApplyLen > BagNullNum of
%% 		true ->
%% 			[2];
%% 		false ->		
%% 			gen_server:call(GoodsPid, {'all_goods_box_to_bag', PlayerId}).
%% 	end.
get_all_box_goodstobag_needed(PlayerId) ->
	Ms = ets:fun2ms(fun(T) when T#goods.player_id == PlayerId 
						 andalso T#goods.location == 7 ->
							{T#goods.id, T#goods.num}
					end),
	ets:select(?ETS_GOODS_ONLINE, Ms).


%% -----------------------------------------------------------------
%% 28008 获取仓库的容量
%% -----------------------------------------------------------------
%% get_box_remain_cells(GoodsPid) ->
%% 	gen_server:call(GoodsPid, {'get_box_storage'}).


%%获取下一个最近的N点时间(秒)（当前时刻的下一个0点）
check_outtime(N) ->
	{M, S, MS} = yg_timer:now(),
	{_, Time} = calendar:now_to_local_time({M, S, MS}),
	NowSecTime = calendar:time_to_seconds(Time),
	M * 1000000 + S - NowSecTime + ?ONE_DAY_SECONDS + N*3600.

%%获取诛邪需要的元宝额度
get_open_box_goldneeded(HoleType, OpenType) ->
	GoldNeededs = [{{1, 1},5},
				   {{1, 2}, 48},
				   {{1, 3}, 225},
				   {{2, 1}, 10},
				   {{2, 2}, 95},
				   {{2, 3}, 450},
				   {{3, 1}, 20},
				   {{3, 2}, 190},
				   {{3, 3}, 900},
				   {{4, 1}, 40},
				   {{4, 2}, 380},
				   {{4, 3}, 1800},
				   {{1, 4}, 0},
				   {{2, 4}, 0},
				   {{3, 4}, 0},
				   {{4, 4}, 100000}],
	{value, {_HoleType, GoldNeeded}} = lists:keysearch({HoleType, OpenType}, 1, GoldNeededs),
	GoldNeeded.

%%根据类型返回开诛邪的次数
set_OpenCount(OpenType) ->
	OpenCounts = [{1},
				  {10},
				  {50},
				  {20}],
	{OpenCount} = lists:nth(OpenType, OpenCounts),
	OpenCount.

%%每天周期性的更新一次物品表信息
mod_box_handle_update_action(Type, State) ->	
	   {{_Year, _Month, _Day}, {Hour, _Min, _Sec}} = calendar:local_time(),
	   case Type of
		   0 ->% 每天凌晨2点到4点之间,系统自动刷新
			   if
				   ((Hour >= 2) and (Hour =< 4)) ->
					   %%清理全服记录和玩家住些物品记录
%% 					   handle_update_trace(),
					   %%更新诛邪系统物品数据
					   handle_update_action_inner(State);
				   true ->
					   State
			   end;
		   1 ->%%主动执行的
			   handle_update_action_inner(State)
	   end.
	
mod_box_log_handle_update_action() ->
	{{_Year, _Month, _Day}, {Hour, _Min, _Sec}} = calendar:local_time(),
	% 每天凌晨2点到4点之间,系统自动刷新
	if
		((Hour >= 2) and (Hour =< 4)) ->
			%%清理全服记录和玩家住些物品记录
			handle_update_log();
		true ->
			no_action
	   end.

handle_update_action_inner(State) ->
	EtsBoxGoodsType = State#box_status.ets_box_goods_type,
	case EtsBoxGoodsType of
		1 ->
			%%先load数据
			load_all_box(2),
			NewStatus = load_all_box_goods_pro(2),
			%%再清数据		
%% 			timer:sleep(8000),
			ets:delete_all_objects(?ETS_BASE_BOX_GOODS_ONE),
			NewStatus;
			
		2 ->
			%%先load数据
			load_all_box(1),
			NewStatus = load_all_box_goods_pro(1),
			%%再清数据
%% 			timer:sleep(8000),
			ets:delete_all_objects(?ETS_BASE_BOX_GOODS_TWO),
			NewStatus
	end.
%% %%清理全服记录和玩家住些物品记录
%% handle_update_trace() ->
%% 	ets:delete_all_objects(?ETS_OPEN_BOXGOODS_TRACE).
handle_update_log() ->
	ets:delete_all_objects(?ETS_LOG_BOX_OPEN).



put_box_purple_time(PurpleTime) ->
	put(purple_time, PurpleTime).
get_box_purple_time() ->
	case get(purple_time) of
		undefined ->
			0;
		Value ->
			Value
	end.

put_box_open_counter(OpenCounter) ->
	put(box_open_counter, OpenCounter).
get_box_open_counter() ->
	case get(box_open_counter) of
		undefined ->
			0;
		Value ->
			Value 
	end.

put_box_purple_num(PurpleNum) ->
	put(purple_num, PurpleNum).
get_box_purple_num() ->
	case get(purple_num) of
		undefined ->
			0;
		Value ->
			Value
	end.
put_box_goods_trace(NewBoxGoodsTrace) ->
	put(box_goods_trace, NewBoxGoodsTrace).
get_box_goods_trace() ->
	case get(box_goods_trace) of
		undefined ->
			[];
		Value ->
			Value 
	end.
put_open_box_goods_type(Type) ->
	put(open_type, Type).
get_open_box_goods_type() ->
	case get(open_type) of
		undefined ->
			0;
		Value ->
			Value
	end.
%%一分钟内开除的紫装列表
get_purple_equip_list() ->
	case get(pelist) of
		undefined ->
			[];
		Value ->
			Value
	end.
put_purple_equip_list(PEList) ->
	put(pelist, PEList).
erase_purple_equip_list() ->
	erase(pelist).

make_purple_equip_list_record(NewPurpleGoods, PupleETList) ->
	case NewPurpleGoods of
		0 ->
			skip;
		_ ->
			NewPurpleEList = [NewPurpleGoods|PupleETList],
			put_purple_equip_list(NewPurpleEList),
			erlang:send_after(?PURPLE_EQUIP_LIST_TIMESTAMP, self(), {delete_purple_equip, NewPurpleGoods})
	end.
delete_purple_equip_list_record(NewPurpleGoods) ->
		PurpleEList = lib_box:get_purple_equip_list(),
		NewPurpleEList = lists:delete(NewPurpleGoods, PurpleEList),
		case NewPurpleEList of
			[] ->
				erase_purple_equip_list();
			_Other ->
				lib_box:put_purple_equip_list(NewPurpleEList)
		end.

 %%初始化诛邪中玩家的数据 
init_log_box_player(PlayerId) ->
	DataRecord = #ets_log_box_player{player_id = PlayerId,
									 purple_time = 0,
									 open_counter = 0,
									 purple_num = 0,
									 box_goods_trace = util:term_to_string([])},
	Table = log_box_player,
	spawn(fun()-> db_agent:insert_log_box_player(Table, DataRecord) end).

delete_box_player(PlayerId) ->
	db_agent:delete_log_box_player(PlayerId),
	ok.

get_player_box_goods(PlayerId) ->
	case db_agent:get_player_box_goods(PlayerId) of
		[] ->
			LogBoxPlayerRecord = #ets_log_box_player{player_id = PlayerId,
													 purple_time = 0,
													 open_counter = 0,
													 purple_num = 0,
													 box_goods_trace =  util:term_to_string([])},
			{0, LogBoxPlayerRecord};
		LogBoxPlayer ->
			LogBoxPlayerRecord = list_to_tuple([ets_log_box_player] ++ LogBoxPlayer),
			{1, LogBoxPlayerRecord}
	end.



%%计算开封印数据更新
%%更新开紫装的数据和时间
init_box_goods_player_info(PlayerId, LastLoginTime, Llast_login_time) ->
	{Type, LogBoxPlayerRecord} = lib_box:get_player_box_goods(PlayerId),
	case Type of
		1 ->%%数据库中已经有数据了
			case (LastLoginTime + 10*3600) div 86400 > (Llast_login_time + 10*3600) div 86400 of
				true ->
					NewBoxGoodsTrace = [],
					case (LastLoginTime - LogBoxPlayerRecord#ets_log_box_player.purple_time) > ?LIMIT_PURPLE_EQUIT_TIME 
						andalso LogBoxPlayerRecord#ets_log_box_player.purple_time =/= 0 of
						true ->
							PurpleTime = 0,
							spawn(fun()->db_agent:update_player_box_goods_trace_time_num(log_box_player, 
																			[{box_goods_trace, util:term_to_string([])}, 
																			 {purple_time, PurpleTime}], 
																			[{player_id, PlayerId}])end);
						false when LogBoxPlayerRecord#ets_log_box_player.purple_time =/= 0 ->
							PurpleTime = LogBoxPlayerRecord#ets_log_box_player.purple_time,
							spawn(fun()->db_agent:update_player_box_goods_trace_time_num(log_box_player, 
																			[{box_goods_trace, util:term_to_string([])}], 
																			[{player_id, PlayerId}])end),
							%%RemainTime时间后，出现紫装的标识位重新归零
							RemainTime = ?LIMIT_PURPLE_EQUIT_TIME - (LastLoginTime - PurpleTime),
							erlang:send_after(RemainTime*1000, self(), 'UPDATE_BOX_PURPLE_TIME');
						false ->
							PurpleTime = 0,
							spawn(fun()->db_agent:update_player_box_goods_trace_time_num(log_box_player, 
																			[{box_goods_trace, util:term_to_string([])}, 
																			 {purple_time, PurpleTime}], 
																			[{player_id, PlayerId}])end)
					end;
				false ->
					NewBoxGoodsTrace = util:string_to_term(tool:to_list(LogBoxPlayerRecord#ets_log_box_player.box_goods_trace)),
					case (LastLoginTime - LogBoxPlayerRecord#ets_log_box_player.purple_time) > ?LIMIT_PURPLE_EQUIT_TIME 
						andalso LogBoxPlayerRecord#ets_log_box_player.purple_time =/= 0 of
						true ->
							PurpleTime = 0,
							spawn(fun()->db_agent:update_player_box_goods_trace_time_num(log_box_player, 
																			[{purple_time, PurpleTime}], 
																			[{player_id, PlayerId}])end);
						false when LogBoxPlayerRecord#ets_log_box_player.purple_time =/= 0 ->
							PurpleTime = LogBoxPlayerRecord#ets_log_box_player.purple_time,
							%%RemainTime时间后，出现紫装的标识位重新归零
							RemainTime = ?LIMIT_PURPLE_EQUIT_TIME - (LastLoginTime - PurpleTime),
							erlang:send_after(RemainTime*1000, self(), 'UPDATE_BOX_PURPLE_TIME');
						false ->
							PurpleTime = 0
					end
			end,
			lib_box:put_box_purple_time(PurpleTime),
			lib_box:put_box_open_counter(LogBoxPlayerRecord#ets_log_box_player.open_counter),
			lib_box:put_box_purple_num(LogBoxPlayerRecord#ets_log_box_player.purple_num),
			lib_box:put_box_goods_trace(NewBoxGoodsTrace),
			%%对是否开过封印做标志
			lib_box:put_open_box_goods_type(1),		
			%%距离此刻最近的下一个0点，会把数据清空
			NextThreeTime = lib_box:check_outtime(0),
			Now = util:unixtime(),
			ReaminTime = NextThreeTime - Now,
			erlang:send_after(ReaminTime*1000, self(), 'UPDATE_BOX_GOODS_TRACE');
	_ ->%%之前都没有开过封印，因此不用更新数据
		%%对是否开过封印做标志
		lib_box:put_open_box_goods_type(0),
		  no_action
	end.

%%在开封印时获取诛邪的玩家数据，如果没有则初始化
%% 	GoodsTraceInit = lib_box:get_box_goods_trace(),
%% 	PlayerPurpleNum = lib_box:get_box_purple_num(),
%% 	OpenCounter = lib_box:get_box_open_counter(),
%% 	PurpleTime = lib_box:get_box_purple_time(),
%% 	NowTime = util:unixtime(),
%% 	case (NowTime - PurpleTime) > 1000*60 of
%% 		true ->
%% 			PurpleTimeType = 1;
%% 		false ->
%% 			PurpleTimeType = 0
%% 	end,
get_open_player_info(PlayerId) ->
	case get_open_box_goods_type() of
		0 ->
			%%向数据库新插数据
			init_log_box_player(PlayerId),
			
			%%数据初始定义
			PlayerPurpleNum = 0, 
			OpenCounter = 0, 
			PurpleTime = 0, 
			GoodsTraceInit = [],
			%%因为是第一次开封印，此值必为0
			PurpleTimeType = 0,
			
			lib_box:put_box_purple_time(PurpleTime),%%最近开出紫装的时间
			lib_box:put_box_open_counter(OpenCounter),%%封印开诛邪次数
			lib_box:put_box_purple_num(PlayerPurpleNum),%%在400次之前开出紫装的数量，数量达到2之后不再累加0
			lib_box:put_box_goods_trace(GoodsTraceInit),%%开封印限制级物品数量记录
			%%对是否开过封印做标志
			lib_box:put_open_box_goods_type(1),
			
			
			%%距离此刻最近的下一个0点，会把数据清空
			NextThreeTime = lib_box:check_outtime(0),
			Now = util:unixtime(),
			ReaminTime = NextThreeTime - Now,
			erlang:send_after(ReaminTime*1000, self(), 'UPDATE_BOX_GOODS_TRACE');
		_ ->
			GoodsTraceInit = lib_box:get_box_goods_trace(),
			PlayerPurpleNum = lib_box:get_box_purple_num(),
			OpenCounter = lib_box:get_box_open_counter(),
			%%对是否开过封印做标志
			lib_box:put_open_box_goods_type(1),
%% 			NowTime = util:unixtime(),
			%%是否在20秒内做限制
			PurpleTimeType = 0	%%目前不做限制了
%% 			case (NowTime - PurpleTime) > ?LIMIT_PURPLE_EQUIT_TIME of
%% 				true ->
%% 					PurpleTimeType = 0;
%% 				false ->
%% 					PurpleTimeType = 1
%% 			end		
	end,
	{PlayerPurpleNum, OpenCounter, PurpleTimeType, GoodsTraceInit}.

update_box_goods_trace(BoxGoodsTrace, NewPurpleNum, PlayerPurpleNum, NewOpenBoxCount, PlayerId) ->
	case BoxGoodsTrace of
		{init, _BoxGoodsTraceUpdate} ->
			lib_box:handle_box_goods_trace_result_a(NewPurpleNum, PlayerPurpleNum, 
													NewOpenBoxCount, PlayerId);
		{update, BoxGoodsTraceUpdate} ->
			lib_box:handle_box_goods_trace_result_b(NewPurpleNum, BoxGoodsTraceUpdate, 
													PlayerPurpleNum, NewOpenBoxCount, PlayerId)
	end.


handle_box_goods_trace_result_a(NewPurpleNum, PlayerPurpleNum, NewOpenBoxCount, PlayerId) ->
	if NewPurpleNum == 1 ->
		   NewPurpleTime = util:unixtime(),
		   lib_box:put_box_purple_num(PlayerPurpleNum+1),
		   lib_box:put_box_open_counter(NewOpenBoxCount),
		   lib_box:put_box_purple_time(NewPurpleTime),
		   %%LIMIT_PURPLE_EQUIT_TIME时间后，出现紫装的标识位重新归零
		   erlang:send_after(?LIMIT_PURPLE_EQUIT_TIME * 1000, self(), 'UPDATE_BOX_PURPLE_TIME'),
		   db_agent:update_player_box_goods_trace_time_num(log_box_player, 
														   [{purple_num, PlayerPurpleNum+1},
															{open_counter, NewOpenBoxCount},
															{purple_time, NewPurpleTime}], 
														   [{player_id, PlayerId}]);
	   true ->
		   lib_box:put_box_open_counter(NewOpenBoxCount),
		   db_agent:update_player_box_goods_trace_time_num(log_box_player, 
														   [{open_counter, NewOpenBoxCount}],
														   [{player_id, PlayerId}])
	end.

handle_box_goods_trace_result_b(NewPurpleNum, BoxGoodsTraceUpdate, PlayerPurpleNum, NewOpenBoxCount, PlayerId) ->
	if NewPurpleNum == 1 ->
		   NewPurpleTime = util:unixtime(),
		   lib_box:put_box_purple_time(NewPurpleTime),
		   %%LIMIT_PURPLE_EQUIT_TIME时间后，出现紫装的标识位重新归零
		   erlang:send_after(?LIMIT_PURPLE_EQUIT_TIME * 1000, self(), 'UPDATE_BOX_PURPLE_TIME'),
		   lib_box:put_box_goods_trace(BoxGoodsTraceUpdate),
		   lib_box:put_box_purple_num(PlayerPurpleNum+1),
		   lib_box:put_box_open_counter(NewOpenBoxCount),
		   db_agent:update_player_box_goods_trace_time_num(log_box_player, 
														   [{box_goods_trace, util:term_to_string(BoxGoodsTraceUpdate)},
															{purple_num, PlayerPurpleNum+1},
															{open_counter, NewOpenBoxCount},
															{purple_time, NewPurpleTime}], 
														   [{player_id, PlayerId}]);
	   true ->
		   lib_box:put_box_goods_trace(BoxGoodsTraceUpdate),
		   lib_box:put_box_open_counter(NewOpenBoxCount),
		   db_agent:update_player_box_goods_trace_time_num(log_box_player, 
														   [{box_goods_trace, util:term_to_string(BoxGoodsTraceUpdate)},
															{open_counter, NewOpenBoxCount}],
														   [{player_id, PlayerId}])
	end.

%%
%% Local Functions
%%
get_holetype_name(HoleType) ->
	HoleTypeName = [{"百年"},
					{"千年"},
					{"万年"},
					{"远古"}],
	{Value} = lists:nth(HoleType, HoleTypeName),
	Value.
%%诛邪仓库删除所有的物品，记录日志
delete_all_box_goods_log(PlayerId, GoodsList) ->
	ThrowTime = util:unixtime(),
	handle_delete_box_goods_log(ThrowTime, PlayerId, GoodsList).

handle_delete_box_goods_log(_ThrowTime, _PlayerId, []) ->
	ok;
handle_delete_box_goods_log(ThrowTime, PlayerId, [Goods|GoodsList]) ->
	delete_box_goods_log(ThrowTime, PlayerId, Goods),
	handle_delete_box_goods_log(ThrowTime, PlayerId, GoodsList).
	
%%诛邪仓库删除单个物品做记录日志
delete_box_goods_log(ThrowTime, PlayerId, Goods) ->
	#goods{id = GoodsId,
		   goods_id = GoodsTypeId,
		   num = Num} = Goods,
	ValueList = [ThrowTime, PlayerId, GoodsId, GoodsTypeId, Num],
	FieldList = [time, player_id, gid, goods_id, num],
	spawn(fun()-> db_agent:insert_box_goods_log(log_box_throw, ValueList, FieldList) end).
	