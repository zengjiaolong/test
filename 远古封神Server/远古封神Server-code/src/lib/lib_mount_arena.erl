%% Author: Administrator
%% Created: 2012-2-28
%% Description: TODO: 坐骑竞技（斗兽）
-module(lib_mount_arena).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%%
%% Exported Functions
%%
-export([]).
-compile(export_all).
-define(MAX_RECENT,5).  %%近况保存的最大记录
-define(RANK_NUM,20).   %%斗兽排行榜需要显示的记录数
-define(MAX_ROUND,30).		%%最大回合数
-define(SKILL_RATE,30).  %%触发技能的概率
%%气血1,法力2,攻击3,防御4,命中5,闪避6,暴击7,风抗8,火抗9,水抗10,雷抗11,土抗12,全抗13
-define(SKILL_ATTACK,[5001,4001,3001,2001]). %%攻击技能ID
-define(SKILL_HIT,[4005,3005,2005,1004]).    %%命中技能ID
-define(SKILL_CRICT,[4007,3007,2007,1006]).   %%暴击技能ID
-define(SKILL_DODGE,[4006,3006,2006,1005]).  %%闪躲技能ID
-define(SKILL_SINGLE_ANTI,[4008,3008,2008,1007,4009,3009,2009,1008,4010,3010,2010,1009,4011,3011,2011,1010,4012,3012,2012,1011]). %%单抗8-12（各4个）
-define(SKILL_ANTI,[4013,3013,2013,1012]).   %%全抗技能ID
-define(SKILL_DEF,[4004,3004,2004,1003]).    %%防御技能ID
-define(SKILL_HP,[4002,3002,2002,1001]).     %%气血技能ID
%%
%% API Functions
%%

