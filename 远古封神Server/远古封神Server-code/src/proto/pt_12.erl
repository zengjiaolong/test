%%%-----------------------------------
%%% @Module  : pt_12
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 12场景信息
%%%-----------------------------------
-module(pt_12).
-export([read/2, write/2, trans_to_12003/1]).
-include("common.hrl").
-include("record.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%%走路
read(12001, <<X:16, Y:16, SceneId:32>>) ->
    {ok, [X, Y, SceneId]};

%%加载场景
read(12002, _) ->
    {ok, load_scene};

%%离开场景
read(12004, <<Q:32>>) ->
    {ok, Q};

%%切换场景
read(12005, <<Q:32>>) ->
%% ?DEBUG("12005_get_~p ~n",[Q]),	
    {ok, Q};

%% 获取当前NPC列表
read(12023, <<SceneId:32>>) ->
    {ok, SceneId};

%% 离开副本
read(12030, <<Nid:32>>) ->
    {ok, Nid};

%%获取场景关系
read(12080, _) ->
    {ok, []};

%%获取副本次数
read(12100,_)->
	{ok,[]};

%%获取水晶信息
read(12301, <<SparId:16>>) ->
	{ok, [SparId]};

%%诛邪副本拾取水晶
read(12302, <<SparId:16>>) ->
	{ok, [SparId]};

%%离开诛邪副本
read(12303, _R) ->
	{ok, []};

%%进入诛邪副本
read(12304, _R) ->
	{ok, []};

%%请求进入挂机场景
read(12400,<<SceneId:32>>)->
	{ok,[SceneId]};

%% 请求离开试炼副本
read(12049,_)->
	{ok,leave};

%% -----------------------------------------------------------------
%% 12052 温泉动作操作
%% -----------------------------------------------------------------
read(12052, <<RecId:32, Face:8>>)->
	{ok, [RecId, Face]};

%% -----------------------------------------------------------------
%% 12053 温泉开放与关闭通知
%% -----------------------------------------------------------------
read(12053, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 12054 进入温泉
%% -----------------------------------------------------------------
read(12054, <<Type:8>>)->
	{ok, [Type]};

%% -----------------------------------------------------------------
%% 12057 离开温泉
%% -----------------------------------------------------------------
read(12057, _R) ->
	{ok, []};


%% 12060 试炼副本立即刷怪

read(12060, _R) ->
	{ok,[]};

%% -----------------------------------------------------------------
%% 12063 采集莲花
%% -----------------------------------------------------------------
read(12063, <<X:16,Y:16>>) ->
	{ok, [X, Y]};

%%轻功传送
read(12062, <<X:16, Y:16>>) ->
    {ok, [X, Y]};

%%进入婚宴
read(12072, _R) ->
%% 	?DEBUG("120720",[]),
	{ok,[]};

read(12074, _R) ->
	{ok,[]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%走路
write(12001, [X, Y, Id]) ->
    Data = <<X:16, Y:16, Id:32>>,
    {ok, pt:pack(12001, Data)};

%% 加场景信息
write(12002, {User, Mon, Elem, Npc, Spar}) ->
    ElemData = pack_elem_list(Elem),
	UserData = pack_role_list(User),
    EnterMonData = pack_mon_list(Mon),
    NpcData = pack_npc_list(Npc),
	SparData = pack_spar_list(Spar),
    Data = <<ElemData/binary, UserData/binary, EnterMonData/binary, NpcData/binary, SparData/binary>>,
    {ok, pt:pack(12002, Data)};

%%进入新场景广播给本场景的人
write(12003, [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, 
			  Lv, Career, Speed, EquipCurrent, Sex, Leader, Realm, 
			  GuildName, GuildPosition, Evil, Status,Stren,SuitID,Carry_Mark, ConVoy_Npc,NpcName,
			  PetStatus,PetId,PetName,PetColor,PetType,PetGrow,Vip,MountStren,PeachRevel,CharmTitle,IsSpring,Turned,Accept,DeputyProfLv,CoupleName,PetAptitude,SuitId,FullStren,FbyfStren,SpyfStren,_Pet_batt_skill]) ->
	
	Data = pack_role_info([Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, 
			  Lv, Career, Speed, EquipCurrent, Sex, Leader, Realm, 
			  GuildName, GuildPosition, Evil, Status,Stren,SuitID,Carry_Mark, ConVoy_Npc,NpcName,
			  PetStatus,PetId,PetName,PetColor,PetType,PetGrow,Vip,MountStren,PeachRevel,CharmTitle,IsSpring,Turned,Accept,DeputyProfLv,CoupleName,PetAptitude,SuitId,FullStren,FbyfStren,SpyfStren,_Pet_batt_skill]),
    {ok, pt:pack(12003, Data)};

%%退出场景
write(12004, Id) ->
    Data = <<Id:32>>,
    {ok, pt:pack(12004, Data)};

%%切换场景
write(12005, [Id, X, Y, Name, Sid, DungeonTimes, DungeonMaxtimes, ArenaMark]) ->
    Len = byte_size(Name),
    Data = <<Id:32, X:16, Y:16, Len:16, Name/binary, Sid:32, DungeonTimes:8, DungeonMaxtimes:8, ArenaMark:8>>,
    {ok, pt:pack(12005, Data)};

%%通知情景玩家怪物重生了 
write(12007, Minfo) ->
	#ets_mon{
		name = MonName,
		x = X,
		y = Y,
		id = Id,
		mid = Mid,
		hp = Hp,
		mp = Mp,
		hp_lim = HpLim,
		mp_lim = MpLim,
		lv = Lv,
		icon = Icon,
		type = Type,
		att_area = AttArea
	} = Minfo,
	NewMonName = tool:to_binary(MonName),
    MonNameLen = byte_size(NewMonName),
	Data = <<X:16, Y:16, Id:32, Mid:32, Hp:32, Mp:32, HpLim:32, MpLim:32, Lv:16, MonNameLen:16, NewMonName/binary, Icon:32, Type:8, AttArea:8>>,
    {ok, pt:pack(12007, Data)};

%%怪物移动
write(12008, [X, Y, Speed, Id]) ->
    Data = <<X:16, Y:16, Speed:16, Id:32>>,
    {ok, pt:pack(12008, Data)};

%%使用物品或者装备物品
write(12009, [PlayerId, HP, HP_lim]) ->
    {ok, pt:pack(12009, <<PlayerId:32, HP:32, HP_lim:32>>)};

%%乘上坐骑或者离开坐骑
write(12010, [PlayerId, PlayerSpeed, MountTypeId,MountId,MountStren]) ->
    {ok, pt:pack(12010, <<PlayerId:32, PlayerSpeed:16, MountTypeId:32,MountId:32,MountStren:8>>)};

%%加场景信息
write(12011, [EnterUser, LeaveUser, EnterMon, LeaveMon]) ->
    EnterUserData = pack_role_list(EnterUser),
    LeaveUserData = pack_leave_list(LeaveUser),
	EnterMonData = pack_mon_list(EnterMon),
	LeaveMonData = pack_leave_list(LeaveMon),
    Data = <<EnterUserData/binary, LeaveUserData/binary, EnterMonData/binary, LeaveMonData/binary>>,
    {ok, pt:pack(12011, Data)};

%%装备物品
write(12012, [PlayerId, GoodsTypeId, Subtype, HP, HP_lim]) ->
    {ok, pt:pack(12012, <<PlayerId:32, GoodsTypeId:32, Subtype:16, HP:32, HP_lim:32>>)};

%%卸下装备
write(12013, [PlayerId, GoodsTypeId, Subtype, HP, HP_lim]) ->
    {ok, pt:pack(12013, <<PlayerId:32, GoodsTypeId:32, Subtype:16, HP:32, HP_lim:32>>)};

%%使用物品
write(12014, [PlayerId, GoodsTypeId, HP, HP_lim]) ->
    {ok, pt:pack(12014, <<PlayerId:32, GoodsTypeId:32, HP:32, HP_lim:32>>)};

%%装备磨损
write(12015, [PlayerId, HP, HP_lim, GoodsList]) ->
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.goods_id,
            Subtype = GoodsInfo#goods.subtype,
            <<GoodsId:32, Subtype:16>>
        end,
    ListBin = tool:to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(12015, <<PlayerId:32, HP:32, HP_lim:32, ListNum:16, ListBin/binary>>)};

%%切换装备
write(12016, [PlayerId, HP, HP_lim, GoodsList]) ->
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.goods_id,
            Subtype = GoodsInfo#goods.subtype,
            <<GoodsId:32, Subtype:16>>
        end,
    ListBin = tool:to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(12016, <<PlayerId:32, HP:32, HP_lim:32, ListNum:16, ListBin/binary>>)};

