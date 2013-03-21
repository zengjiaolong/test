%%%-----------------------------------
%%% @Module  : pt_13
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 13角色信息
%%%-----------------------------------
-module(pt_13).
-export([read/2, write/2]).
-include("common.hrl").
%%
%%客户端 -> 服务端 ----------------------------
%%

%%查询自己的信息
read(13001, _) ->
    {ok, myself};

%%查询玩家的信息
read(13004, <<Id:32>>) ->
    {ok, Id};

%%获取快捷栏
read(13007, _) ->
    {ok, get};

%%保存快捷栏
read(13008, <<T:8, S:8, Id:32>>) ->
    {ok, [T, S, Id]};

%%删除快捷栏
read(13009, <<T:8>>) ->
    {ok, T};

%%替换快捷栏
read(13010, <<T1:8, T2:8>>) ->
    {ok, [T1, T2]};

%%更改PK模式
read(13012, <<T:8>>) ->
    {ok, T};

%% 获取BUFF信息
read(13013, _) ->
    {ok, no_param};

%% 获取物品bugff信息
read(13014,_)->
	{ok,no_param};

%% 角色打坐信息
read(13015,_) ->
    {ok, no_param};

%%查询离线时间经验累积
read(13020,_)->
	{ok,[]};

%%兑换离线时间经验累积
read(13021,<<Hours:8,Mult:8>>)->
	{ok,[Hours,Mult]};

%%查询连续上线物品奖励信息
read(13022,<<>>)->
	{ok,[]};

%%领取连续上线物品奖励
read(13023,<<Day:8>>)->
	{ok,[Day]};

%%查询在线时长礼券奖励信息
read(13024,<<>>)->
	{ok,[]};

%%领取在线时长礼券奖励
read(13025,<<Type:8>>)->
	{ok,[Type]};

%%查询魅力信息
read(13026,<<>>)->
	{ok,[]};

%% 获取积分面板积分
read(13027, _)->
	{ok, no_param};

%% 角色改名
read(13028, <<Bin/binary>>) ->
    {NickName, _} = pt:read_string(Bin),
    {ok, [NickName]};


%% 排行榜角色属性
read(13029, <<Id:32>>) ->
    {ok, Id};

%%变性
read(13030, <<Mark:8>>) ->
    {ok, [Mark]};

%%vip免费传送次数
read(13031,<<>>)->
	{ok,[]};

%%查询双修角色列表
read(13040,<<>>)->
	{ok,[]};

%%查找角色名
read(13041, <<Bin/binary>>) ->
    {Nick, _} = pt:read_string(Bin),
    {ok, Nick};

%%发出双修邀请
read(13042, <<Player_Id:32>>) ->
    {ok, Player_Id};

%%设置双修邀请
read(13043, <<Accept:8>>) ->
    {ok, Accept};


%%同意或拒绝双修邀请
read(13045, <<OtherPlayerId:32,Code:8>>) ->
    {ok, [OtherPlayerId,Code]};

%%开始或取消双修动作(Code开始双修1，结束双修2)InitX,Y发起人的原始坐标
read(13046, <<OtherPlayerId:32,Code:8,InitX:16,InitY:16>>) ->
    {ok, [OtherPlayerId,Code,InitX,InitY]};

%%邀请方已经到指定位置
read(13053, <<OtherPlayerId:32>>) ->
    {ok, [OtherPlayerId]};

%%封神争霸功勋属性加成升级
read(13062,<<Type:16>>)->
	{ok,[Type]};