%%加载斗兽信息
%%只给斗兽进程init（）使用
%%挑战近况格式{发生时间，近况描述字符串， 战报ID}
load_mount_arena() ->
	ets:new(?ETS_MOUNT_ARENA, [named_table, public, set, {keypos, #ets_mount_arena.rank},?ETSRC, ?ETSWC]),
	ets:new(?ETS_MOUNT_BATTLE, [named_table, public, set, {keypos, #ets_mount_battle.mount_id},?ETSRC, ?ETSWC]),
	ets:new(?ETS_BATTLE_RESULT, [named_table, public, set, {keypos, #ets_battle_result.id},?ETSRC, ?ETSWC]),
	ets:new(?ETS_MOUNT_AWARD, [named_table, public, set, {keypos, #ets_mount_award.mid},?ETSRC, ?ETSWC]),
	ets:new(?ETS_MOUNT_RECENT, [named_table, public, set, {keypos, #ets_mount_recent.player_id},?ETSRC, ?ETSWC]),
	%%加载排名系统数据
    load_arena_datas().

%%加载排名系统数据, 纠正不正常(坐骑被放生、排名重复)的排名数据
load_arena_datas() ->
	case db_agent:get_mount_arena_info() of
		[] ->
			0;
		Datas ->
 			Nums = lists:foldl(fun(D,LastLen)->
								NextLen = LastLen+1,
								Marena = list_to_tuple([ets_mount_arena|D]),
								case db_agent:select_mount_info(Marena#ets_mount_arena.mount_id) of
									[] ->										
										%%如果玩家放生坐骑，就跑这里
										db_agent:delete_mount_arena(Marena#ets_mount_arena.id),
										LastLen;
									M ->
										%%插入榜内坐骑战斗信息
										if Marena#ets_mount_arena.rank =/= NextLen ->
											   db_agent:update_mount_arena([{rank,NextLen}],[{id,Marena#ets_mount_arena.id}]);
										   true ->
											   skip
										end,   
										if Marena#ets_mount_arena.rank =< ?MAX_MOUNT_NUM ->
											   BattleMount = parse_to_battle_data(list_to_tuple([ets_mount|M])),
											   ets:insert(?ETS_MOUNT_BATTLE, BattleMount),
											   %%加载近况数据，因为被人挑战时，也要改数据的
											   load_recent_data(Marena#ets_mount_arena.player_id), 
											   ets:insert(?ETS_MOUNT_ARENA, Marena#ets_mount_arena{rank = NextLen}),
											   NextLen;
										   true ->
											   NextLen
										end
								end
							   end, 0, Datas),
			Nums
	end.
					   

%%生成名次字段
%%暂时未处理玩家多个坐骑的情况
arena_rank([],_Order,AccList)->
	lists:reverse(AccList);
arena_rank([M|Infos],Order,AccList)->
	Mount = list_to_tuple([ets_mount|M]),
	NewM = {Mount#ets_mount.player_id,Mount,Order},
	arena_rank(Infos,Order+1,[NewM|AccList]).

%%从数据库加载一个坐骑的战斗信息
parse_to_battle_data_from_db(Mid) ->
	case db_agent:select_mount_info(Mid) of
		[] ->
			%%如果玩家放生坐骑，就不正常了
			[];
		M ->
			BattleMount = parse_to_battle_data(list_to_tuple([ets_mount|M])),
			ets:insert(?ETS_MOUNT_BATTLE, BattleMount),
			BattleMount
	end.

%%坐骑内存数据转化为战斗数据
parse_to_battle_data(M)->
	[Hp,Mp,Att,Def,Hit,Dodge,Crit,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil] = data_mount:get_prop_mount(M),
	SkillList = [M#ets_mount.skill_1,M#ets_mount.skill_2,M#ets_mount.skill_3,M#ets_mount.skill_4,
				 M#ets_mount.skill_5,M#ets_mount.skill_6,M#ets_mount.skill_7,M#ets_mount.skill_8],
	F = fun(MountSkill) ->
				[_Pos, SkillId, SkillType, SkillLevel, _SkillStep, _SkillExp]  = util:string_to_term(tool:to_list(MountSkill)),
				if SkillType >= 1 andalso SkillType < 14 ->
					   {SkillId,SkillType,SkillLevel};
				   true ->
					   {0,0,0}
				end
		end,
	%%战斗力
	M_val = data_mount:count_mount_batt([Hp,Mp,Att,Def,Hit,Dodge,Crit,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil]),
	%%技能[{ID，技能类型，技能等级 }]
	Hit2 = Hit / 1000 + 0.85,
	Dodge2 = (Dodge) / 1500,
	Crit2 = (Crit) / 2000,
	ResultList = [F(MountSkill) ||  MountSkill <- SkillList],
	NewSpeed = count_speed(M),
	BattleData = [M#ets_mount.id,M#ets_mount.player_id]++[Hp,Mp,Att,Def,Hit2,Dodge2,Crit2,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil]++[M#ets_mount.level]++[ResultList]++[M_val]++[NewSpeed],
	list_to_tuple([ets_mount_battle|BattleData]).

%%坐骑原始数据转化成竞技数据(并且同时插入DB与ets)
%%{Player_Id,_MountId,_Name,_Level,_Color,_Step,_Title,_Mount_val,_Order}
parse_to_arena_data() ->
	BattRanks =  db_agent:rank_mount_rank_all(?SLAVE_POOLID),
	BattRanks1 = arena_rank(BattRanks,1,[]),
	PlayerIdList = [Id || {Id,_M,_Order} <- BattRanks1],
	PlayerInfoList = db_agent:get_player_mult_properties([id, nickname, realm],lists:flatten(PlayerIdList)), 
	F = fun([Id, Nickname, Realm]) ->
				{_Id, M, Order}  = lists:keyfind(Id, 1, BattRanks1),
				[Id,M#ets_mount.id,Order,Nickname,Realm,M#ets_mount.step,M#ets_mount.name,M#ets_mount.title,M#ets_mount.goods_id,M#ets_mount.color,M#ets_mount.level,M#ets_mount.mount_val,?MAX_CGE_TIMES,0]
		end,
	BattRanks2 = [F([Id, Nickname, Realm]) || {_Key,[Id, Nickname, Realm]} <- PlayerInfoList],
	F_insert = fun(ArenaData) ->
					   db_agent:add_mount_to_arena(ArenaData),
					   Mrecord = list_to_tuple([ets_mount_arena|ArenaData]),
					   ets:insert(?ETS_MOUNT_ARENA, Mrecord)
			   end,
	%%进入竞技榜的坐骑数目限制为?MAX_NUM
	BattRanks3 = lists:sublist(BattRanks2, 1, ?MAX_MOUNT_NUM),
	[F_insert(ArenaData) || ArenaData <- BattRanks3],
	length(BattRanks3).

%%根据当前竞技榜斗兽个数判断一个坐骑能否加入竞技榜
mount_join_ranker(Nownum,[Mount,PlayerId,Nickname,Realm,_Vip]) ->
	case db_agent:select_mount_arena(PlayerId,Mount#ets_mount.id) of
		[] ->
			Rank = Nownum+1,
			join_ranker(Rank,{no,[]},[Mount,PlayerId,Nickname,Realm]),
			%%战斗信息
			BattleMount = parse_to_battle_data(Mount),
			ets:insert(?ETS_MOUNT_BATTLE, BattleMount),
			Rank;
		Data -> %%已经被设成0的数据或已在排行榜的数据
			Ms = ets:fun2ms(fun(Ma) when Ma#ets_mount_arena.player_id =:= Mount#ets_mount.player_id 
						 andalso Ma#ets_mount_arena.mount_id =:=  Mount#ets_mount.id -> Ma end),
			case ets:select(?ETS_MOUNT_ARENA,Ms) of
				[] ->%%不在排行榜，已经被设成0的数据
					%%更新数据库
					New = list_to_tuple([ets_mount_arena | Data]),
					Rank =
						if New#ets_mount_arena.rank =:= 0 ->
							   case ets:lookup(?ETS_MOUNT_ARENA, Nownum + 1) of
								   [] ->
									   db_agent:update_mount_arena([{rank,Nownum + 1}],[{id,New#ets_mount_arena.id}]),
									   Nownum + 1;
								   _ ->
									   db_agent:update_mount_arena([{rank,Nownum + 2}],[{id,New#ets_mount_arena.id}]),
									   Nownum + 2
							   end;
						   true ->
							   New#ets_mount_arena.rank
						end,
					%%插入内存即可
					join_ranker(Rank,{yes,Data},[Mount,PlayerId,Nickname,Realm]),
					Rank;
				_ ->
					Nownum
			end
	end.

%%坐骑加入斗兽榜函数
join_ranker(Rank,{EtsOnly,Data},[Mount,PlayerId,Nickname,Realm]) ->
	case EtsOnly of
		no ->
			%%?DEBUG("no.......~p",[Mount#ets_mount.id]),
			MountMultAttributeList = data_mount:get_prop_mount(Mount),
			Mount_Batt_val = data_mount:count_mount_batt(MountMultAttributeList),
			Name = Mount#ets_mount.name,
			%%斗兽榜
			%%如果 rank大于500 ， 该玩家下线时内存数据将被清除, 第二个rank为结算时的rank，第一次进入斗兽系统时默认与rank相同
			RankerData = [PlayerId,Mount#ets_mount.id,Rank,Rank,Nickname,Realm,Mount#ets_mount.step,Name,Mount#ets_mount.title,
						  Mount#ets_mount.goods_id,Mount#ets_mount.color,Mount#ets_mount.level,Mount_Batt_val,0,1,1],
			Id = db_agent:add_mount_to_arena(RankerData),
			EtsData = [Id|RankerData],
			Arena = list_to_tuple([ets_mount_arena | EtsData]),
			ets:insert(?ETS_MOUNT_ARENA, Arena#ets_mount_arena{rank = Rank});
		yes ->
			%%?DEBUG("yes1.......~p",[Mount#ets_mount.id]),
			%%这里可能会有问题, 数据库已有的坐骑再次加载
			%%判断rank_award
			New = list_to_tuple([ets_mount_arena | Data]),		   
			ets:insert(?ETS_MOUNT_ARENA, New#ets_mount_arena{rank = Rank})
	end.

temp_fun1(Time) ->
	Time>1334246400 andalso Time<1334300100.

temp_fun2(Time) ->
	case Time<1334300100 of
		true ->
			1334300160;
		false ->
			Time
	end.

%%计算金币增加次数与当前已挑战次数
count_cge_times(Re) ->
	Now = util:unixtime(),
	R1 = 
		case temp_fun1(Re#ets_mount_recent.last_cost_time) of
			true ->
				R2 = Re#ets_mount_recent{gold_cge_times = 0,last_cost_time = 1},
				ets:insert(?ETS_MOUNT_RECENT, R2),
				db_agent:update_mount_recent([{gold_cge_times,0},{last_cost_time,0}], [{player_id,Re#ets_mount_recent.player_id}]),
				R2;
			false ->
				Re
		end,
	R3 = 
		case temp_fun1(R1#ets_mount_recent.last_cge_time) of
			true ->
				R4 = R1#ets_mount_recent{cge_times = 0,last_cge_time = 0},
				ets:insert(?ETS_MOUNT_RECENT, R4),
				db_agent:update_mount_recent([{cge_times,0},{last_cge_time,0}], [{player_id,R1#ets_mount_recent.player_id}]),
				R4;
			false ->
				R1
		end,
	NewCost = 
		if 
			R3#ets_mount_recent.last_cost_time =:= 0 ->
				1;
			true ->
				R3#ets_mount_recent.last_cost_time
		end,
	Gold_times =
		case util:is_same_date(NewCost, Now) of
			false ->
				ets:insert(?ETS_MOUNT_RECENT, R3#ets_mount_recent{gold_cge_times = 0}),
				db_agent:update_mount_recent([{gold_cge_times,0}], [{player_id,R3#ets_mount_recent.player_id}]),
				0;
			true ->
				R3#ets_mount_recent.gold_cge_times
		end,
	Cge_times = 
		case util:is_same_date(R3#ets_mount_recent.last_cge_time, Now) of
			false ->
				ets:insert(?ETS_MOUNT_RECENT, R3#ets_mount_recent{cge_times = 0}),
				db_agent:update_mount_recent([{cge_times,0}], [{player_id,R3#ets_mount_recent.player_id}]),
				0;
			true ->
				R3#ets_mount_recent.cge_times
		end,
	{Gold_times,Cge_times}.

%%加载单个坐骑战斗信息、近况信息
load_single_mount_br(Player,Mount) ->
	%%加载战斗信息
	BattleMount = parse_to_battle_data(Mount),
	ets:insert(?ETS_MOUNT_BATTLE, BattleMount),
	%%加载近况数据
	NewRecent = load_recent_data(Player#player.id),
	{NewRecent,BattleMount}.

%%玩家登陆后首次点击斗兽时加载近况数据
load_recent_data(PlayerId) ->
	%加载挑战次数与玩家斗兽近况数据
	case db_agent:select_mount_recent(PlayerId) of
		[] ->
			%%为该玩家插入一条近况数据, 第一次
			Rdata = [PlayerId,0,0,0,1,[]],
			Rid = db_agent:add_mount_recent(Rdata),
			NewRecent = [Rid | Rdata],
			New = list_to_tuple([ets_mount_recent| NewRecent]),
			ets:insert(?ETS_MOUNT_RECENT,New),
			New;			
		R ->
			ArenaR = list_to_tuple([ets_mount_recent|R]),
			Recent = 
				case util:string_to_term(tool:to_list(ArenaR#ets_mount_recent.recent)) of
					undefined ->
						[];
					Rec ->
						Rec
				end,
			{Gold_times,Cge_times} = count_cge_times(ArenaR),
			NewCost = 
				if 
					ArenaR#ets_mount_recent.last_cost_time =:= 0 ->
						1;
					true ->
						ArenaR#ets_mount_recent.last_cost_time
				end,

			New = ArenaR#ets_mount_recent{last_cost_time = NewCost,recent = Recent, cge_times = Cge_times,gold_cge_times = Gold_times},
			ets:insert(?ETS_MOUNT_RECENT, New),
			New
	end.

%%近况时间处理
make_recent_time(Rtime,Str) ->
	Now = util:unixtime(),
	TimeStr = 
	if Now > Rtime ->
		   Ret = Now - Rtime,
		   if Ret < 3600 ->
				  io_lib:format("~p分钟前", [trunc(Ret/60)+1]);
			  Ret < 86400 ->
				  io_lib:format("~p小时前", [trunc(Ret/3600)+1]);
			  true ->
				  io_lib:format("~p天前", [trunc(Ret/86400)+1])
		   end;
	   true ->
		   ""
	end,
	io_lib:format("~s，~s", [TimeStr,Str]).

%%加入一条近况
add_recent(ElemA,ElemB,OldA,OldB,IsAcker) ->	
	{Ar,Br} = 
		case IsAcker of
			true -> %%A是挑战者
				if length(OldA) =:= 0 -> %% A在竞技榜外
					   {[ElemA],[ElemB | OldB]};
				   true -> %% A在竞技榜内
					   {[ElemA | OldA],[ElemB | OldB]}
				end;
			false ->
				if length(OldB) =:= 0 -> %% B在竞技榜外
					   {[ElemA | OldA],[ElemB]};
				   true -> %% B在竞技榜内
					   {[ElemA | OldA],[ElemB | OldB]}
				end
		end,
	%%限制为 MAX_RECENT 条近况
	{lists:sublist(Ar, 1, ?MAX_RECENT), lists:sublist(Br, 1, ?MAX_RECENT)}.

%%通过技能id取名字
get_name_color(Color) ->
	case Color of
		1 ->%%白
			"#ffffff";
		2 ->%%绿			
			"#00ff33";
		3 ->%%蓝
			"#313bdd";
		4 ->%%金
			"#f8ef38";
		5 ->%%紫
			"#8800ff";
		_ ->%%白
			"#ffffff"
	end.

%%竞技后，坐骑互换名次，A是胜利者, IsPeace是否平局， IsAcker表示A是否挑战者
exchange_rank(A,B,IsPeace,IsAcker,BattleId,_Rounds) ->
	%%?DEBUG("IsAcker = ~p",[IsAcker]),
	case IsPeace of
		true ->  %%平局
			skip;
		false ->
			%%生成近况字符窜，更新recent
			Now = temp_fun2(util:unixtime()),
			Ar = 
				case ets:lookup(?ETS_MOUNT_RECENT, A#ets_mount_arena.player_id) of
					[] ->
						load_recent_data(A#ets_mount_arena.player_id);
					[Ra|_OtherA] ->
						Ra
				end,
			Br = 
				case ets:lookup(?ETS_MOUNT_RECENT, B#ets_mount_arena.player_id) of
					[] ->
						load_recent_data(B#ets_mount_arena.player_id);
					[Rb|_OtherB] ->
						Rb
				end,
			case Ar =/= [] andalso Br =/= [] of
				true ->
					case IsAcker of
						false -> %%A 防守获胜， 排名不变
							StrA = io_lib:format("<font color='#e8ef38'><a href='event:~p'>~s</a></font>的<font color='~s'><a href='event:~p,~p'>~s</a></font>挑战你的<font color='~s'><a href='event:~p,~p'>~s</a></font>，你获胜了，排名不变！",
										 [B#ets_mount_arena.player_id,B#ets_mount_arena.player_name,
										  get_name_color(B#ets_mount_arena.mount_color),B#ets_mount_arena.mount_id,B#ets_mount_arena.player_id,
										  B#ets_mount_arena.mount_name,get_name_color(A#ets_mount_arena.mount_color),A#ets_mount_arena.mount_id,A#ets_mount_arena.player_id,
										  A#ets_mount_arena.mount_name]),
							StrB = io_lib:format("你的<font color='~s'><a href='event:~p,~p'>~s</a></font>挑战<font color='#e8ef38'><a href='event:~p'>~s</a></font>的<font color='~s'><a href='event:~p,~p'>~s</a></font>，你战败了，排名不变！",
										 [get_name_color(B#ets_mount_arena.mount_color),B#ets_mount_arena.mount_id,B#ets_mount_arena.player_id,
										  B#ets_mount_arena.mount_name,
										  A#ets_mount_arena.player_id,A#ets_mount_arena.player_name,
										  get_name_color(A#ets_mount_arena.mount_color),A#ets_mount_arena.mount_id,A#ets_mount_arena.player_id,
										  A#ets_mount_arena.mount_name]),
							{NewRecentA, NewRecentB} = add_recent({Now,StrA,BattleId},{Now,StrB,BattleId},Ar#ets_mount_recent.recent,Br#ets_mount_recent.recent,IsAcker),
							Arestr = util:term_to_string(NewRecentA),
							Brestr = util:term_to_string(NewRecentB),
							{_Count_Gold_times,NewCgeTimes} = arena_times(Br,add,0),
							ets:insert(?ETS_MOUNT_RECENT, Ar#ets_mount_recent{recent = NewRecentA}),
							ets:insert(?ETS_MOUNT_RECENT, Br#ets_mount_recent{cge_times = NewCgeTimes,recent = NewRecentB, last_cge_time = Now}),
							%% 							ets:insert(?ETS_MOUNT_ARENA,A#ets_mount_arena{recent_win = 1, win_times = WinTimes}),
							ets:insert(?ETS_MOUNT_ARENA,B#ets_mount_arena{recent_win = 2, win_times = 0}),
							db_agent:update_mount_recent([{recent, Arestr}],[{player_id, A#ets_mount_arena.player_id}]),
							db_agent:update_mount_recent([{cge_times,NewCgeTimes},{recent,Brestr},{last_cge_time,Now}],[{player_id,B#ets_mount_arena.player_id}]),
							db_agent:update_mount_arena([{recent_win,2},{win_times,0}],[{id,B#ets_mount_arena.id}]);								   
						true ->  %%A 挑战获胜， 排名互换A#ets_mount_arena.rank < B#ets_mount_arena.rank
								if  A#ets_mount_arena.rank =< 5 andalso  A#ets_mount_arena.rank >= 1
									  andalso B#ets_mount_arena.rank =< 5 andalso  B#ets_mount_arena.rank >= 1
									  andalso A#ets_mount_arena.rank < B#ets_mount_arena.rank ->  %%只有前五名的 A 挑战排名比自己低但也是前五名的 B
										StrA = io_lib:format("你的<font color='~s'><a href='event:~p,~p'>~s</a></font>挑战<font color='#e8ef38'><a href='event:~p'>~s</a></font>的<font color='~s'><a href='event:~p,~p'>~s</a></font>，你获胜了，排名不变！",
															[get_name_color(A#ets_mount_arena.mount_color),A#ets_mount_arena.mount_id,A#ets_mount_arena.player_id,
															 A#ets_mount_arena.mount_name,B#ets_mount_arena.player_id,B#ets_mount_arena.player_name,
															 get_name_color(B#ets_mount_arena.mount_color),
															 B#ets_mount_arena.mount_id,B#ets_mount_arena.player_id,B#ets_mount_arena.mount_name]),
									   StrB = io_lib:format("<font color='#e8ef38'><a href='event:~p'>~s</a></font>的<font color='~s'><a href='event:~p,~p'>~s</a></font>挑战你的<font color='~s'><a href='event:~p,~p'>~s</a></font>，你战败了，排名不变！",
															[A#ets_mount_arena.player_id,A#ets_mount_arena.player_name,
															 get_name_color(A#ets_mount_arena.mount_color),
															 A#ets_mount_arena.mount_id,A#ets_mount_arena.player_id,
															 A#ets_mount_arena.mount_name,
															 get_name_color(B#ets_mount_arena.mount_color),
															 B#ets_mount_arena.mount_id,B#ets_mount_arena.player_id,
															 B#ets_mount_arena.mount_name]),
									   {_Count_Gold_times,NewCgeTimes} = arena_times(Ar,add,0),
									   WinTimes = A#ets_mount_arena.win_times+1,
									   if (WinTimes rem 10) =:= 0 ->
											  lib_chat:broadcast_sys_msg(1, io_lib:format("<font color = '#FFCF00'>[~s]</font>的~s势如破竹，在斗兽中连胜达到~p次！", [A#ets_mount_arena.player_name,A#ets_mount_arena.mount_name,WinTimes]));
										  true ->
											  skip
									   end,
									   {NewRecentA, NewRecentB} = add_recent({Now,StrA,BattleId},{Now,StrB,BattleId},Ar#ets_mount_recent.recent,Br#ets_mount_recent.recent,IsAcker),
									   ets:insert(?ETS_MOUNT_RECENT, Br#ets_mount_recent{recent = NewRecentB}),
									   ets:insert(?ETS_MOUNT_RECENT, Ar#ets_mount_recent{cge_times = NewCgeTimes,recent = NewRecentA, last_cge_time = Now}),
									   ets:insert(?ETS_MOUNT_ARENA,A#ets_mount_arena{recent_win = 1, win_times = WinTimes}),
									   ets:insert(?ETS_MOUNT_ARENA,	B#ets_mount_arena{recent_win = 2, win_times = 0}),
									   Arestr = util:term_to_string(NewRecentA),
									   Brestr = util:term_to_string(NewRecentB),
									   if Ar#ets_mount_recent.player_id =:= Br#ets_mount_recent.player_id ->
											  db_agent:update_mount_recent([{cge_times,NewCgeTimes},{win_times,WinTimes},{recent,Arestr},{last_cge_time,Now}], [{player_id,A#ets_mount_arena.player_id}]),
											  db_agent:update_mount_arena([{win_times,WinTimes}, {recent_win,1}], [{id,A#ets_mount_arena.id}]),
											  db_agent:update_mount_arena([{recent_win,2},{win_times, 0}], [{id,B#ets_mount_arena.id}]);
										  true ->
											  db_agent:update_mount_recent([{cge_times,NewCgeTimes},{win_times,WinTimes},{recent,Arestr},{last_cge_time,Now}], [{player_id,A#ets_mount_arena.player_id}]),
											  db_agent:update_mount_recent([{recent,Brestr}], [{player_id,B#ets_mount_arena.player_id}]),
											  db_agent:update_mount_arena([{win_times,WinTimes},{recent_win,1}], [{id,A#ets_mount_arena.id}]),
											  db_agent:update_mount_arena([{recent_win,2},{win_times, 0}], [{id,B#ets_mount_arena.id}])
									   end;
								   true ->
									   StrA = io_lib:format("你的<font color='~s'><a href='event:~p,~p'>~s</a></font>挑战<font color='#e8ef38'><a href='event:~p'>~s</a></font>的<font color='~s'><a href='event:~p,~p'>~s</a></font>，你战胜了，升至第~p名！", 
															[get_name_color(A#ets_mount_arena.mount_color),
															 A#ets_mount_arena.mount_id,A#ets_mount_arena.player_id,
															 A#ets_mount_arena.mount_name,B#ets_mount_arena.player_id,
															 B#ets_mount_arena.player_name,get_name_color(B#ets_mount_arena.mount_color),
															 B#ets_mount_arena.mount_id,B#ets_mount_arena.player_id,
															 B#ets_mount_arena.mount_name, B#ets_mount_arena.rank]),
									   if A#ets_mount_arena.rank > ?MAX_MOUNT_NUM -> %%榜外坐骑发起的挑战
											  StrB = io_lib:format("<font color='#e8ef38'><a href='event:~p'>~s</a></font>的<font color='~s'><a href='event:~p,~p'>~s</a></font>挑战你的<font color='~s'><a href='event:~p,~p'>~s</a></font>，你战败了，跌至~p名之后！",
																   [A#ets_mount_arena.player_id,A#ets_mount_arena.player_name,get_name_color(A#ets_mount_arena.mount_color),
																	A#ets_mount_arena.mount_id,A#ets_mount_arena.player_id,
																	A#ets_mount_arena.mount_name,
																	get_name_color(B#ets_mount_arena.mount_color),
																	B#ets_mount_arena.mount_id,B#ets_mount_arena.player_id,
																	B#ets_mount_arena.mount_name,?MAX_MOUNT_NUM]);
										  true ->
											  StrB = io_lib:format("<font color='#e8ef38'><a href='event:~p'>~s</a></font>的<font color='~s'><a href='event:~p,~p'>~s</a></font>挑战你的<font color='~s'><a href='event:~p,~p'>~s</a></font>，你战败了，跌至~p名！",
																   [A#ets_mount_arena.player_id,A#ets_mount_arena.player_name,get_name_color(A#ets_mount_arena.mount_color),
																	A#ets_mount_arena.mount_id,A#ets_mount_arena.player_id,
																	A#ets_mount_arena.mount_name,get_name_color(B#ets_mount_arena.mount_color),
																	B#ets_mount_arena.mount_id,B#ets_mount_arena.player_id,
																	B#ets_mount_arena.mount_name, A#ets_mount_arena.rank])
									   end,
									   {_Count_Gold_times,NewCgeTimes} = arena_times(Ar,add,0),
									   WinTimes = A#ets_mount_arena.win_times+1,
									   if (WinTimes rem 10) =:= 0 ->
											  lib_chat:broadcast_sys_msg(1, io_lib:format("<font color = '#FFCF00'>[~s]</font>的~s势如破竹，在斗兽中连胜达到~p次！", [A#ets_mount_arena.player_name,A#ets_mount_arena.mount_name,WinTimes]));
										  true ->
											  skip
									   end,
									   if B#ets_mount_arena.rank =:= 1 ->
											  lib_chat:broadcast_sys_msg(1, io_lib:format("<font color = '#FFCF00'>[~s]</font>的~s击败了<font color = '#FFCF00'>[~s]</font>的~s，登上了斗兽第一的宝座！", [A#ets_mount_arena.player_name,A#ets_mount_arena.mount_name,B#ets_mount_arena.player_name,B#ets_mount_arena.mount_name]));
										  true ->
											  skip
									   end,
									   {NewRecentA, NewRecentB} = add_recent({Now,StrA,BattleId},{Now,StrB,BattleId},Ar#ets_mount_recent.recent,Br#ets_mount_recent.recent,IsAcker),
									   ets:insert(?ETS_MOUNT_ARENA, A#ets_mount_arena{win_times = WinTimes, rank = B#ets_mount_arena.rank, recent_win = 1}),
									   ets:insert(?ETS_MOUNT_ARENA, B#ets_mount_arena{rank = A#ets_mount_arena.rank,recent_win = 2, win_times = 0}),
									   ets:insert(?ETS_MOUNT_RECENT, Br#ets_mount_recent{recent = NewRecentB}),
									   ets:insert(?ETS_MOUNT_RECENT, Ar#ets_mount_recent{cge_times = NewCgeTimes,recent = NewRecentA, last_cge_time = Now}),
									   Arestr = util:term_to_string(NewRecentA),
									   Brestr = util:term_to_string(NewRecentB),
									   if Ar#ets_mount_recent.player_id =:= Br#ets_mount_recent.player_id ->
											  db_agent:update_mount_recent([{cge_times,NewCgeTimes},{win_times,WinTimes},{recent,Arestr},{last_cge_time,Now}], [{player_id,A#ets_mount_arena.player_id}]),
											  db_agent:update_mount_arena([{win_times,WinTimes},{rank,B#ets_mount_arena.rank},{recent_win,1}], [{id,A#ets_mount_arena.id}]),
											  db_agent:update_mount_arena([{rank,A#ets_mount_arena.rank},{recent_win,2},{win_times, 0}], [{id,B#ets_mount_arena.id}]);
										  true ->
											  db_agent:update_mount_recent([{cge_times,NewCgeTimes},{win_times,WinTimes},{recent,Arestr},
																			{last_cge_time,Now}], [{player_id,A#ets_mount_arena.player_id}]),
											  db_agent:update_mount_recent([{recent,Brestr}], [{player_id,B#ets_mount_arena.player_id}]),
											  db_agent:update_mount_arena([{win_times,WinTimes},{rank,B#ets_mount_arena.rank},{recent_win,1}], 
																		  [{id,A#ets_mount_arena.id}]),
											  db_agent:update_mount_arena([{rank,A#ets_mount_arena.rank},{recent_win,2},{win_times, 0}], 
																		  [{id,B#ets_mount_arena.id}])
									   end
								end
					end;
				false->
					%%?DEBUG("what the fuck , bug!!!! ",[]),
					skip
			end
	end.

%%打开坐骑竞技面板
open_arena_panel(Player,NowNum,Mount)->
	%%自己的斗兽信息
	Ms = ets:fun2ms(fun(Ma) when Ma#ets_mount_arena.player_id =:= Player#player.id andalso Ma#ets_mount_arena.mount_id =:= Mount#ets_mount.id  -> Ma end),
	%%判断当前出战坐骑是否入榜,根据这个找出不同的待挑战者
	case ets:select(?ETS_MOUNT_ARENA,Ms) of
		[]->
			%%正常情况不会出现这种情况了，因为玩家登录时就已经加载自己的斗兽榜数据
			rank_by_login(Mount,Player);
		[My|_Rets] ->
			{Mr,_Battle} = 
				case ets:lookup(?ETS_MOUNT_RECENT, Player#player.id) of
					[] ->
						load_single_mount_br(Player,Mount);
					[Recent|_Other] ->
						{Recent,[]}
				end,
			%%计算两个次数(当天已使用金币增加次数、已使用挑战次数)
			{Gold_times,Cge_times} = arena_times(Mr,client,Player#player.vip),
			%%这个是发给客户端的数据，并不是内存数据
			NewRecent = Mr#ets_mount_recent{cge_times = Cge_times,gold_cge_times = Gold_times},
			%%四位
			OtherRankers = get_previous_four(My#ets_mount_arena.rank,NowNum),
			BattleMount = parse_to_battle_data(Mount),
			ets:insert(?ETS_MOUNT_BATTLE, BattleMount),
			{ok, BinData} = pt_16:write(16042,[1,My,NewRecent,OtherRankers]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end.

%%使用元宝增加挑战次数
add_cge_times(Mr,Player) ->
	Now = util:unixtime(),
	NeedGold = count_cge_need(Mr,Now),

	case goods_util:is_enough_money(Player, NeedGold, gold) of
		false ->
			{ok,Bin} = pt_16:write(16046,2),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin);
		true ->			
			case Player#player.other#player_other.pid of
				undefined ->
					skip;
				Pid ->
					GoldTimes = 
						case util:is_same_date(Now,Mr#ets_mount_recent.last_cost_time) of
							true ->
								Mr#ets_mount_recent.gold_cge_times + 1;
							false ->
								%不同一天，用元宝增加次数是0
								0+1
						end,
					ets:insert(?ETS_MOUNT_RECENT, Mr#ets_mount_recent{last_cost_time = Now,gold_cge_times = GoldTimes}),
					db_agent:update_mount_recent([{last_cost_time,Now},{gold_cge_times,GoldTimes}],[{id,Mr#ets_mount_recent.id}]),
					Pid ! {'ADD_MOUNT_ARENA_TIMES',NeedGold}
			end
	end.

%%增加挑战次数消费元宝的计算方式
count_cge_need(Mr,Now) ->
	LastTime = Mr#ets_mount_recent.last_cost_time,
	case util:is_same_date(Now,LastTime) of
		true ->
			(Mr#ets_mount_recent.gold_cge_times + 1) * 2;
		false ->
			%%清零
			2
	end.

%%VIP挑战次数加成
%% [1月卡，2季卡，3半年卡，4周卡,5一天卡，6体验卡]
vip_add_times(Vip)->
	case Vip of
		1 ->
			2;
		2 ->
			4;
		3 ->
			6;
		4 ->
			2;
		_ ->
			0
	end.

%%斗兽竞技排行榜(20 名)
get_arena_ranker(PidSend) ->
	Ranks = lists:seq(1, ?RANK_NUM),
	Minfos = [lib_mount_arena:get_arena_info_by_rank(N) || N <- Ranks],
	Minfos1 = lists:filter(fun(E)->E/=[] end, Minfos),
	{ok,BinData} = pt_16:write(16045,Minfos1),
	lib_send:send_to_sid(PidSend,BinData).

%%外部调用，同步更新竞技榜坐骑自身属性，
sync_mount_data(Mount)->
	Pid = mod_mount_arena:get_mod_mount_arena_pid(),
	Pid ! {'SYNC_MOUNT_DATA',Mount}.

%%更新竞技榜中坐骑属性信息
update_arena_mount(Mount) ->
	Ms = ets:fun2ms(fun(M) when M#ets_mount_arena.mount_id =:= Mount#ets_mount.id -> M end),
	[Hp,Mp,Att,Def,Hit,Dodge,Crit,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil] = data_mount:get_prop_mount(Mount),
	M_val = data_mount:count_mount_batt([Hp,Mp,Att,Def,Hit,Dodge,Crit,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil]),
	%%需要更新的字段
	[Step,Title,Color,Level,TypeId] = [Mount#ets_mount.step, Mount#ets_mount.title, Mount#ets_mount.color, Mount#ets_mount.level,
									   Mount#ets_mount.goods_id],
	Name = Mount#ets_mount.name,	
	case ets:select(?ETS_MOUNT_ARENA,Ms) of
		[] ->
			%%更新DB
			db_agent:update_mount_arena([{mount_step,Step},{mount_title,Title},{mount_color,Color},{mount_level,Level},{mount_typeid,TypeId},{mount_name,Name},{mount_val,M_val}],
										[{mount_id,Mount#ets_mount.id}]);      
		[Minfo|_R] ->
			New = Minfo#ets_mount_arena{mount_step = Step,mount_title = Title,mount_color =  Color, mount_level = Level,mount_typeid = TypeId, mount_name = Name, mount_val =  M_val},
			NewBattle = parse_to_battle_data(Mount),
			%%更新内存
			ets:insert(?ETS_MOUNT_ARENA, New),
			ets:insert(?ETS_MOUNT_BATTLE, NewBattle),
			%%更新DB
			db_agent:update_mount_arena([{mount_step,Step},{mount_title,Title},{mount_color,Color},{mount_level,Level},{mount_typeid,TypeId},{mount_name,Name},{mount_val,M_val}],
										[{id,Minfo#ets_mount_arena.id}])
	end.

%%登陆排名处理
%%玩家进程调用，登陆操作与坐骑出战会执行
rank_by_login(Mount,Player) ->
	case Mount of
		[] ->
			skip;
		M when erlang:is_record(M,ets_mount) ->
			ArenaPid = mod_mount_arena:get_mod_mount_arena_pid(),
			ArenaPid ! {'RANK_BY_LOGIN',M,Player#player.id,Player#player.nickname,Player#player.realm,Player#player.vip}
	end.

%%

%%根据介数取名字
get_name_by_step(Step,GoodsId) ->
	if Step =< 2 ->
		  data_mount:get_name_by_goodsid(GoodsId);
	   true ->
		   [_Gid,Name] = data_mount:get_next_step_type_name(Step),
		   Name
	end.

%%根据排名获取信息
get_arena_info_by_rank(Rank) ->
	if Rank =< 0 ->
		   [];
	   true ->
		   case ets:lookup(?ETS_MOUNT_ARENA, Rank) of
			   []->
				   %%补偿丢失数据;
				   get_lost_data([Rank]),
				   case ets:lookup(?ETS_MOUNT_ARENA, Rank) of
					   [] ->
						   [];
					   [Mo|_Other] ->
						   Mo
				   end;
			   [Minfo|_R] ->
				   Minfo
		   end
end.

%%根据排名获取面板上其他四位要显示的竞技对象
get_previous_four(Rank,_NowNum)->
	if Rank =< 0 ->  %%不正常
		   [];
	   Rank =< 5 ->  %%位于前五位的，显示其他四位
		   Five = [1,2,3,4,5],
		   Four = lists:delete(Rank, Five),
		   List2 = [get_arena_info_by_rank(Erank) || Erank <- Four ],
		   
		   lists:filter(fun(E)->E/=[] end, List2);
	   Rank > ?MAX_MOUNT_NUM -> 
		   Four = [?MAX_MOUNT_NUM-3,?MAX_MOUNT_NUM-2,?MAX_MOUNT_NUM-1,?MAX_MOUNT_NUM],
		   List2 = [get_arena_info_by_rank(Erank) || Erank <- Four ],
		   lists:filter(fun(E)->E/=[] end, List2);
	   true ->%%榜内数据走这里
		    List2 = [get_arena_info_by_rank(R) || R <- [Rank-4,Rank-3,Rank-2,Rank-1]],
			lists:filter(fun(E)->E/=[] end, List2)
	end.
	
%从数据库提取一个坐骑的战斗信息
get_battle_info_db(MountId)->
	case db_agent:select_mount_info(MountId) of
		[]->
			skip;
		MountData ->
			Mount = list_to_tuple([ets_mount|MountData]),
			BattAtt = data_mount:get_prop_mount(list_to_tuple([ets_mount|MountData])),
			[_Hp,_Mp,_Att,_Def,_Hit,_Dodge,_Crit,_Anti_wind,_Anti_fire,_Anti_water,_Anti_thunder,_Anti_soil] = BattAtt,
			Hit = _Hit / 1000 + 0.85,
			Dodge = (_Dodge) / 1500,
			Crit = (_Crit) / 2000,
			Mount_Batt_val = data_mount:count_mount_batt(BattAtt),
			SkillList = [Mount#ets_mount.skill_1,Mount#ets_mount.skill_2,Mount#ets_mount.skill_3,Mount#ets_mount.skill_4,
										Mount#ets_mount.skill_5,Mount#ets_mount.skill_6,Mount#ets_mount.skill_7,Mount#ets_mount.skill_8],
		   F = fun(MountSkill) ->
					   [_Pos, SkillId, SkillType, SkillLevel, _SkillStep, _SkillExp]  = util:string_to_term(tool:to_list(MountSkill)),
					   if SkillType >= 1 andalso SkillType < 14 ->
							  {SkillId,SkillLevel};
						  true ->
							  {14,0}
					   end
			   end,
			Skills = [F(Ms) || Ms <- SkillList],
			BattleData = [Mount#ets_mount.id,Mount#ets_mount.player_id]++BattAtt++[Mount#ets_mount.level,Skills,Mount_Batt_val],
			MountBattel = list_to_tuple([ets_mount_battel|BattleData]),
			ets:insert(?ETS_MOUNT_BATTLE, MountBattel#ets_mount_battle{hit = Hit, dodge = Dodge, crit = Crit})
	end.

%%是否触发技能(参数：坐骑已装备的技能)返回{技能类型ID,}
%%IsAtker:是否攻击者
%% [Hp,Mp,Att,Def,Hit,Dodge,Crit,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,Level,Skills,Batt]
%%坐骑本次攻击触发技能的概率？(无论何种技能)
%%（气血1,法力2,攻击3,防御4,命中5,闪避6,暴击7,风抗8,火抗9,水抗10,雷抗11,土抗12,全抗13）

get_skills_by_type(Type) ->
	case Type of
		3 ->
			?SKILL_ATTACK;
		5 ->
			?SKILL_HIT;
		7 ->
			?SKILL_CRICT;
		6 ->
			?SKILL_DODGE;
		9 ->
			?SKILL_SINGLE_ANTI;
		13 ->
			?SKILL_ANTI;
		4 ->
			?SKILL_DEF;
		1 ->
			?SKILL_HP;
		_ ->
			[]
	end.	

%%单抗技能概率
single_anti_rate(Skills)->
	Rate = util:rand(1,100),
	case length(Skills) of
		1 ->
			lists:nth(1, Skills);
		2 ->
			if Rate =< 50 ->
				   lists:nth(1, Skills);
			   true ->
				   lists:nth(2, Skills)
			end;
		3 ->
			if Rate =< 33 ->
				   lists:nth(1, Skills);
			   Rate =< 66 ->
				   lists:nth(2, Skills);
			   true ->
				   lists:nth(3, Skills)
			end;
		4 ->
			if Rate =< 25 ->
				   lists:nth(1, Skills);
			   Rate =< 50 ->
				   lists:nth(2, Skills);
			   Rate =< 75 ->
				   lists:nth(3, Skills);
			   true ->
				   lists:nth(4, Skills)
			end;
		5 ->
			if Rate =< 20 ->
				   lists:nth(1, Skills);
			   Rate =< 40 ->
				   lists:nth(2, Skills);
			   Rate =< 60 ->
				   lists:nth(3, Skills);
			   Rate =< 80 ->
				   lists:nth(4, Skills);
			   true ->
				   lists:nth(5, Skills)
			end
	end.
	

%%查找该技能是否已经装备
is_skill_learn(Sid,Skills) ->
	case lists:keyfind(Sid, 1, Skills) of
		false ->
			false;
		Data ->
			Data
	end.

%%本轮攻击，一个战斗单位是否触发了技能
is_tri_skill(Skills,IsAtker)->
	%%触发技能的总概率
	Rnd = util:rand(1,100),
	Is_tri = 
		if Rnd < ?SKILL_RATE ->
			   yes;
		   true ->
			   no
		end,
	case Is_tri of
		yes ->
			%%坐骑随机触发一种技能类型
			Type_Rnd = util:rand(1,100),
			%%?DEBUG("LIB_MOUNT_ARENA 77 ......................",[]),
			Key = 
				%%根据是否攻击者来获取触发的技能
				case IsAtker of
					true -> %%攻击者（只能触发攻击类技能）
						if Type_Rnd =< 25 ->
							   %%?DEBUG("LIB_MOUNT_ARENA 482 CASE_CLAUSE.......................",[]),
							   3; %%攻击类型
						   Type_Rnd =< 65 ->
							   5; %%命中类型
						   Type_Rnd =< 100 ->
							   7; %%暴击类型
						   true ->
							   5
						end;
					false ->
						if Type_Rnd < 20 ->
							   6; %%闪避类型
						   Type_Rnd < 50 ->
							   4; %%防御类型
						   Type_Rnd =< 80 ->
							   13; %%全抗类型
						   Type_Rnd < 100 ->
							   1; %%加血类型
						   true ->
							   8
						end
				end,
			%%查找坐骑有没有此种技能
			Type_Of_Skills = get_skills_by_type(Key),
			Datas = lists:foldl(fun(Sid,Acc) ->
									   case is_skill_learn(Sid,Skills) of
										   false ->
											   Acc;
										   Data ->
											   [Data|Acc]
									   end
							   end, [], Type_Of_Skills),
			Learneds = length(Datas),
			if Learneds =:= 0 ->
				   {0,0,0};
			   Learneds > 1 ->
				   %%必是单抗类型，需再随机出一个
				   {SkillId,SkillType,SkillLevel} = single_anti_rate(Datas),
				   {SkillId,SkillType,SkillLevel};
			   true ->
				   lists:nth(1, Datas)
			end;			
		no ->
			{0,0,0}
	end.

%%获取技能加成属性值
get_skill_effect(SkillId,SkillType,SkillLv,IsAcker)->
	case IsAcker of
		true ->
			case SkillType of
				3 ->
					%%技能加成效果(技能加成属性值)
					SkillValue = data_mount:get_skill_prop(SkillId,SkillLv),
					[ack,{0,0,SkillValue,0,0}];
				5 ->
					SkillValue = data_mount:get_skill_prop(SkillId,SkillLv),
					[hit,{SkillValue,0,0,0,0}];
				7 ->
					SkillValue = data_mount:get_skill_prop(SkillId,SkillLv),
					[crict,{0,SkillValue,0,0,0}];
				_ ->
					[none,{0,0,0,0,0}]
			end;
		false ->
			case SkillType of
				6 ->
					SkillValue = data_mount:get_skill_prop(SkillId,SkillLv),
					[dodge,{SkillValue,0,0,0,0}];
				13 ->
					SkillValue = data_mount:get_skill_prop(SkillId,SkillLv),
					[anti,{0,SkillValue,0,0,0}];
				4 ->%%防御
					SkillValue = data_mount:get_skill_prop(SkillId,SkillLv),
					[def,{0,0,0,SkillValue,0}];
				1 ->%%气血
					SkillValue = data_mount:get_skill_prop(SkillId,SkillLv),
					[hp,{0,0,0,0,SkillValue}];
				_ ->%%暂时不做单抗
					[none,{0,0,0,0,0}]
			end
	end.

%%取值
get_skill_value([S,{V1,V2,V3,V4,V5}])->
	if V1 =:= 0 andalso V2 =:= 0 andalso V3 =:= 0 andalso V4 =:= 0 andalso V5 =:= 0 ->
		   0;
	   true ->
		   case S of
			   hit ->
				   V1;
			   dodge ->
				   V1;
			   crict ->
				   V2;
			   anti ->
				   V2;
			   ack ->
				   V3;
			   def ->
				   V4;
			   hp ->
				   V5;
			   none ->
				   V3
		   end
	end.

%%计算等级压制的命中和暴击率
level_press_hit(A,B) ->
	Lv = A#ets_mount_battle.level - B#ets_mount_battle.level,
	{Rate_hit, Rate_crit} = 
		if Lv =< -5 ->
			   {-0.04, -0.03};
		   Lv =< -8 ->
			   {-0.06, -0.04};
		   Lv =< -10 ->
			   {-0.08, -0.05};
		   Lv >= 3 ->
			   {0.03, 0.02};
		   Lv >= 5 ->
			   {0.05, 0.03};
		   Lv >= 8 ->
			   {0.08, 0.04};
		   Lv >= 10 ->
			   {0.10, 0.05};
		   true ->
			   {0,0}
		end,
	{Rate_hit, Rate_crit}.

is_dodge(Hit) ->
	Rnd = util:rand(1,1000),
	Rnd > Hit.	

%%战斗函数，递归
mount_battle(A,B,BattleList,Counter,IAhp,IBhp,MaxAhp,MaxBhp) ->
	Round = round(Counter/2),
	%%?DEBUG("iAHP = ~p, IBhp = ~p ~n", [IAhp,IBhp]),
	if IAhp =< 0 -> %%胜利者是B
		   {B,false,lists:reverse(BattleList)};
	   IBhp =< 0 ->
		   {A,false,lists:reverse(BattleList)};
	   Round >= ?MAX_ROUND ->
		   if IBhp > IAhp ->
				  {B,false,lists:reverse(BattleList)};
			  true ->
				  {A,false,lists:reverse(BattleList)}
		   end;
	   true ->
		   Data = mount_attack(A,B,MaxBhp),
		   {_Amid,_SkillName,_SkillType,_SkillValue1,Ahp,_SkillName2,_SkillType2,_SkillValue2,Bhp,_AttType,_Dam} = Data,
		   if Ahp =< 0 -> %%胜利者是B
				  if Counter =:= 0 ->
						 {B,false,[Data]};
					 true ->
						 {B,false,lists:reverse([Data|BattleList])}
				  end;
			  Bhp =< 0 ->
				   if Counter =:= 0 ->
						 {A,false,[Data]};
					 true ->
						 {A,false,lists:reverse([Data|BattleList])}
				   end;
			  Round >= ?MAX_ROUND ->
				  if Bhp > Ahp ->
						 {B,false,lists:reverse(BattleList)};
					 true ->
						 {A,false,lists:reverse(BattleList)}
				  end;
			  true ->
				  mount_battle(B#ets_mount_battle{hp = Bhp},A#ets_mount_battle{hp = Ahp},[Data|BattleList],Counter+1,Bhp,Ahp,MaxBhp,MaxAhp)
		   end
	end.

%%   int:8 攻击者
%%          1 =》 自己
%%          2 =》 对方
%%      string 自己触发的技能名（比如轩辕护体，鬼神）
%%      int:16 自己触发的技能类型（气血1,法力2,攻击3,防御4,命中5,闪避6,暴击7,风抗8,火抗9,水抗10,雷抗11,土抗12,全抗13）
%%      int:16 自己触发技能增加的属性值
%%      int:32 自己当前血量
%%      string 对方触发的技能名
%%      int:16 对方触发的技能类型
%%      int:16 对方触发的技能增加的属性值
%%      int:32 对方当前血量
%%      int:8  攻击类型
%%          1 =》 普通攻击
%%          2 =》 暴击
%%          3 =》 被闪避
%%      int:32 产生的伤害

%%单次攻击
%%A向B发起攻击
mount_attack(A,B,MaxBhp) ->
	%%计算等级压制命中
	{Level_hit, Level_crit} = level_press_hit(A,B),
	%%A是否触发技能
	{SkillId,SkillType,SkillLv} = is_tri_skill(A#ets_mount_battle.skills,true),
	[S,{SkillHit, SkillCrict, SkillAttack,0,0}] = get_skill_effect(SkillId,SkillType,SkillLv,true),
	%%B是否触发技能
	{SkillId2,SkillType2,SkillLv2} = is_tri_skill(B#ets_mount_battle.skills,false),
	[S2,{SkillDodge, SkillAnti, SkillSingle, SkillDef, SkillHp}] = get_skill_effect(SkillId2,SkillType2,SkillLv2,false),
	%%计算实际命中率（攻击者当前命中 - 被攻击者当前闪躲 + 等级压制命中） ? 
	Hit = (A#ets_mount_battle.hit + Level_hit + round(SkillHit/1200) - (B#ets_mount_battle.dodge+round(SkillDodge/1200)))*1000,
	SkillName = data_mount:get_skill_name(SkillId),
	SkillName2 = data_mount:get_skill_name(SkillId2),
	SkillValue1 = get_skill_value([S,{SkillHit, SkillCrict, SkillAttack, 0, 0}]),
	Temp = get_skill_value([S2,{SkillDodge, SkillAnti, SkillSingle, SkillDef, SkillHp}]),
	SkillValue2 = 
		case SkillHp > 0 of
			true ->
				trunc(SkillHp);
			false ->
				Temp
		end,
	case is_dodge(Hit) of
		false ->
			%%公式？
			{DCData, BDef} = {60,B#ets_mount_battle.def+SkillDef},
			DCParam = BDef * (1 + B#ets_mount_battle.level / DCData),
			DC = DCParam / (DCParam + A#ets_mount_battle.level * DCData + 100),			
			%% 暴击率
			Crit = A#ets_mount_battle.crit + Level_crit + SkillCrict/2000,
			{IsCrict,Rdam} = 
				case random:uniform(1000) > Crit * 1000 of
					%% 没暴击
					true ->
						{1,util:ceil(A#ets_mount_battle.atk+SkillAttack)};
					false ->
						{2,util:ceil((A#ets_mount_battle.atk+SkillAttack) * 1.5)}
				end,
			%%伤害
			Dam = trunc(Rdam * (1 - DC)),
			Ahp = A#ets_mount_battle.hp,
			Bhp = 
			  case B#ets_mount_battle.hp =< Dam of
				  true ->
					  0;
				  false ->
					  TempBhp = (B#ets_mount_battle.hp - Dam) + trunc(SkillHp),
					  if TempBhp >= MaxBhp ->
							 MaxBhp;
						 true ->
							 TempBhp
					  end
			  end,			
			{A#ets_mount_battle.mount_id,SkillName,SkillId,SkillValue1,Ahp,SkillName2,SkillId2,SkillValue2,Bhp,IsCrict,Dam};
		true -> %%闪避   攻击者A也有可能触发技能
			Dam = 0,
			Ahp = A#ets_mount_battle.hp,
			Bhp = B#ets_mount_battle.hp,
			%%闪躲方只能触发回血、闪避技能，其他技能要屏蔽
			IsHp = lists:member(SkillId2, ?SKILL_HP),
			IsDodge = lists:member(SkillId2, ?SKILL_DODGE),
			{Dsid,Dbhp} = 
				if IsHp =:= true ->
					   TempBhp = (B#ets_mount_battle.hp - Dam) + trunc(SkillHp/1),
					   CountHp = 
						   if TempBhp >= MaxBhp ->
								  MaxBhp;
							  true ->
								  TempBhp
						   end,
					   {SkillId2,CountHp};
				   IsDodge =:= true ->
					   {SkillId2,Bhp};
				   true ->
					   {0,Bhp}
				end,
			{A#ets_mount_battle.mount_id,SkillName,SkillId,SkillValue1,Ahp,SkillName2,Dsid,SkillValue2,Dbhp,3,Dam}
	end.

%%出手顺序
compare_speed(A,B) ->
	if A#ets_mount_battle.speed > B#ets_mount_battle.speed ->
		   {A,B};
	   A#ets_mount_battle.speed =:= B#ets_mount_battle.speed ->
		   Rate = util:rand(1,100),
		   if Rate =< 50 ->
				  {A,B};
			  true ->
				  {B,A}
		   end;
	   true ->
		   {B,A}
	end.

%%计算坐骑速度
count_speed(Mount) ->
	if
		is_record(Mount,ets_mount) ->
			GoodsInfo = goods_util:get_goods(Mount#ets_mount.id),
			if is_record(GoodsInfo,goods) ->
				   if
					   GoodsInfo#goods.stren > 0 ->
						   GoodsInfo#goods.speed;
					   true ->
						   NewSpeed =
							   case Mount#ets_mount.step of
								   0 -> 0;
								   1 -> 30;
								   2 ->
									   Gid = GoodsInfo#goods.goods_id,
									   if Gid =:= 16004 orelse Gid =:= 16005 ->
											  65;
										  Gid =:= 16006 orelse Gid =:= 16007->
											  60;
										  true ->
											  45
									   end;
								   3 -> 55;
								   _ -> 65
							   end,
						   NewSpeed
				   end;
			   true ->
				  GoodsInfo1 = goods_util:get_goods_by_id(Mount#ets_mount.id),
				  if is_record(GoodsInfo1,goods) == false ->
						 0;
					 true ->
						  if
					   GoodsInfo1#goods.stren > 0 ->
						   GoodsInfo1#goods.speed;
					   true ->
						   NewSpeed =
							   case Mount#ets_mount.step of
								   0 -> 0;
								   1 -> 30;
								   2 -> 
									   Gid = GoodsInfo1#goods.goods_id,
									   if Gid =:= 16004 orelse Gid =:= 16005 ->
											  65;
										  Gid =:= 16006 orelse Gid =:= 16007->
											  60;
										  true ->
											  45
									   end;
								   3 -> 55;
								   _ -> 65
							   end,
						   NewSpeed
				   end					 
				  end
			end;
		true ->
			0
	end.

%%次数
arena_times(Re,Type,Vip)->
	%%先计算今天已使用金币次数，已挑战个数
	{Gtimes,Ctimes} = count_cge_times(Re),
	case Type of
		add ->%%挑战后要增加次数
			{Gtimes,Ctimes+1};
		client ->
			VipAdd = vip_add_times(Vip),
			Total = ?MAX_CGE_TIMES + VipAdd,
			NewTimes = Total + Gtimes - Ctimes,
			{Gtimes,NewTimes};
		_ ->
			{10,10}
	end.

%%针对360平台42区
update_data()->
	case db_agent:get_42f_info() of
		[]->
			?DEBUG("skip",[]),
			[];
		Data ->
			List = lists:sublist(Data, 4),
			lists:foldl(fun(D,Acc) ->
								M = list_to_tuple([ets_mount_arena|D]),
								[Rank,L] = Acc,
								%%加载战斗信息( 从坐骑原始数据提取 )
								case db_agent:select_mount_info(M#ets_mount_arena.mount_id) of
									[] ->
										%%如果玩家放生坐骑，就不正常了
										skip;
									Mount ->
										BattleMount = parse_to_battle_data(list_to_tuple([ets_mount|Mount])),
										ets:insert(?ETS_MOUNT_BATTLE, BattleMount)
								end,
								%%加载近况数据，因为被人挑战时，也要改数据的
								load_recent_data(M#ets_mount_arena.player_id),
								ets:insert(?ETS_MOUNT_ARENA, M#ets_mount_arena{rank = Rank}),
								db_agent:update_mount_arena([{rank,Rank}],[{id,M#ets_mount_arena.id}]),
								[Rank - 1,[M#ets_mount_arena.player_id|L]]
						end,[500,[]], List)
	end.

%%补回丢失的数据
get_lost_data(LostRanks)->
	Data = 
		case db_agent:get_42f_info() of
			[]->
				case db_agent:get_out_arena_info() of
					[] ->
						[];
					OutMax ->
						OutMax
				end;
			Gtzero ->
				Gtzero
		end,
	List = lists:sublist(Data, length(LostRanks)),
	lists:foldl(fun(D,Acc) ->
						M = list_to_tuple([ets_mount_arena|D]),
						[[Rank|Rs],L] = Acc,
						%%加载战斗信息( 从坐骑原始数据提取 )
						case db_agent:select_mount_info(M#ets_mount_arena.mount_id) of
							[] ->
								%%如果玩家放生坐骑，就不正常了
								skip;
							Mount ->
								BattleMount = parse_to_battle_data(list_to_tuple([ets_mount|Mount])),
								ets:insert(?ETS_MOUNT_BATTLE, BattleMount)
						end,
						%%加载近况数据，因为被人挑战时，也要改数据的
						load_recent_data(M#ets_mount_arena.player_id),
						ets:insert(?ETS_MOUNT_ARENA, M#ets_mount_arena{rank = Rank}),
						db_agent:update_mount_arena([{rank,Rank}],[{id,M#ets_mount_arena.id}]),
						[Rs,[M#ets_mount_arena.player_id|L]]
				end,[LostRanks,[]], List).
					
%%生成战报
make_battle_record(WinnerId,LosersId,A_mount_id,A_player_name,A_mount_name,A_mount_color,A_mount_type,
				   B_mount_id,B_player_name,B_mount_name,B_mount_color,B_mount_type,InitList,Data) ->
	Now = util:unixtime(),
	Rounds = round(length(Data)/2),
	InitStr = util:term_to_string(InitList),
	Str = util:term_to_string(Data),	
	Id = db_agent:add_battle_result(WinnerId,LosersId,Rounds,Now,A_mount_id,A_player_name,A_mount_name,A_mount_color,A_mount_type,
				   B_mount_id,B_player_name,B_mount_name,B_mount_color,B_mount_type,InitStr,Str),
	Rd = #ets_battle_result{id = Id, winner = WinnerId, losers = LosersId, rounds = Rounds, time = Now, a_mount_id = A_mount_id,a_player_name = A_player_name,
							a_mount_name = A_mount_name,a_mount_color = A_mount_color,a_mount_type = A_mount_type,
				   b_mount_id = B_mount_id,b_player_name = B_player_name,b_mount_name = B_mount_name,b_mount_color = B_mount_color,b_mount_type = B_mount_type,init = InitList, battle_data = Data},
	ets:insert(?ETS_BATTLE_RESULT, Rd),
	Id.

%%奖励规则
award_rule_num(Rank) ->
	if 
		Rank =:= 1 ->
			[300,250000,{24821,10}];
		Rank =:= 2 ->
		    [250,180000,{24821,6}];
		Rank =:= 3 ->
			[200,100000,{24821,4}];
		Rank =:= 0 ->
			[20,10000,{24820,1}];
		Rank < 81 ->
			[(101-Rank)*2,100000-1000*(Rank - 1),{24821,1}];
		Rank < 101 ->
			[121 - Rank,21000-500*(Rank-80),{24820,2}];
		Rank > 100 ->
			[20,10000,{24820,1}];
		true ->
			[20,10000,{24820,1}]
	end.

%%获取第一名
get_mount_king() ->
	Pid = mod_mount_arena:get_mod_mount_arena_pid(),
	case catch gen_server:call(Pid, {'GET_KING'}) of
		{'EXIT',_R} ->
			[];
		{true,PlayerId}->
			[PlayerId];
		_ ->
			[]
	end.

%%
award_rule_comment(Rank) ->
	[Cash,Coin,{_Gid,Num}] = award_rule_num(Rank),
	NewRank = 
		if Rank =:= 0 ->
			   500;
		   true ->
			   Rank
		end,
	if NewRank < 81 ->
		   io_lib:format("结算时第~p名的奖励:~p礼券，~p绑定铜，封灵神符*~p",[NewRank,Cash,Coin,Num]);
	   NewRank =:= 500 ->
		   io_lib:format("结算时500名之后的奖励:~p礼券，~p绑定铜，封灵符*~p",[Cash,Coin,Num]);
	   true ->
		  io_lib:format("结算时第~p名的奖励:~p礼券，~p绑定铜，封灵符*~p",[NewRank,Cash,Coin,Num])
	end.

%%
%% Local Functions
%%

%%挑战获得奖励
cge_award(Player,Cge_award) ->
	[_IsWin,Cash,Bcoin] = Cge_award,
	NewPlayer = lib_goods:add_money(Player,Cash,cash,1644),
	NewPlayer2 = lib_goods:add_money(NewPlayer,Bcoin,bcoin,1644),
	{ok,Bin} = pt_16:write(16049,Cge_award),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin),
	NewPlayer2.

%%生成一次奖励数据
create_award()->
	case ets:tab2list(?ETS_MOUNT_ARENA) of
		[] ->
			skip;
		All ->
			case db_agent:select_all_mount_arena() of
				[] ->
					skip;
				Datas ->
					Fdb = fun(D) ->
								  Mn = list_to_tuple([ets_mount_arena|D]),
								  db_agent:update_mount_arena([{rank_award,Mn#ets_mount_arena.rank},{get_ward_time,0}],[{id,Mn#ets_mount_arena.id}])
						  end,
					[Fdb(D) || D <- Datas]
			end,
			F = fun(M)->
						NewM = M#ets_mount_arena{rank_award = M#ets_mount_arena.rank, get_ward_time = 0},
						ets:insert(?ETS_MOUNT_ARENA, NewM)
				end,
			[F(A) || A <- All]
	end.
								  
release_ets(PlayerId)->
	Pid = mod_mount_arena:get_mod_mount_arena_pid(),
	Pid ! {'RELEASE_ETS',PlayerId}.

clear_battle_result() ->
	Pid = mod_mount_arena:get_mod_mount_arena_pid(),
	Pid ! {'CLEARE_BATTLE'}.

after_get_award(NewM) ->
	Pid = mod_mount_arena:get_mod_mount_arena_pid(),
	Pid ! {'AFTER_GET_AWARD',NewM}.

%% test() ->
%% 	case db_agent:get_mount_arena_info() of
%% 		[] ->
%% 			skip;
%% 		Datas ->
%% 			F = fun(R) ->
%% 						Rs = list_to_tuple([ets_mount_arena|R])
%% 				end,
%% 			[F(R) || R <- Datas]
%%     end.

test() ->
	Pid = mod_mount_arena:get_mod_mount_arena_pid(),
	gen_server:call(Pid, {'test_change'}).

test2(Mid)->
	Pid = mod_mount_arena:get_mod_mount_arena_pid(),
	Pid ! {'test_del',Mid}.

%%生成一次奖励数据
%% create_award()->
%% 	case ets:tab2list(?ETS_MOUNT_ARENA) of
%% 		[] ->
%% 			skip;
%% 		All ->
%% 			F = fun(M)->
%% 						Award = #ets_mount_award{pid = M#ets_mount_arena.player_id,mid = M#ets_mount_arena.mount_id,
%% 												 rank = M#ets_mount_arena.rank},
%% 						ets:insert(?ETS_MOUNT_AWARD, Award)
%% 				end,
%% 			[F(M) || M <- All]
%% 	end.

%%工具函数，手工调用，查询坐骑某种类型的技能ID
add_type(Type) ->
	L = lists:seq(1001, 7001),
	lists:foldl(fun(N,Acc) ->
							[Stype,_Scolor] = data_mount:get_skill_type_color(N),
							if Type =:= Stype ->
								   %%?DEBUG("Stype = ~p~n",[Stype]),
								   [N|Acc];
							   true ->
								   Acc
							end 
					end,[], L).	

test(L1,L2) ->
	L3 = L1 - 2 ,
	if L1 =:= 0 ->
		   ?DEBUG("L1 = 0,L2 = ~p~n",[L2]);
	   true ->
		   ?DEBUG("L1 = ~p, L2 = ~p~n",[L1,L2]),
		   test(L2,L3)
	end.