%% 掉落包生成
write(12017, [RealMonId, Time, X, Y]) ->
     {ok, pt:pack(12017, <<RealMonId:32, Time:16, X:16, Y:16>>)};

%% 掉落包生成
write(12117, [Type, DropGoods]) ->
	Len = length(DropGoods),
    DropFun = fun({DropId, GoodsTypeId, X, Y}) ->
 		<<DropId:32, GoodsTypeId:32, X:16, Y:16>>
   	end,
    DropGoodsBin = tool:to_binary(lists:map(DropFun, DropGoods)),
  	{ok, pt:pack(12117, <<Type:8, Len:16, DropGoodsBin/binary>>)};

%%某玩家成为队长(卸任队长)时通知场景
write(12018, [Id, Type]) ->
%% ?DEBUG("12018_~p/",[{Id, Type}]),
    {ok, pt:pack(12018, <<Id:32, Type:8>>)};

%%掉落包消失
write(12019, DropId) ->
     {ok, pt:pack(12019, <<DropId:32>>)};

%% 改变NPC状态图标
write(12020, []) ->
    {ok, pt:pack(12020, <<>>)};
write(12020, [NpcList]) ->
    NL = length(NpcList),
    Bin = tool:to_binary([<<Id:32, Ico:8>> || [Id, Ico] <- NpcList]),
    Data = <<NL:16, Bin/binary>>,
    {ok, pt:pack(12020, Data)};