%%
read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%玩家信息
write(13001, [Scene, X, Y, Id, Hp, Hp_lim, Mp, Mp_lim, Sex, Lv, Exp, Exp_lim, 
			  Career, Nickname, MaxAtt, MinAtt, Def, Forza, Physique, Agile, Wit, Hit, Dodge, 
              Crit, GuildId, GuildName, GuildPosition, Realm, Gold, Cash, Coin, Bcoin,
			  Att_area, Spirit, Speed, AttSpeed, EquipCurrent, Mount,
              Pk_mode, Title, Couple_name, Position, Evil, RealmHonor, Culture, State,
              Anti_wind, Anti_fire, Anti_water, Anti_thunder,Anti_soil, Status, 
			  Stren,SuitID,ChangeReason, Arena,Vip,VipTime,MountStren,CharmTitle,IsSpring,
			  AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti, Batt_value,Turned,_Accept,DeputyProfLv,WarHonor,FullStren,FbyfStren,SpyfStren,_Pet_batt_skill
            ]) ->
	[E1, E2, E3, E4, E5] = EquipCurrent,
    Nick1 = tool:to_binary(Nickname),
    Nick_len = byte_size(Nick1),
    GuildName1 = tool:to_binary(GuildName),
    GuildName_len = byte_size(GuildName1),	
    Title1 = tool:to_binary(Title),
    Title_len = byte_size(Title1),	
    Couple_name1 = tool:to_binary(Couple_name),
    Couple_name_len = byte_size(Couple_name1),
    Position1 = tool:to_binary(Position),
    Position_len = byte_size(Position1),
	Spirit_bin = tool:to_binary(Spirit),
	Spirit_len = byte_size(Spirit_bin),
	{TitlesLen, TitlesBin} = lib_title:pack_titles_data(CharmTitle),
	{GPostStrLen, GPostStrBin} = lib_player:get_guild_post_title(GuildPosition),
	[HonorUse,HonorRift,HonorCul,HonorSpt,HonorPet] = WarHonor,
	%%封装战斗力值
	case Batt_value of
		[] ->
			Batt_Data = <<0:16,<<>>/binary>>;
		_ ->
			BattLen = length(Batt_value),
			F = fun(D) ->
						if D == [] ->
							   <<0:8,0:32>>;
						   true ->
							   [Type,Value] = D,
							   <<Type:8,Value:32>>
						end
				end,
			Batt_Data1 = tool:to_binary([F(D) || D <- Batt_value]),
			Batt_Data = <<BattLen:16, Batt_Data1/binary>>
	end,
    Data = <<
            Scene:32,
            X:16,
            Y:16,
            Id:32,
            Hp:32,
            Hp_lim:32,
            Mp:32,
            Mp_lim:32,
            Sex:16,
            Lv:16,
            Exp:32,
            Exp_lim:32,
            Career:8,
            Nick_len:16,
            Nick1/binary,
			MaxAtt:16,
			MinAtt:16,
            Def:16,
            Forza:16,
            Physique:16,			
            Agile:16,
            Wit:16,
            Hit:16,
            Dodge:16,
            Crit:16,
            GuildId:32,
            GuildName_len:16,
            GuildName1/binary,
            GuildPosition:8,
            Realm:8,
            Gold:32,
            Cash:32,
            Coin:32,
			Bcoin:32,
            Att_area:8,
			Spirit_len:16,
            Spirit_bin/binary,
            Speed:16,
            AttSpeed:16,
            E1:32,
            E2:32,
            E3:32,
			E4:32,
			E5:32,
			Mount:32,			
            Pk_mode:8,
			Title_len:16,
            Title1/binary,
			Couple_name_len:16,
            Couple_name1/binary,
			Position_len:16,
            Position/binary,
            Evil:32,
            RealmHonor:32,
            Culture:32,
            State:8,
            Anti_wind:32,
            Anti_fire:32,
            Anti_water:32,
            Anti_thunder:32,
			Anti_soil:32,
            Status:32,
			Stren:8,
			SuitID:8,
			ChangeReason:16,
			Arena:32,
			Vip:8,
			VipTime:32,
			MountStren:8,
			TitlesLen:16,
			TitlesBin/binary,
			AchHp:8, AchMp:8, AchAtt:8, AchDef:8, 
			AchDod:8, AchHit:8, AchCrit:8, AchAnti:8,
			IsSpring:8,
			GPostStrLen:16,
			GPostStrBin/binary,
			Batt_Data/binary,
			Turned:32,
			DeputyProfLv:8,
			HonorUse:32,
			HonorRift:32,
			HonorCul:32,
			HonorSpt:32,
			HonorPet:32,
			FullStren:8,
			FbyfStren:8,
			SpyfStren:8
			>>,
    {ok, pt:pack(13001, Data)};

%%加经验
write(13002, [Exp, Spirit]) ->
    {ok, pt:pack(13002, <<Exp:32, Spirit:32>>)};

%%升级
write(13003, [Hp, Mp, Lv, Exp, Exp_lim, Spirit, Exp_ori]) ->
    {ok, pt:pack(13003, <<Hp:32, Mp:32, Lv:16, Exp:32, Exp_lim:32, Spirit:32, Exp_ori:32>>)};

