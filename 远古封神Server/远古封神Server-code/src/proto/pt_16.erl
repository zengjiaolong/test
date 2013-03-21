%%%-----------------------------------
%%% @Module  : pt_16
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 16坐骑信息 
%%%-----------------------------------
-module(pt_16).
-include("common.hrl").
-include("record.hrl").
-export([read/2, write/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%% 获取坐骑详细信息  ps暂保留
read(16001, <<MountId:32>>) ->
    {ok, MountId};

%% 坐骑状态切换
read(16002, <<MountId:32>>) ->
    {ok, MountId};

%% 卸下坐骑
read(16003,_) ->
	{ok,mountOff};

%%购买飞行坐骑
read(16010,<<GoodsId:32>>)->
	{ok,[GoodsId]};

%%查看新版坐骑信息
read(16012, <<MountId:32>>) ->
    {ok, MountId};

%%查看新版坐骑列表
read(16013, _) ->
    {ok, []};

%% 出战坐骑亲密度自动增长
read(16014,<<MountId:32>>) ->
	{ok,[MountId]};

%%坐骑出战,休息 
%% Type 0为休息 1为出战  2坐骑丢弃
read(16015,<<MountId:32,Type:8>>) ->
	{ok,[MountId,Type]};

%% 坐骑喂养
read(16016, <<PetId:32, Food_type:32, GoodsNum:16 >>) ->
    {ok, [PetId, Food_type, GoodsNum]};

%% 坐骑改名
read(16017, <<MountId:32, Bin/binary>>) ->
    {NewName, _} = pt:read_string(Bin),
    {ok, [MountId, NewName]};

%% 坐骑乘骑
read(16018, <<MountId:32>>) ->
    {ok, [MountId]};

%%坐骑进阶界面信息
read(16019, <<MountId:32>>) ->
    {ok, MountId};

%%坐骑进阶操作
read(16020, <<MountId:32,Goods_id:32,Auto_purch:8>>) ->
    {ok, [MountId,Goods_id,Auto_purch]};

%%坐骑兽魄驯化界面信息
read(16021, <<MountId:32>>) ->
    {ok, MountId};

%%坐骑兽魄驯化操作
read(16022, <<MountId:32,Auto_purch:8>>) ->
    {ok, [MountId,Auto_purch]};

%%坐骑猎魂技能列表
read(16023, _) ->
    {ok, []};

%%坐骑五个按钮信息
read(16024, _) ->
    {ok, []};

%%设置自动萃取颜色设置
read(16025,<<Auto_Atep:8>>) ->
    {ok, Auto_Atep};

%%点击按钮产生技能按钮顺序从1-5
read(16026,<<Btn_Order:8>>) ->
    {ok, Btn_Order};

%%技能拖动类型(UpDown 1为从上面拉到下面,2从下面拉到上面,3为闲置技能左右拖动坐骑技能不能左右拖动,Type1为技能合并预览，2为正式技能合并
read(16027,<<MountId:32,UpDown:8,Type:8,Id1:32,Id2:32>>) ->
    {ok, [MountId,UpDown,Type,Id1,Id2]};

%%用元宝激活按钮4
read(16028,_) ->
    {ok, []};

%%萃取
read(16029,<<MountSkillSplitId:32>>) ->
    {ok, MountSkillSplitId};

%%一键萃取
read(16030,_) ->
    {ok, []};

%%卖出
read(16031,<<MountSkillSplitId:32>>) ->
    {ok, MountSkillSplitId};

%%一键卖出
read(16032,_) ->
    {ok, []};

%%一键吞噬 
read(16033,_) ->
    {ok, []};

%%添加技能经验 坐骑技能位置(1-8)
read(16034,<<MountId:32,Pos:8>>) ->
    {ok, [MountId,Pos]};

%%坐骑图鉴列表
read(16035,_) ->
    {ok, []};

%%坐骑展示
read(16037,<<MountId:32>>) ->
    {ok, MountId};

%%一键猎魂
read(16038,_) ->
    {ok, []};

%% 坐骑图鉴切换
read(16039, <<MountId:32,GoodsTypeId:32>>) ->
    {ok, [MountId,GoodsTypeId]};

%% 坐骑闲置技能查看
read(16040, <<MountSkillSplitId:32>>) ->
    {ok, [MountSkillSplitId]};

%%斗兽面板
read(16042,_)->
	{ok,[]};

%%斗兽竞技
read(16044,<<MyId:32,EnemyId:32>>)->
	{ok,[MyId,EnemyId]};

%%斗兽竞技榜
read(16045,_)->
	{ok,[]};

%%增加挑战次数
read(16046,_)->
	{ok,[]};


%%请求战报，返回16044的内容
read(16047,<<BattleId:32>>)->
	{ok,[BattleId]};

%%领取奖励
read(16048,<<>>) ->
	%%?DEBUG("read 16048,,,,,,,,,,,,,,,,~n",[]),
	{ok,[]};

read(_Cmd, _R) ->
    {error, no_match}.


%%
%%服务端 -> 客户端 -------------------------------
%%
%% 获取坐骑详细信息 ps暂无保留
write(16001, [Res, MountId, MountTypeId, BindState, UseState]) ->
    {ok, pt:pack(16001, <<Res:16, MountId:32, MountTypeId:32, BindState:16, UseState:16>>)};

%% 乘上坐骑
write(16002, [Res, MountId, MountType,NewSpeed]) ->
    {ok, pt:pack(16002, <<Res:16, MountId:32, MountType:32,NewSpeed:16>>)};

%% 卸下坐骑
write(16003,[Res,NewSpeed]) ->
	{ok,pt:pack(16003,<<Res:16,NewSpeed:16>>)};

%%快捷栏去掉坐骑
write(16009,[MountId,GoodsTypeId])->
	{ok,pt:pack(16009,<<MountId:32,GoodsTypeId:32>>)};

%%购买坐骑
write(16010,[Res])->
	{ok,pt:pack(16010,<<Res:16>>)};


%%查看新版坐骑信息
write(16012,Mount)->
	BinData = parse_mount_info(Mount),
    {ok, pt:pack(16012, BinData)};

%%查看新版坐骑列表
write(16013,MountList)->
	ListNum = length(MountList),
	if ListNum == 0 ->
		   Data = <<0:16, <<>>/binary>>;
	   true ->
		   ListBin = tool:to_binary(lists:map(fun(Mount)-> parse_mount_info(Mount) end,MountList)),
		   Data = <<ListNum:16, ListBin/binary>>
	end,
    {ok, pt:pack(16013, Data)};

%%出战坐骑亲密度自动增长
write(16014,[Res])->
	{ok,pt:pack(16014,<<Res:8>>)};

%%坐骑出战,休息 
%% Type 1为出战。0为休息
write(16015,[Res])->
	{ok,pt:pack(16015,<<Res:8>>)};

%%坐骑喂养
write(16016,[Res])->
	{ok,pt:pack(16016,<<Res:8>>)};

%%坐骑改名
write(16017,[Res,MountId,NewName])->
	Name = tool:to_binary(NewName),
	Name_len = byte_size(Name),
	{ok,pt:pack(16017,<<Res:8,MountId:32,Name_len:16,Name/binary>>)};

%% 乘上坐骑
write(16018, [Res, MountId, MountType,NewSpeed]) ->
    {ok, pt:pack(16018, <<Res:8, MountId:32, MountType:32,NewSpeed:16>>)};

%% 坐骑进阶界面信息
write(16019, [Res,MountId,MountTypeId,Name,NewStep,NewSpeed,TotalValue,Goods_id,Num,Coin,Luck_val,Max_Luck_val]) ->
	Name1 = tool:to_binary(Name),
	Name_len = byte_size(Name1),
    {ok, pt:pack(16019, <<Res:8, MountId:32, MountTypeId:32,Name_len:16,Name1/binary,NewStep:8,NewSpeed:16,TotalValue:16,Goods_id:32,Num:16,Coin:32,Luck_val:32,Max_Luck_val:32>>)};

%% 坐骑进阶操作
write(16020, [Res,Gold,Coin,Bcoin]) ->
    {ok, pt:pack(16020, <<Res:8,Gold:32,Coin:32,Bcoin:32>>)};


%% 坐骑兽魄驯化界面信息
write(16021, [Res,Goods_id,Num,Cost]) ->
    {ok, pt:pack(16021, <<Res:8,Goods_id:32,Num:16,Cost:32>>)};

%% 坐骑兽魄驯化提升
write(16022, [Res,Gold,Coin,Bcoin]) ->
    {ok, pt:pack(16022, <<Res:8,Gold:32,Coin:32,Bcoin:32>>)};

%%坐骑猎魂技能列表
write(16023,ResultList)->
	ResultLen = length(ResultList),
	if ResultLen == 0 ->
		   Data = <<0:16, <<>>/binary>>;
	   true ->
			F = fun(MountSkillSplitInfo) ->
						Id = MountSkillSplitInfo#ets_mount_skill_split.id,
						SkillId = MountSkillSplitInfo#ets_mount_skill_split.skill_id, 
						Exp = MountSkillSplitInfo#ets_mount_skill_split.exp, 
						Color = MountSkillSplitInfo#ets_mount_skill_split.color, 
						Level = MountSkillSplitInfo#ets_mount_skill_split.level,
						Type = MountSkillSplitInfo#ets_mount_skill_split.type, 
						NextSkillExp = data_mount:get_skill_upgrade_exp(Level,Color),
						EffectValue = data_mount:get_skill_prop(SkillId,Level),
						<<Id:32,SkillId:32,Exp:32,NextSkillExp:32,Color:8,Level:8,Type:8,EffectValue:16>>
				end,
			ListBin = tool:to_binary([F(MountSkillSplitInfo) || MountSkillSplitInfo <- ResultList]),
		   Data = <<ResultLen:16, ListBin/binary>>
	end,
    {ok, pt:pack(16023, Data)};

%% 坐骑五个按钮信息
write(16024, [MountSkillExpInfo,Cash]) ->
	if is_record(MountSkillExpInfo, ets_mount_skill_exp) ->
		   Total_exp = MountSkillExpInfo#ets_mount_skill_exp.total_exp,
		   Auto_step = MountSkillExpInfo#ets_mount_skill_exp.auto_step,
		   Btn_1 = MountSkillExpInfo#ets_mount_skill_exp.btn_1,
		   Btn_2 = MountSkillExpInfo#ets_mount_skill_exp.btn_2,
		   Btn_3 = MountSkillExpInfo#ets_mount_skill_exp.btn_3,
		   Btn_4 = MountSkillExpInfo#ets_mount_skill_exp.btn_4,
		   Btn_5 = MountSkillExpInfo#ets_mount_skill_exp.btn_5,
		   Btn4_type = MountSkillExpInfo#ets_mount_skill_exp.btn4_type,
		   Btn5_type = MountSkillExpInfo#ets_mount_skill_exp.btn5_type,
		   {ok, pt:pack(16024, <<Total_exp:32,Auto_step:8,Btn_1:8,Btn_2:8,Btn_3:8,Btn_4:8,Btn_5:8,Btn4_type:8,Btn5_type:8,Cash:32>>)};
	   true ->
		   {ok, pt:pack(16024, <<0:32,1:8,1:8,0:8,0:8,0:8,0:8,0:8,0:8,Cash:32>>)}
	end;

%%设置自动萃取颜色
write(16025,[Res])->
	{ok,pt:pack(16025,<<Res:8>>)};

%%点击按钮产生技能按钮顺序从1-5
write(16026, [Res,SkillId,Color,Pos,Gold,Coin,Bcoin]) ->
    {ok, pt:pack(16026, <<Res:8,SkillId:32,Color:8,Pos:8,Gold:32,Coin:32,Bcoin:32>>)};

%% 技能拖动
write(16027,[Code,Desc])->
	BinDesc = tool:to_binary(Desc),
	BinDesc_len = byte_size(BinDesc),
	{ok,pt:pack(16027,<<Code:8,BinDesc_len:16,BinDesc/binary>>)};

%%用元宝激活按钮4
write(16028, [Res,Gold,Coin,Bcoin]) ->
    {ok, pt:pack(16028, <<Res:8,Gold:32,Coin:32,Bcoin:32>>)};

%%萃取
write(16029,[Res])->
	{ok,pt:pack(16029,<<Res:8>>)};

%%一键萃取
write(16030,[Res])->
	{ok,pt:pack(16030,<<Res:8>>)};

%%卖出
write(16031,[Res])->
	{ok,pt:pack(16031,<<Res:8>>)};

%%一键卖出
write(16032,[Res])->
	{ok,pt:pack(16032,<<Res:8>>)};

%%一键吞噬
write(16033,[Res])->
	{ok,pt:pack(16033,<<Res:8>>)};

%% 技能拖动
write(16034,[Code,Desc])->
	BinDesc = tool:to_binary(Desc),
	BinDesc_len = byte_size(BinDesc),
	{ok,pt:pack(16034,<<Code:8,BinDesc_len:16,BinDesc/binary>>)};

%%坐骑图鉴列表
write(16035,ResultList)->
	ResultLen = length(ResultList),
	if ResultLen == 0 ->
		   Data = <<0:16, <<>>/binary>>;
	   true ->
			F = fun(MountTypeId) ->
						Name = tool:to_binary(data_mount:get_name_by_goodsid(MountTypeId)),
						Name_len = byte_size(Name),
						<<MountTypeId:32,Name_len:16,Name/binary>>						
				end,
			ListBin = tool:to_binary([F(MountTypeId) || MountTypeId <- ResultList]),
		   Data = <<ResultLen:16, ListBin/binary>>
	end,
    {ok, pt:pack(16035, Data)};

%%坐骑加经验
write(16036, Exp) ->
    {ok, pt:pack(16036, <<Exp:32>>)};

%%查看新版坐骑信息(在线不在线两种)
write(16037,Mount)->
	BinData = parse_mount_info(Mount),
    {ok, pt:pack(16037, BinData)};

%%一键猎魂
write(16038, [Res,SkillId,Gold,Coin,Bcoin]) ->
    {ok, pt:pack(16038, <<Res:8,SkillId:32,Gold:32,Coin:32,Bcoin:32>>)};

%% 坐骑图鉴切换
write(16039,[Res,GoodsTypeId])->
	{ok,pt:pack(16039,<<Res:8,GoodsTypeId:32>>)};

%% 坐骑闲置技能查看
write(16040,MountSkillSplitInfo)->
	if MountSkillSplitInfo == [] ->
		   {ok,pt:pack(16040,<<0:32,0:32,0:32,0:32,0:8,0:8,0:8,0:16>>)};
	   true ->
		   Id = MountSkillSplitInfo#ets_mount_skill_split.id,
		   SkillId = MountSkillSplitInfo#ets_mount_skill_split.skill_id,
		   Exp = MountSkillSplitInfo#ets_mount_skill_split.exp,
           Color = MountSkillSplitInfo#ets_mount_skill_split.color,
		   Level = MountSkillSplitInfo#ets_mount_skill_split.level,
		   Type = MountSkillSplitInfo#ets_mount_skill_split.type,
		   NextSkillExp = data_mount:get_skill_upgrade_exp(Level,Color),
		   EffectValue = data_mount:get_skill_prop(SkillId,Level),
		   {ok,pt:pack(16040,<<Id:32,SkillId:32,Exp:32,NextSkillExp:32,Color:8,Level:8,Type:8,EffectValue:16>>)}
	end;


%% 坐骑通知信息(黄色中间显示)
write(16041,[Desc])->
	BinDesc = tool:to_binary(Desc),
	BinDesc_len = byte_size(BinDesc),
	{ok,pt:pack(16041,<<BinDesc_len:16,BinDesc/binary>>)};

%%斗兽面板
write(16042,[Res,My,Mr,FourRankers])->
	if Res =:= 1 ->
		   F_rankers = fun(Ranker)->
							   Pid = Ranker#ets_mount_arena.player_id,
							   Mid = Ranker#ets_mount_arena.mount_id,
							   Pname = tool:to_binary(Ranker#ets_mount_arena.player_name),
							   Mname = tool:to_binary(lib_mount_arena:get_name_by_step(Ranker#ets_mount_arena.mount_step,Ranker#ets_mount_arena.mount_typeid)),
							   Prealm = Ranker#ets_mount_arena.realm,
							   Mstep = Ranker#ets_mount_arena.mount_step,
							   Mrank = Ranker#ets_mount_arena.rank,
							   Mtype = Ranker#ets_mount_arena.mount_typeid,
							   Mcolor = Ranker#ets_mount_arena.mount_color,
							   Pname_len = byte_size(Pname),
							   Mname_len = byte_size(Mname),
							   <<Pid:32, Mid:32, Pname_len:16, Pname/binary, Mname_len:16, Mname/binary, Prealm:8, Mstep:8, Mrank:16, Mtype:32, Mcolor:8>>
					   end,
		   RankersBin = tool:to_binary([F_rankers(Ranker) || Ranker <- FourRankers]),
		   RankersLen = length(FourRankers),
		   RecentList = Mr#ets_mount_recent.recent,
		   F_recent = fun(Recent)->
							  if Recent =:= [] ->
									 <<0:16,<<>>/binary,0:32>>;
								 true ->
									 {Time,String,BattleId} = Recent,
									 
									 Str = lib_mount_arena:make_recent_time(Time,String),
									 Strbin = tool:to_binary(Str),
									 Len = byte_size(Strbin),
									 <<Len:16, Strbin/binary, BattleId:32>>
							  end
					  end,
		   if length(RecentList) =:= 0 ->
				  RecentBin = <<>>,
				  RecentLen = 0;
			  true ->
				  RecentBin = tool:to_binary([F_recent(Recent) || Recent <- RecentList]),
				  RecentLen = length(RecentList)
		   end,
		   {Mname,Mtitle,Mid,Mstep,Mval,Mwin,Mrank,Mcge,Mgold_cge,Mct,Mtype,Mcolor} = {tool:to_binary(lib_mount_arena:get_name_by_step(My#ets_mount_arena.mount_step,My#ets_mount_arena.mount_typeid)),
														  tool:to_binary(My#ets_mount_arena.mount_title),
														  My#ets_mount_arena.mount_id,My#ets_mount_arena.mount_step,My#ets_mount_arena.mount_val,
														  My#ets_mount_arena.win_times,My#ets_mount_arena.rank,
														  Mr#ets_mount_recent.cge_times,Mr#ets_mount_recent.gold_cge_times,mod_mount_arena:display_award(My#ets_mount_arena.mount_id),
														  My#ets_mount_arena.mount_typeid,My#ets_mount_arena.mount_color},
		   Mname_len = byte_size(Mname),
		   Mtitle_len = byte_size(Mtitle),
		   Straw = tool:to_binary(lib_mount_arena:award_rule_comment(My#ets_mount_arena.rank_award)),
		   Straw_len = byte_size(Straw),
		   {ok,pt:pack(16042,<<Res:8,Mname_len:16,Mname/binary,Mtitle_len:16,Mtitle/binary,Mid:32,Mstep:8,Mval:32,Mwin:16,Mrank:16,Mcge:16,Mgold_cge:16,Mct:32,
						RankersLen:16,RankersBin/binary,RecentLen:16,RecentBin/binary,Mtype:32,Mcolor:8,Straw_len:16,Straw/binary>>)};
	   true ->
		   {ok,pt:pack(16042,<<Res:8,0:16,<<>>/binary,0:16,<<>>/binary,0:32,0:8,0:32,0:16,0:16,0:16,0:16,0:32,0:16,<<>>/binary,0:16,<<>>/binary,0:32,0:8,0:16,<<>>/binary>>)}
	end;

%%斗兽战斗初始数据
%%  Array{  坐骑战斗属性，第一个是自己坐骑属性，第二个是对方坐骑属性
%%     int:32 气血
%%     int:32 攻击
%%     int:32 防御
%%     int:32 命中
%%     int:32 闪避
%%     int:32 暴击
%%     int:32 速度
%%     int:32 风抗
%%     int:32 水抗
%%     int:32 火抗
%%     int:32 土抗
%%     int:32 雷抗
%%     int:32 战斗力
%%   }
write(16043, List)->
	F = fun(Elem) ->
				{Hp,Atk,Def,Hit,Dodge,Crict,Speed,Awind,Awater,Afire,Asoil,Athunder,Mval} = Elem,
				<<Hp:32,Atk:32,Def:32,Hit:32,Dodge:32,Crict:32,Speed:32,Awind:32,Awater:32,Afire:32,Asoil:32,Athunder:32,Mval:32>>
		end,
	if length(List) =:= 0 ->
		   ArrLen = 0,
		   ArrBin = <<>>;
	   true ->
		   ArrLen = length(List),
		   ArrBin = tool:to_binary([F(E) || E <- List])
	end,
	{ok,pt:pack(16043,<<ArrLen:16,ArrBin/binary>>)};

%%斗兽竞技
write(16044, [Result,MyMId,MyName,MyMountName,MyColor,EtkMId,EName,EMountName,EColor,BattleList,MyType,EType]) ->
%% 	?DEBUG("Result = ~p,MyMId = ~p,MyName = ~p,MyMountName = ~p,MyColor = ~p,EtkMId = ~p,EName = ~p,EMountName = ~p,EColor = ~p~n",[Result,MyMId,MyName,MyMountName,MyColor,EtkMId,EName,EMountName,EColor]),
	Mybin = tool:to_binary(MyName),
	Mylen = byte_size(Mybin),
	Ebin = tool:to_binary(EName),
	Elen = byte_size(Ebin),
	Mmbin = tool:to_binary(MyMountName),
	Mmlen = byte_size(Mmbin),
	Embin = tool:to_binary(EMountName),
	Emlen = byte_size(Embin),
	F = fun(B) ->
			{AtkMid,MSkillName,MSkillType,MSkillValue,Ahp,ESName,ESType,ESValue,Bhp,AttType,Hurt} = B,
			Msbin = tool:to_binary(MSkillName),
			Mslen = byte_size(Msbin),
			Esbin = tool:to_binary(ESName),
			Eslen = byte_size(Esbin),
%% 			?DEBUG("AtkMid = ~p ,MSkillName = ~p ,MSkillType = ~p ,MSkillValue = ~p ,ESName = ~p ,ESType = ~p ,ESValue = ~p ,AttType = ~p ,Hurt = ~p~n ",[AtkMid,MSkillName,MSkillType,MSkillValue,ESName,ESType,ESValue,AttType,Hurt]),
			<<AtkMid:32,Mslen:16,Msbin/binary,MSkillType:16,MSkillValue:16,Ahp:32,Eslen:16,Esbin/binary,ESType:16,ESValue:16,Bhp:32,AttType:8,Hurt:32>>
		end,
	{ArrLen,ArrBin} =
		case length(BattleList) of
			0 ->
				%%?DEBUG("BattleList data is empty!!!!!",[]),
				{0,<<>>};
			L ->
			%%?DEBUG("BattleList length = ~p~n!!!!!",[L]),
			   {L,tool:to_binary([F(B) || B <- BattleList])}
		end,
	{ok,pt:pack(16044, <<Result:8,MyMId:32,Mylen:16,Mybin/binary,Mmlen:16,Mmbin/binary,MyColor:8,EtkMId:32,
						 Elen:16,Ebin/binary,Emlen:16,Embin/binary,EColor:8,ArrLen:16,ArrBin/binary,MyType:32,EType:32>>)};

%%斗兽竞技榜
write(16045, Ranks)->
	F = fun(R)->
				[Pname,Pid,Prealm,Mname,Mid,Mcolor,Mlv,Mval,Mstep,Mrank,Mr]=[R#ets_mount_arena.player_name,R#ets_mount_arena.player_id,
																			 R#ets_mount_arena.realm,R#ets_mount_arena.mount_name,R#ets_mount_arena.mount_id,
																			 R#ets_mount_arena.mount_color,R#ets_mount_arena.mount_level,
																			 R#ets_mount_arena.mount_val,R#ets_mount_arena.mount_step,
																			 R#ets_mount_arena.rank,R#ets_mount_arena.recent_win],
				Pbin = tool:to_binary(Pname),
				Plen = byte_size(Pbin),
				Mbin = tool:to_binary(Mname),
				Mlen = byte_size(Mbin),
				<<Plen:16,Pbin/binary,Pid:32,Prealm:8,Mlen:16,Mbin/binary,Mid:32,Mcolor:8,Mlv:16,Mval:32,Mstep:8,Mrank:8,Mr:8>>
		end,
	if length(Ranks) =:= 0 ->
		   Alen = 0,
		   Abin = <<>>;
	   true ->
		   Alen = length(Ranks),
		   Abin = tool:to_binary([F(R) || R<-Ranks])
	end,
	%%?DEBUG("PT_16 Alen = ~p",[Alen]),
	{ok, pt:pack(16045, <<Alen:16,Abin/binary>>)};

%%增加挑战次数
write(16046, Res)->
	{ok, pt:pack(16046, <<Res:8>>)};

%%领取奖励
write(16048, Res)->
	{ok, pt:pack(16048, <<Res:8>>)};

%%挑战奖励
write(16049,[Res,Cash,Bcoin])->
	{ok, pt:pack(16049, <<Res:8,Cash:16,Bcoin:16>>)};

write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

%%坐骑信息打包处理
parse_mount_info(Mount) ->
	if 
		is_record(Mount,ets_mount) ->
			GoodsInfo = goods_util:get_goods(Mount#ets_mount.id),
			if is_record(GoodsInfo,goods) == false ->
				  GoodsInfo1 = goods_util:get_goods_by_id(Mount#ets_mount.id),
				  if is_record(GoodsInfo1,goods) == false ->
						 NewSpeed = 0;
					 true ->
						 NewSpeed = GoodsInfo1#goods.speed
				  end;
			   true ->
				  GoodsInfo1 =  GoodsInfo,
				  NewSpeed = GoodsInfo1#goods.speed
			end,
			
			ResultList = data_mount:get_prop_mount(Mount),
			[Hp,Mp,Att,Def,Hit,Dodge,Crit,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil] = ResultList,
			Batt_val = data_mount:count_mount_batt(ResultList),
			[TotalValue,_Average,MaxVlaue] = data_mount:get_4sp_val(Mount#ets_mount.step),%%兽魄总值，最大兽魄值
			Mount_id = Mount#ets_mount.id,                          %% 主键	
      		Player_id = Mount#ets_mount.player_id,                   %% 角色id	
      		Goods_id = Mount#ets_mount.goods_id,                    %% 品物类型id	
     		Name = tool:to_binary(Mount#ets_mount.name),           %% 字名	
      		Level = Mount#ets_mount.level,                             %% 等级	
      		Exp = Mount#ets_mount.exp,                                %% 经验	
			LevelExp = data_mount:get_level_need_exp(Mount#ets_mount.level), %% 本等级经验
      		Luck_val = Mount#ets_mount.luck_val,                      %% 幸运值	
			Max_Luck_val = data_mount:get_max_luck_val(Mount#ets_mount.step),%%最大幸运值
      		Close = Mount#ets_mount.close,                             %% 亲密度	
      		Step = Mount#ets_mount.step,                              %% 阶数	
      		Speed = NewSpeed,                           %% 速度	
      		Title = tool:to_binary(Mount#ets_mount.title),              %% 称号	
      		Color = Mount#ets_mount.color,                              %% 品质(白1	绿2蓝3金4紫5)	
      		Stren = Mount#ets_mount.stren,                              %%  强化等级	
      		Lp = Mount#ets_mount.lp,                                    %% 力魄
      		Xp = Mount#ets_mount.xp,                                 %% 心魄	
      		Tp = Mount#ets_mount.tp,                                 %% 体魄	
      		Qp = Mount#ets_mount.qp,                                 %% 气魄	
			Skill = pack_mount_skill(Mount),                             %% 技能[Id等级,阶数,经验],	
      		Status = Mount#ets_mount.status,                          %%  0休息1出战	
      		Icon = Mount#ets_mount.icon,                               %% 显示图形	
      		Ct = Mount#ets_mount.ct;                                   %% 创建时间	
		true ->
			[Hp,Mp,Att,Def,Hit,Dodge,Crit,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil] = [0,0,0,0,0,0,0,0,0,0,0,0],
			Batt_val = 0,
			[TotalValue,_Average,MaxVlaue] = data_mount:get_4sp_val(1),%%兽魄总值，最大兽魄值
			Mount_id = 0,                          %% 主键	
      		Player_id = 0,                          %% 角色id	
      		Goods_id = 0,                           %% 品物类型id	
     		Name = <<>>,                              %% 字名	
      		Level = 0,                              %% 等级	
      		Exp = 0,                                %% 经验
			LevelExp = data_mount:get_level_need_exp(1), %% 本等级经验
      		Luck_val = 0,                           %% 幸运值
			Max_Luck_val = data_mount:get_max_luck_val(1),%%最大幸运值
      		Close = 0,                              %% 亲密度	
      		Step = 0,                               %% 阶数	
      		Speed = 0,                              %% 速度	
      		Title = <<>>,                             %% 称号	
      		Color = 0,                              %% 品质(白1	绿2蓝3金4紫5)	
      		Stren = 0,                              %%  强化等级	
      		Lp = 0,                                 %% 力魄	
      		Xp = 0,                                 %% 心魄	
      		Tp = 0,                                 %% 体魄	
      		Qp = 0,                                 %% 气魄	
			Skill = pack_mount_skill([]),            %% 技能[Id等级,阶数,经验],	
      		Status = 0,                             %%  0休息1出战	
      		Icon = 0,                               %% 显示图形	
      		Ct = 0                                  %% 创建时间	
	end,
	Name_len = byte_size(Name),
	Title_len = byte_size(Title),
	Data_vaule = <<Mount_id:32,Player_id:32,Goods_id:32,Name_len:16,Name/binary,Level:16,Exp:32,LevelExp:32,
				   Luck_val:32,Max_Luck_val:32,Close:32,Step:8,Speed:16,Title_len:16,Title/binary,Color:8,Stren:8,TotalValue:16,MaxVlaue:16,Lp:16,Xp:16,Tp:16,Qp:16,
				   Skill/binary,Status:8,Icon:32,Ct:32,Hp:16,Mp:16,Att:16,Def:16,Hit:16,Dodge:16,Crit:16,Anti_wind:16,Anti_fire:16,Anti_water:16,Anti_thunder:16,Anti_soil:16,Batt_val:32>>,
	Data_vaule.


%%坐骑技能信息打包处理
pack_mount_skill(Mount) ->
	case Mount of
			[] ->  
				 <<0:16, <<>>/binary>>;
			_ ->
				Skill_List = [Mount#ets_mount.skill_1,Mount#ets_mount.skill_2,Mount#ets_mount.skill_3,Mount#ets_mount.skill_4,Mount#ets_mount.skill_5,Mount#ets_mount.skill_6,Mount#ets_mount.skill_7,Mount#ets_mount.skill_8],
				F = fun(MountSkill) ->
							[Pos, SkillId, SkillType, SkillLevel, SkillStep, SkillExp] = util:string_to_term(tool:to_list(MountSkill)),
							NextSkillExp = data_mount:get_skill_upgrade_exp(SkillLevel,SkillStep),
							EffectValue = data_mount:get_skill_prop(SkillId,SkillLevel),
							<<Pos:32, SkillId:32, SkillExp:32, NextSkillExp:32, SkillStep:8, SkillLevel:8, SkillType:8, EffectValue:16>>
					end,
				RB = tool:to_binary([F(MountSkill) || MountSkill <- Skill_List]),
				<<8:16, RB/binary>>
		end.