%% 当前罪恶值
write(12021, [Id, Evil]) ->
    {ok, pt:pack(12021, <<Id:32, Evil:32>>)};

%% 返回当前场景的分线数
write(12022, [SceneId,CopySceneIdList]) ->
	NL = length(CopySceneIdList),
	Bin = tool:to_binary([<<SId:32>> || SId <- CopySceneIdList]),
	Data = <<SceneId:32, NL:16,Bin/binary>>,
	{ok,pt:pack(12022,Data)};

%% 获取当前NPC列表
write(12023, [SceneId, NpcList, ElemList]) ->
    NpcData = pack_npc_list(NpcList),
	ElemData = pack_elem_list(ElemList),
    {ok, pt:pack(12023, <<SceneId:32, NpcData/binary, ElemData/binary>>)};

%% 退出副本
write(12030, State) ->
    {ok, pt:pack(12030, <<State:8>>)};

%%灵兽出战或休息
write(12031,[PetStatus,Id,PetId,PetName,PetColor,PetType,PetGrow,PetAptitude]) ->
	Name = tool:to_binary(PetName),
	Len = byte_size(Name),
	{ok,pt:pack(12031,<<PetStatus:16,Id:32,PetId:32,Len:16,Name/binary,PetColor:16,PetType:32,PetGrow:16,PetAptitude:8>>)};

%%装备效果改变场景广播
write(12032,[PlayerId,Type,Value]) ->
	{ok,pt:pack(12032,<<PlayerId:32,Type:8,Value:16>>)};

%%接镖或者交镖
write(12041,[PsId,Carry_Mark]) ->
	{ok,pt:pack(12041,<<PsId:32,Carry_Mark:8>>)};

%%护送NPC
write(12051,[PsId,ConVoy_Npc,Name]) ->
	Name1 = tool:to_binary(Name),
	NameLen = byte_size(Name1),
	{ok,pt:pack(12051,<<PsId:32,ConVoy_Npc:32,NameLen:16,Name1/binary>>)};

%% 场景烟花广播
write(12061,[PlayerId,Goods_id]) ->
	{ok,pt:pack(12061,<<PlayerId:32,Goods_id:32>>)};


%% 打包场景相邻关系数据
write(12080, [L]) ->
    Len = length(L),
    Bin = pack_scene_border(L, []),
    {ok, pt:pack(12080, <<Len:16, Bin/binary>>)};

%% 更新怪物血量
write(12081, [Id, Hp]) ->
 	{ok, pt:pack(12081, <<Id:32, Hp:32>>)};

%% 更新怪物血量
write(12082, [Id, Hp]) ->
	{ok, pt:pack(12082, <<Id:32, Hp:32>>)};

%% 更新怪物属性
write(12083, [Id, Hp, HpLim, Name]) ->
%% ?DEBUG("12083___________________~p/",[[Hp, HpLim]]),
	NewName = tool:to_binary(Name),
	NameLen = byte_size(Name),
  	{ok, pt:pack(12083, <<Id:32, Hp:32, HpLim:32, NameLen:16, NewName/binary>>)};