%%查询进入场景所需信息
write(13004, [Id, Hp, Hp_lim, Mp, Mp_lim, Sex, Lv, Career, Nickname,
            MaxAtt, MinAtt, Def, Forza, Physique, Agile, Wit, Hit, Dodge, Crit,  
			GuildId, GuildName, GuildPosition, Realm, Spirit, Speed, EquipCurrent,Mount,
            Pk_mode, Title, Couple_name, Position, Evil, Honor, Culture, State,
            Anti_wind, Anti_fire, Anti_water, Anti_thunder,Anti_soil,Vip, CharmTitle, AchPearl			  
            ,Batt_value,Close,DeputyProfLv,WarHonor]) ->
    Nick1 = tool:to_binary(Nickname),
    Nick_len = byte_size(Nick1),
    GuildName1 = tool:to_binary(GuildName),
    GuildName_len = byte_size(GuildName1),
    Title1 = tool:to_binary(Title),
    Title_len = byte_size(Title1),	
    Couple_name1 = tool:to_binary(Couple_name),
    Couple_name_len = byte_size(Couple_name1),	
    Position1 = tool:to_binary(Position),
    Position_len = byte_size(Position1),
	Spirit_bin = tool:to_binary(Spirit),
	Spirit_len = byte_size(Spirit_bin),
	{TitlesLen, TitlesBin} = lib_title:pack_titles_data(CharmTitle),
	[_E1, _E2, E3, E4, E5] = EquipCurrent,
	[HonorUse,HonorRift,HonorCul,HonorSpt,HonorPet] = WarHonor,
	[AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti] = 
		data_achieve:get_pearl_equiped_ornot(AchPearl),
	%%封装战斗力值
	case Batt_value of
		[] ->
			Batt_Data = <<0:16,<<>>/binary>>;
		_ ->
			BattLen = length(Batt_value),
			F = fun(D) ->
						if D == [] ->
							   <<0:8,0:32>>;
						   true ->
							   [Type,Value] = D,
							   <<Type:8,Value:32>>
						end
				end,
			Batt_Data1 = tool:to_binary([F(D) || D <- Batt_value]),
			Batt_Data = <<BattLen:16, Batt_Data1/binary>>
	end,
    Data = <<
            Id:32,
            Hp:32,
            Hp_lim:32,
            Mp:32,
            Mp_lim:32,
            Sex:16,
            Lv:16,
            Career:8,
            Nick_len:16,
            Nick1/binary,
			MaxAtt:16,
			MinAtt:16,
            Def:16,
            Forza:16,
            Physique:16,			
            Agile:16,
            Wit:16,
            Hit:16,
            Dodge:16,
            Crit:16,
            GuildId:32,
            GuildName_len:16,
            GuildName1/binary,
            GuildPosition:8,
            Realm:8,
            Spirit_len:16,
			Spirit_bin/binary,
			E5:32,
			Mount:32,
			Speed:16,
            Pk_mode:8,
			Title_len:16,
            Title1/binary,
			Couple_name_len:16,
            Couple_name1/binary,
			Position_len:16,
            Position/binary,
            Evil:32,
            Honor:32,
            Culture:32,
            State:8,
            Anti_wind:32,
            Anti_fire:32,
            Anti_water:32,
            Anti_thunder:32,
			Anti_soil:32,
			Vip:8,
			TitlesLen:16,
			TitlesBin/binary,
			AchHp:8, AchMp:8, AchAtt:8, AchDef:8, 
			AchDod:8, AchHit:8, AchCrit:8, AchAnti:8,
			Batt_Data/binary,
			Close:32,
			DeputyProfLv:8,
			HonorUse:32,
			HonorRift:32,
			HonorCul:32,
			HonorSpt:32,
			HonorPet:32,
			E3:32,
			E4:32
			>>,
    {ok, pt:pack(13004, Data)};

%%通知客户端更新
write(13005, S) ->
    {ok, pt:pack(13005, <<S:8>>)};

%%通知客户端更新灵力
write(13006, Spr) ->
    {ok, pt:pack(13006, <<Spr:32>>)};

%%获取快捷栏
write(13007, []) ->
    {ok, pt:pack(13007, <<0:16, <<>>/binary>>)};
write(13007, Quickbar) ->
    Rlen = length(Quickbar),
    F = fun({L, T, Id}) ->
        <<L:8, T:8, Id:32>>
    end,
    RB = tool:to_binary([F(D) || D <- Quickbar]),
    {ok, pt:pack(13007, <<Rlen:16, RB/binary>>)};

%%保存快捷栏
write(13008, State) ->
    {ok, pt:pack(13008, <<State:8>>)};

%%删除快捷栏
write(13009, State) ->
    {ok, pt:pack(13009, <<State:8>>)};

%%替换快捷栏
write(13010, State) ->
    {ok, pt:pack(13010, <<State:8>>)};