%% 更改怪物某一属性 
write(12084, [MonId, AttrList]) ->
	Len = length(AttrList),
	F = fun({AttrType, AttrVal, Symbol}) ->
		<<AttrType:8, AttrVal:32, Symbol:8>>
	end,
	LB = tool:to_binary(lists:map(F, AttrList)),
    {ok, pt:pack(12084, <<MonId:32, Len:16 ,LB/binary>>)};
     
%%修炼信息广播
write(12090, [Pid, Sta]) ->
    {ok, pt:pack(12090, <<Pid:32, Sta:8>>)};

%% 场景瞬移
write(12110, [Sign, PlayerId, X, Y, Type]) ->
	{ok, pt:pack(12110, <<Sign:8, PlayerId:32, X:16, Y:16, Type:8>>)};

%%获取副本次数
write(12100,TimesList)->
	TBin = pack_times_list(TimesList),
    Data = << TBin/binary>>,
    {ok, pt:pack(12100, Data)};

%%场景矿点出现
write(12200,[OreId,X,Y]) ->
	{ok,pt:pack(12200,<<OreId:32,X:16,Y:16>>)};
%%场景矿点消失
write(12201,[OreId]) ->
	{ok,pt:pack(12201,<<OreId:32>>)};

%%获取水晶信息
write(12301, [SparID, X, Y]) ->
	Data = <<SparID:16, X:16, Y:16>>,
	{ok, pt:pack(12301, Data)};

%%诛邪副本拾取水晶
write(12302, [Result, GoodsTypeId, SparId]) ->
	Data = <<Result:8, GoodsTypeId:32, SparId:16>>,
	{ok, pt:pack(12302, Data)};

%% 场景广播 某人的 某个属性
write(12042, [PlayerId, AttrList]) ->
	Len = length(AttrList),
	F = fun({AttrType, AttrVal}) ->
				<<AttrType:32, AttrVal:32>>
		end,
	LB = tool:to_binary(lists:map(F, AttrList)),
    {ok, pt:pack(12042, <<PlayerId:32, Len:16 ,LB/binary>>)};

%%进入挂机场景
write(12400,[Res])->
	{ok,pt:pack(12400,<<Res:16>>)};

write(12401,[Res])->
	{ok,pt:pack(12401,<<Res:16>>)};

%%魅力称号变换
write(12043,[PlayerId,Titles]) ->
%% 	?DEBUG("CharmTitle ~p", [Titles]),
	{TitlesLen, TitlesBin} = lib_title:pack_titles_data(Titles),
	{ok,pt:pack(12043,<<PlayerId:32,TitlesLen:16, TitlesBin/binary>>)};

%% 角色改名场景知道
write(12044, [Player_Id,Nickname])->
	Nickname1 = tool:to_binary(Nickname),
    Nickname1_len = byte_size(Nickname1),	
	{ok, pt:pack(12044, <<Player_Id:32,Nickname1_len:16,Nickname1/binary>>)};

%%试炼副本返回剩余时间
write(12050,[Time])->
	{ok,pt:pack(12050,<<Time:16>>)};

%%离开试炼副本
write(12049,[Code])->
	{ok,pt:pack(12049,<<Code:8>>)};

%% -----------------------------------------------------------------
%% 12052 温泉动作操作
%% -----------------------------------------------------------------
write(12052, [Type]) ->
	{ok,pt:pack(12052, <<Type:8>>)};

%% -----------------------------------------------------------------
%% 12053 温泉开放与关闭通知
%% -----------------------------------------------------------------
write(12053, [EndTime, Type]) ->
%% 	?DEBUG("12053 :~p, ~p", [EndTime, Type]),
	{ok,pt:pack(12053, <<Type:8, EndTime:32>>)};

%% -----------------------------------------------------------------
%% 12054 进入温泉
%% -----------------------------------------------------------------
write(12054, [Result]) ->
	{ok,pt:pack(12054, <<Result:8>>)};

%% -----------------------------------------------------------------
%% 12055 玩家剩余的表情次数
%% -----------------------------------------------------------------
write(12055, [CD, List]) ->
	Len = length(List),
	{_Num, Lists} = 
		lists:foldl(fun(Elem, AccIn) ->
						  {FaceId, EList} = AccIn,
						  {FaceId+1, [<<FaceId:8, Elem:8>>|EList]}
				  end, {1, []}, List),
	BinLists = tool:to_binary(Lists),
	{ok,pt:pack(12055, <<CD:32, Len:16, BinLists/binary>>)};