%%查询进入场景所需信息
write(13011, [Hp, Hp_lim, Mp, Mp_lim, Gold, Cash, Coin, Bcoin, ChangeReason]) ->
    Data = <<
            Hp:32,
            Hp_lim:32,
            Mp:32,
            Mp_lim:32,
            Gold:32,
            Cash:32,
            Coin:32,
			Bcoin:32,
			ChangeReason:16
            >>,
    {ok, pt:pack(13011, Data)};

%%修改 Pk模式
write(13012, [State, Mode]) ->
    {ok, pt:pack(13012, <<State:8, Mode:32>>)};

%% 返回BUFF信息
write(13013, [BUFF, Now]) ->
    Len = length(BUFF),
    F = fun({_, _, BuffTime, SkillId, Slv}) ->
        LeftBuffTime = BuffTime - Now,
        <<SkillId:32, Slv:32, LeftBuffTime:32>>
    end,
    LB = tool:to_binary([F(B) || B <- BUFF]),
    {ok, pt:pack(13013, <<Len:16, LB/binary>>)};

%% 返回物品buff效果
write(13014, BUFF) ->
	Len = length(BUFF),
	F = fun([GoodsId,Value,LeftTime]) ->
			<<GoodsId:32 , Value:32 , LeftTime:32>>
		end,
	LB = tool:to_binary(lists:map(F, BUFF)),
	Data = <<Len:16 ,LB/binary>>,
	{ok,pt:pack(13014,Data)};

%% 角色打坐效果
write(13015,[PlayerId,State]) ->
   {ok, pt:pack(13015, <<PlayerId:32,State:8>>)};

%% 角色打坐气血，法力恢复效果
write(13016, [PlayerId,HP,MP]) ->
    {ok, pt:pack(13016, <<PlayerId:32, HP:32, MP:32>>)};

%% 通知客户端金钱改变 
write(13017, [_PlayerId, Field, Optype, Value, Source]) ->
    {ok, pt:pack(13017, <<Field:8, Optype:8, Value:32, Source:8>>)};

%% 更改角色某一属性 
write(13018, AttrList) ->
	Len = length(AttrList),
	F = fun({AttrType, AttrVal}) ->
		<<AttrType:32, AttrVal:32>>
	end,
	LB = tool:to_binary(lists:map(F, AttrList)),
    {ok, pt:pack(13018, <<Len:16 ,LB/binary>>)};

%% 查询离线时间经验灵力累积
write(13020,[Seconds, Exp, Coin, Sprite])->
	{ok,pt:pack(13020, <<Seconds:32, Exp:32, Coin:32, Sprite:32>>)};

%%兑换离线时间经验灵力累积
write(13021,[Result,Seconds,Exp,Sprite])->
	{ok,pt:pack(13021,<<Result:8,Seconds:32,Exp:32,Sprite:32>>)};

%%查询连续登陆物品奖励信息
write(13022,[Day,G4,Num4,Mark4,G8,Num8,Mark8,G12,Num12,Mark12,GoodsId1,G1_N,G1_M,CDay,GoodsId2,G2_N,G2_M])->
	{ok,pt:pack(13022,<<Day:8,G4:32,Num4:8,Mark4:8,G8:32,Num8:8,Mark8:8,G12:32,Num12:8,Mark12:8,GoodsId1:32,G1_N:8,G1_M:8,CDay:8,GoodsId2:32,G2_N:8,G2_M:8>>)};

%%领取连续登陆物品奖励
write(13023,Res)->
	{ok,pt:pack(13023,<<Res:8>>)};

%%查询在线时长礼券奖励信息
write(13024,[Hour,Cash,Week,CashWeek,WeekMark,WeekEnd,Mon,CashMon,MonMark,MonEnd])->
	{ok,pt:pack(13024,<<Hour:32,Cash:8,Week:32,CashWeek:16,WeekMark:8,WeekEnd:32,Mon:32,CashMon:16,MonMark:8,MonEnd:32>>)};

%%领取在线时长礼券奖励
write(13025,Res)->
	{ok,pt:pack(13025,<<Res:8>>)};

%%查询魅力值
write(13026,Charm)->
	{ok,pt:pack(13026,<<Charm:32>>)};

%% 获取积分面板积分
write(13027, [Arena, Guild, Fst, Td, Charm, RealmHonor,ZxtHonor])->
	{ok, pt:pack(13027, <<Arena:32, Guild:32, Fst:32, Td:32, Charm:32, RealmHonor:32,ZxtHonor:32>>)};