%% -----------------------------------------------------------------
%% 12056 温泉动作操作(广播)
%% -----------------------------------------------------------------
write(12056, [SendId, SendName, RecId, RecName, Face]) ->
	{SNLen, SNBin} = lib_guild_inner:string_to_binary_and_len(SendName),
	{RNLen, RNBin} = lib_guild_inner:string_to_binary_and_len(RecName),
	{ok,pt:pack(12056, <<SendId:32, SNLen:16, SNBin/binary, RecId:32, RNLen:16, RNBin/binary, Face>>)};

%% -----------------------------------------------------------------
%% 12057 离开温泉
%% -----------------------------------------------------------------
write(12057, [Type]) ->
	{ok,pt:pack(12057, <<Type:8>>)}; 

%% -----------------------------------------------------------------
%% 12059 莲花消失
%% -----------------------------------------------------------------
write(12059, [Coord]) ->
	{X, Y} = Coord,
	{ok,pt:pack(12059, <<X:16, Y:16>>)};
%%轻功传送
write(12062, [Player_Id,Res,X,Y]) ->
    {ok, pt:pack(12062, <<Player_Id:32,Res:8,X:16,Y:16>>)};

%% -----------------------------------------------------------------
%% 12060 刷新莲花
%% -----------------------------------------------------------------
write(12060, [Lotuses]) ->
%%	?DEBUG("lotuses : ~p", [Lotuses]),
	Len = length(Lotuses),
	List = 
		lists:map(fun(Elem) ->
						  {X, Y} = Elem,
						  <<X:16, Y:16>>
				  end, Lotuses),
	ListBin = tool:to_binary(List),
	{ok,pt:pack(12060, <<Len:16, ListBin/binary>>)};

%% -----------------------------------------------------------------
%% 12063 采集莲花
%% -----------------------------------------------------------------
write(12063, [Result]) ->
%% 	?DEBUG("12063: ~p", [Result]),
	{ok,pt:pack(12063, <<Result:16>>)};

%% -----------------------------------------------------------------
%% 12064 取消采集莲花
%% -----------------------------------------------------------------
write(12064, []) ->
	{ok,pt:pack(12064, <<>>)};

%% -----------------------------------------------------------------
%% 12065 温泉内进水出水广播
%% -----------------------------------------------------------------
write(12065, [Pid, Type]) ->
	{ok,pt:pack(12065, <<Pid:32, Type:8>>)};

%% 变身
write(12066, [PlayerId,Turned]) ->
	{ok,pt:pack(12066, <<PlayerId:32, Turned:32>>)};

%% 幻魔穴传送点信息
write(12071, List) ->
	Len = length(List),
    F = fun({SceneIndex, SceneId, SceneName, SceneX, SceneY}) ->
		SceneNameLen = byte_size(SceneName),
		<<SceneIndex:8, SceneId:32, SceneNameLen:16, SceneName/binary, SceneX:32, SceneY:32>>
    end,
    LN = tool:to_binary([F(L) || L <- List]),
    Data = <<Len:16, LN/binary>>,
    {ok, pt:pack(12071, Data)};

%%进入婚宴
write(12072,[Result])->
	{ok,pt:pack(12072, <<Result:8>>)};

%%生成餐桌
write(12073,Ds)->
	Length = length(Ds),
	Fun = fun({D,X,Y}) ->
		 		<<D:32,X:16,Y:16>>
		  end,
	L = tool:to_binary([Fun(E) || E <- Ds]),
	Data = <<Length:16,L/binary>>,
	{ok,pt:pack(12073, Data)};
	

%%离开婚宴
write(12074,[Result])->
	{ok,pt:pack(12074, <<Result:8>>)};

write(12075,{PlayerId,Str})->
	StrBin = tool:to_binary(Str),
	StrLen = byte_size(StrBin),
	{ok,pt:pack(12075, <<PlayerId:32,StrLen:16,StrBin/binary>>)};

write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p]/~p ",[misc:time_format(yg_timer:now()), Cmd, _R]),
    {ok, pt:pack(0, <<>>)}.

%%打包副本次数列表
pack_times_list([]) -> <<0:16>>;
pack_times_list(TimesList) ->
    Len = length(TimesList),
    Bin = tool:to_binary([pack_times(X) || X <- TimesList]),
    <<Len:16, Bin/binary>>.
pack_times({SceneId,NowTimes,LimitTimes})->
	<<SceneId:32,NowTimes:16,LimitTimes:16>>.

%% 打包元素列表
pack_elem_list([]) ->
    <<0:16, <<>>/binary>>;
pack_elem_list(Elem) ->
    Rlen = length(Elem),
    F = fun([Index, Sid, Name, X, Y]) ->
        Len = byte_size(Name),
        <<Index:8, Sid:32, Len:16, Name/binary, X:16, Y:16>>
    end,
    RB = tool:to_binary([F(D) || D <- Elem]),
    <<Rlen:16, RB/binary>>.

%% 打包单个角色
pack_role_info([Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, 
			  Lv, Career, Speed, EquipCurrent, Sex, Leader, Realm, 
			  GuildName, GuildPosition, Evil, Status,Stren,SuitID,Carry_Mark, ConVoy_Npc,NpcName,
			  PetStatus,PetId,PetName,PetColor,PetType,PetGrow,Vip,MountStren, PeachRevel, CharmTitle,
			  IsSpring,Turned,_Accept,DeputyProfLv,CoupleName,PetAptitude,SuitId,FullStren,FbyfStren,SpyfStren,_Pet_batt_skill]) ->
	[E1, E2, E3, E4, E5] = EquipCurrent,
    Nick1 = tool:to_binary(Nick),
    Len = byte_size(Nick1),
	Couple = tool:to_binary(CoupleName),
    Lenc = byte_size(Couple),
    GuildName1 = tool:to_binary(GuildName),
    Len1 = byte_size(GuildName1),
	PetName1 = tool:to_binary(PetName),
	PetNameLen = byte_size(PetName1),
	NpcName1 = tool:to_binary(NpcName),
	NpcNameLen = byte_size(NpcName1),
	{TitlesLen, TitlesBin} = lib_title:pack_titles_data(CharmTitle),
	{GPostStrLen, GPostStrBin} = lib_player:get_guild_post_title(GuildPosition),
    <<X:16, Y:16, Id:32, Hp:32, Mp:32, Hp_lim:32, Mp_lim:32, Lv:16, Career:8, Len:16, Nick1/binary, 
	  	Speed:16, E1:32, E2:32, E3:32, E4:32, E5:32, Sex:8, Leader:8, Realm:8, Len1:16, GuildName1/binary, 
	  	Evil:32, Status:16, Stren:8, SuitID:8, Carry_Mark:8, ConVoy_Npc:32,	NpcNameLen:16, 
	  	NpcName1/binary, PetStatus:16, PetId:32, PetNameLen:16, PetName1/binary, 
	  	PetColor:16, PetType:32,PetGrow:16,Vip:8,MountStren:8, PeachRevel:8,TitlesLen:16, TitlesBin/binary, 
		IsSpring:8, GPostStrLen:16, GPostStrBin/binary,Turned:32,DeputyProfLv:8,Lenc:16,Couple/binary,PetAptitude:8,
		SuitId:16,FullStren:8,FbyfStren:8,SpyfStren:8>>.