%% 角色改名
write(13028, Res)->
	{ok, pt:pack(13028, <<Res:8>>)};

%排行榜玩家属性
write(13029, [Id, Nickname, Realm, Sex, Lv, Career, Vip, Mount,MountTypeId]) ->
	Nick1 = tool:to_binary(Nickname),
    Nick_len = byte_size(Nick1),
    {ok, pt:pack(13029, <<Id:32, Nick_len:16,Nick1/binary, Realm:8, Sex:8, Lv:16, Career:8 ,Vip:8, Mount:32, MountTypeId:32>>)};

%%变性
write(13030, Res)->
	{ok, pt:pack(13030, <<Res:8>>)};

%%vip免费传送次数
write(13031,Times)->
	{ok, pt:pack(13031, <<Times:16>>)};

%%vip过期提醒
write(13032,Code) ->
	{ok,pt:pack(13032, <<Code:8>>)};

%%查询双修角色列表
write(13040, []) ->
    {ok, pt:pack(13040, <<0:16, <<>>/binary>>)};
write(13040, Result) ->
    Rlen = length(Result),
    F = fun([Player_Id,Nickname,Lv,Career]) ->
				Nick1 = tool:to_binary(Nickname),
				Nick_len = byte_size(Nick1),
				<<Player_Id:32,Nick_len:16,Nick1/binary,Lv:16,Career:8>>
    end,
    RB = tool:to_binary([F(D) || D <- Result]),
    {ok, pt:pack(13040, <<Rlen:16, RB/binary>>)};

%%查询双修角色列表
write(13041, Result) ->
	case Result of
		[] ->
			{ok, pt:pack(13041, <<0:16, <<>>/binary>>)};
		_ ->
			F = fun([Player_Id,Nickname,Lv,Career]) ->
						Nick1 = tool:to_binary(Nickname),
						Nick_len = byte_size(Nick1),
						<<Player_Id:32,Nick_len:16,Nick1/binary,Lv:16,Career:8>>
				end,
			RB = tool:to_binary([F(D) || D <- [Result]]),
			{ok, pt:pack(13041, <<1:16, RB/binary>>)}
	end;   

%% 邀请双修
write(13042,[Code,Other_Id,OtherSceneId,X,Y,InitX,InitY,PlayerId,PlayerSceneId,X1,Y]) ->
    {ok, pt:pack(13042, <<Code:8,Other_Id:32,OtherSceneId:32,X:16,Y:16,InitX:16,InitY:16,PlayerId:32,PlayerSceneId:32,X1:16,Y:16>>)};

%% 邀请双修
write(13043,Code) ->
   {ok, pt:pack(13043, <<Code:8>>)};

%% 发出邀请成功后对方弹出邀请窗口
write(13044,[OtherPlayerId,Nickname]) ->
	Nick1 = tool:to_binary(Nickname),
	Nick_len = byte_size(Nick1),
   {ok, pt:pack(13044, <<OtherPlayerId:32,Nick_len:16,Nick1/binary>>)};

%% 发出邀请成功后对方弹出邀请窗口
write(13045,[Code,Player_Id,SceneId,X,Y,InitX,InitY,OtherId,OtherSceneId,OtherX,OtherY]) ->
   {ok, pt:pack(13045, <<Code:8,Player_Id:32,SceneId:32,X:16,Y:16,InitX:16,InitY:16,OtherId:32,OtherSceneId:32,OtherX:16,OtherY:16>>)};

%% 发出邀请成功后对方弹出邀请窗口
write(13046,Code) ->
   {ok, pt:pack(13046, <<Code:8>>)};

%% 通知角色改变状态
write(13047,[OtherPlayerId,Code,X,Y]) ->
   {ok, pt:pack(13047, <<OtherPlayerId:32,Code:8,X:16,Y:16>>)};

%%加修为
write(13052, [Culture]) ->
    {ok, pt:pack(13052, <<Culture:32>>)};

%%邀请方已经到指定位置
write(13053, Code) ->
    {ok, pt:pack(13053, <<Code:8>>)};

%%商城积分
write(13054, ShopScore) ->
    {ok, pt:pack(13054, <<ShopScore:32>>)};

%% 双倍经验活动
write(13061, [St, Et, Dt]) ->
    {ok, pt:pack(13061, <<St:32, Et:32, Dt:32>>)};

%%封神争霸功勋属性升级
write(13062,[Res])->
	 {ok, pt:pack(13062, <<Res:16>>)};
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.