%% 打包角色列表
pack_role_list([]) ->  <<0:16, <<>>/binary>>;
pack_role_list(User) -> 
    Rlen = length(User),
    F = fun([Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent,
			 Sex, Out_pet, _Pid, Leader, _Pid_team, Realm, GuildName, GuildPosition, Evil, Status, Carry_Mark, ConVoy_Npc ,Stren,SuitID,Vip,MountStren, PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,CoupleName,SuitId,FullStren,FbyfStren,SpyfStren,_Pet_batt_skill]) ->
		case Out_pet of
			[] -> 
				PetStatus=0,
				PetId=0,
				PetName='',
				PetColor=0,
				PetType=0,
				PetGrow=0,
				PetAptitude=0;
			_Pet ->
				PetStatus = Out_pet#ets_pet.status,
				PetId = Out_pet#ets_pet.id,
				PetName = Out_pet#ets_pet.name,
				PetColor = data_pet:get_pet_color(Out_pet#ets_pet.aptitude),
				PetType=Out_pet#ets_pet.goods_id,
				PetGrow=Out_pet#ets_pet.grow,
				PetAptitude=Out_pet#ets_pet.aptitude
		end,
		case ConVoy_Npc of
			0->
				NpcName='';
			_->
			case lib_npc:get_data(ConVoy_Npc) of
				ok -> NpcName='';
				NpcInfo ->
					NpcName=NpcInfo#ets_npc.name
			end
		end,
		pack_role_info([Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, 
			  Lv, Career, Speed, EquipCurrent, Sex, Leader, Realm, 
			  GuildName, GuildPosition, Evil, Status, Stren, SuitID, Carry_Mark, ConVoy_Npc, NpcName,
			  PetStatus, PetId, PetName, PetColor, PetType,PetGrow,Vip,MountStren, PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,CoupleName,PetAptitude,SuitId,FullStren,FbyfStren,SpyfStren,_Pet_batt_skill])
    end,
    RB = tool:to_binary([F(D) || D <- User]),
    <<Rlen:16, RB/binary>>.

%% 打包怪物列表
pack_mon_list([]) ->
    <<0:16, <<>>/binary>>;
pack_mon_list(Mon) ->
    F = fun([Id, Name, X, Y, Hp, HpLim, Mp, MpLim, Lv, Mid,Icon, Type, AttArea]) ->
		Name1 =  tool:to_binary(Name),
   		Len = byte_size(Name1),
      	<<X:16, Y:16, Id:32, Mid:32, Hp:32, Mp:32, HpLim:32, MpLim:32,
			  Lv:16, Len:16, Name1/binary, Icon:32, Type:8, AttArea:8>>
   	end,
    Mons = [F(M) || M <- Mon],
    Rlen = length(Mons),
    RB = tool:to_binary(Mons),
    <<Rlen:16, RB/binary>>.

%% 打包NPC列表
pack_npc_list([]) ->
    <<0:16, <<>>/binary>>;
pack_npc_list(Npc) ->
    Rlen = length(Npc),
    F = fun([Id, Nid, Name, X, Y, Icon, NpcType]) ->
				Name1 = tool:to_binary(Name),
				NameLen = byte_size(Name1),
				TypeName = get_npc_typename(NpcType),
				TypeNameBin = tool:to_binary(TypeName),
				TypeNameLen = byte_size(TypeNameBin),
				<<Id:32, Nid:32, NameLen:16, Name1/binary, X:16, Y:16, Icon:32, TypeNameLen:16, TypeNameBin/binary>>
		end,
    RB = tool:to_binary([F(D) || D <- Npc]),
    <<Rlen:16, RB/binary>>.

%% 打包水晶列表
pack_spar_list([]) ->
    <<0:16, <<>>/binary>>;
pack_spar_list(Spar) ->
	Rlen = length(Spar),
	F = fun(Elem) ->
				#ets_spar{spar_id = SparId,
						  x = X,
						  y = Y,
						  type = SparType} = Elem,
				<<SparId:16, X:32, Y:32, SparType:8>>
		end,
	RB = tool:to_binary([F(D) || D <- Spar]),
	<<Rlen:16, RB/binary>>.

get_npc_typename(NpcType) ->
	case NpcType of
		1 -> "【氏】";
		2 -> "【武】";
		3 -> "【仓】";
		4 -> "【杂】";
		5 -> "【商】";
		6 -> "【铁】";
		7 -> "【宝】";
		8 -> "【兽】";
		9 -> "【传】";
		10 -> "【镖】";
		11 -> "【药】";
		12 -> "【修】";
		13 -> "【雇】";
		14 -> "【战】";
		15 -> "【鉴】";
		16 -> "【移】";
		17 -> "【荣】";
		18 -> "【师】";
		19 -> "【副】";
		20 -> "【荣】";
		21 -> "【台】";
		22 -> "【市】";
		23 -> "【装】";
		24 -> "【戒】";
		25 -> "【泉】";
		26 -> "【试】";
		27 -> "【诛】";
		28 -> "【变】";
		29 -> "【封】";
		30 -> "【镇】";
		31 -> "【时】";
		32 -> "【性】";
		33 -> "【活】";
		34 -> "【日】";
		35 -> "【城】";
		_ -> ""
	end.

%% %% 打包NPC列表
%% pack_npc_list([]) ->
%%     <<0:16, <<>>/binary>>;
%% pack_npc_list(Npc) ->
%%     Rlen = length(Npc),
%%     F = fun([Id, Nid, Name, X, Y, Icon]) ->
%%         Len = byte_size(Name),
%%         <<Id:32, Nid:32, Len:16, Name/binary, X:16, Y:16, Icon:32>>
%%     end,
%%     RB = tool:to_binary([F(D) || D <- Npc]),
%%     <<Rlen:16, RB/binary>>.

%% 打包pet列表
%% pack_pet_list([]) ->
%% 	<<0:16,<<>>/binary>>;
%% pack_pet_list(Pets) ->
%% 	Plen = length(Pets),
%% 	%%<<PetStatus:16,Id:32,PetId:32,PetType:32,Len:16,Name/binary,PetColor:16>>
%% 	F = fun(Pet) ->
%% 			Name = tool:to_binary(Pet#ets_pet.name),
%% 			Len = byte_size(Name),
%% 			PetColor = data_pet:get_pet_color(Pet#ets_pet.aptitude),
%% 			PetStatus =Pet#ets_pet.status,
%% 			Player_id =Pet#ets_pet.player_id,
%% 			Pet_id =Pet#ets_pet.id,
%% 			Goods_id =Pet#ets_pet.goods_id,
%% 			<<PetStatus:16,Player_id:32,Pet_id:32,Len:16,Name/binary,PetColor:16,Goods_id:32>>
%% 		end,
%% 	RB = tool:to_binary([F(P) || P <- Pets ]),
%% 	<<Plen:16,RB/binary>>.

%% 打包场景相邻关系数据
pack_scene_border([], Result) ->
    tool:to_binary(Result);
pack_scene_border([{Id, Border} | T], Result) ->
    L = length(Border),
    B = tool:to_binary([<<X:32>> || X <- Border]),
    Bin = <<Id:32, L:16, B/binary>>,
    pack_scene_border(T, [Bin | Result]).

%% 打包元素列表
pack_leave_list([]) ->
    <<0:16, <<>>/binary>>;
pack_leave_list(List) ->
    Rlen = length(List),
    RB = tool:to_binary([<<Id:32>> || Id <- List]),
    <<Rlen:16, RB/binary>>.

trans_to_12003(Status) ->
	case Status#player.other#player_other.out_pet of
		[] -> 
			PetStatus=0,
			PetId=0,
			PetName='',
			PetColor=0,
			PetType=0,
			PetGrow=0,
			PetAptitude=0;
		Pet ->
			PetStatus = Pet#ets_pet.status,
			PetId = Pet#ets_pet.id,
			PetName = Pet#ets_pet.name,
			PetColor = data_pet:get_pet_color(Pet#ets_pet.aptitude),
			PetType=Pet#ets_pet.goods_id,
			PetGrow=Pet#ets_pet.grow,
			PetAptitude=Pet#ets_pet.aptitude
	end,
	case Status#player.task_convoy_npc of
		0->
			NpcName='';
		NpcId->
			case lib_npc:get_data(NpcId) of
				ok ->NpcName='';
				NpcInfo ->
					NpcName=NpcInfo#ets_npc.name
			end
	end,
	[
    	Status#player.id,
    	Status#player.nickname,
	 	Status#player.x,
	 	Status#player.y,
	 	Status#player.hp,
	 	Status#player.hp_lim,
	 	Status#player.mp,
	 	Status#player.mp_lim,
	 	Status#player.lv,
	 	Status#player.career,
	 	Status#player.speed,
	 	Status#player.other#player_other.equip_current,
	 	Status#player.sex,
	 	Status#player.other#player_other.leader,
	 	Status#player.realm,
	 	Status#player.guild_name,
		Status#player.guild_position,
        Status#player.evil,
        Status#player.status,
		Status#player.other#player_other.stren,
		Status#player.other#player_other.suitid,
		Status#player.carry_mark,
		Status#player.task_convoy_npc,
		NpcName,
		PetStatus,
		PetId,
		PetName,
		PetColor,
		PetType,
		PetGrow,
		Status#player.vip,
		Status#player.other#player_other.mount_stren,
		Status#player.other#player_other.peach_revel,
		Status#player.other#player_other.titles,
		Status#player.other#player_other.is_spring,
		Status#player.other#player_other.turned,
		Status#player.other#player_other.accept,
		Status#player.other#player_other.deputy_prof_lv,
		Status#player.couple_name,
		PetAptitude,
		Status#player.other#player_other.suitid,
		Status#player.other#player_other.fullstren,
		Status#player.other#player_other.fbyfstren,
		Status#player.other#player_other.spyfstren,
		Status#player.other#player_other.pet_batt_skill
	].


%% %%  复制生生成 若干个 角色(用于大数据包测试)
%% make_many_user([]) -> [];
%% make_many_user(User) ->
%% 	[Auser|_] = User,
%% 	[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent,
%% 			 Sex, Out_pet, _Pid, Leader, _Pid_team, Realm, GuildName, Evil, Status,Carry_Mark,ConVoy_Npc] = Auser,
%% 	lists:map(fun(Id0) ->
%% 			[Id0, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent,
%% 			 Sex, Out_pet, _Pid, Leader, _Pid_team, Realm, GuildName, Evil, Status,Carry_Mark,ConVoy_Npc]					
%% 			  end,
%% 		lists:seq(1, 300)). %% 566 错误
	