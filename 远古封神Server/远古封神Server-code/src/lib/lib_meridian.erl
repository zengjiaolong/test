%%%-----------------------------------
%%% @Module  : lib_meridian
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 经脉
%%%-----------------------------------
-module(lib_meridian).
-include("record.hrl").
-include("common.hrl").
-compile(export_all).

%查看经脉信息
check_meridian_info(PlayerStatus,PlayerId)->
	Player_id = PlayerStatus#player.id, 
	NowTime= util:unixtime(),
	[MeridianInfo] = case Player_id =:= PlayerId of
				   true-> 
					   case get_player_meridian_info(PlayerId) of
						   []->[[]];
						   Info->Info
					   end;
				   false->
						get_other_player_meridian(PlayerId)
					 end,
	{ok,[Mer_up,Mer_time]} = check_uplvl_meridian(PlayerId,MeridianInfo),
	%判读是否修炼完毕
	if 
		Mer_up =/=0 andalso Mer_time =< NowTime andalso PlayerId =:=Player_id	-> 
			NewMeridianInfo = meridian_uplvl_change(PlayerId,MeridianInfo,Mer_up,1),
			PS = mod_meridian:meridian_uplvl_finish(PlayerStatus,NewMeridianInfo,false),
			NewMup = 0,
			NewMtime = 0;
		Mer_up =/=0 andalso Mer_time > NowTime andalso PlayerId =:=Player_id	->
			NewMeridianInfo = MeridianInfo,
			NewMup = Mer_up,
			NewMtime = Mer_time-NowTime,
			PS = PlayerStatus;
		true	->
			NewMeridianInfo = MeridianInfo,
			NewMup = 0,
			NewMtime = 0,
			PS = PlayerStatus
	end,
	{ok,Data_Lvl,Data_LingGen,TopValue} = check_meridian_info_all(PS,PlayerId,NewMeridianInfo),
	MeridianID = [1,2,3,4,5,6,7,8],
	[Lvl1,Lvl2,Lvl3,Lvl4,Lvl5,Lvl6,Lvl7,Lvl8] = Data_Lvl,
	[LG1,LG2,LG3,LG4,LG5,LG6,LG7,LG8] = Data_LingGen,
	[YangTop,YinTop,WeiTop,RenTop,DuTop,ChongTop,QiTop,DaiTop] = TopValue,
	UpLvl_Time = [match_meridian(X,NewMup,NewMtime)||X <-MeridianID ],
	[T1,T2,T3,T4,T5,T6,T7,T8] = UpLvl_Time,
	Effect1= get_meridian_effect(1,Lvl1,LG1),
	Effect2= get_meridian_effect(2,Lvl2,LG2),
	Effect3= get_meridian_effect(3,Lvl3,LG3),
	Effect4= get_meridian_effect(4,Lvl4,LG4),
	Effect5= get_meridian_effect(5,Lvl5,LG5),
	Effect6= get_meridian_effect(6,Lvl6,LG6),
	Effect7= get_meridian_effect(7,Lvl7,LG7),
	Effect8= get_meridian_effect(8,Lvl8,LG8),
	Next_Effect1= get_meridian_effect(1,Lvl1+1,LG1),
	Next_Effect2= get_meridian_effect(2,Lvl2+1,LG2),
	Next_Effect3= get_meridian_effect(3,Lvl3+1,LG3),
	Next_Effect4= get_meridian_effect(4,Lvl4+1,LG4),
	Next_Effect5= get_meridian_effect(5,Lvl5+1,LG5),
	Next_Effect6= get_meridian_effect(6,Lvl6+1,LG6),
	Next_Effect7= get_meridian_effect(7,Lvl7+1,LG7),
	Next_Effect8= get_meridian_effect(8,Lvl8+1,LG8),
	Mer_Info =[PlayerId,1,Lvl1,LG1,YangTop,Effect1,Next_Effect1,T1,
				PlayerId,2,Lvl2,LG2,YinTop,Effect2,Next_Effect2,T2,
				PlayerId,3,Lvl3,LG3,WeiTop,Effect3,Next_Effect3,T3,
				PlayerId,4,Lvl4,LG4,RenTop,Effect4,Next_Effect4,T4,
				PlayerId,5,Lvl5,LG5,DuTop,Effect5,Next_Effect5,T5,
				PlayerId,6,Lvl6,LG6,ChongTop,Effect6,Next_Effect6,T6,
				PlayerId,7,Lvl7,LG7,QiTop,Effect7,Next_Effect7,T7,
				PlayerId,8,Lvl8,LG8,DaiTop,Effect8,Next_Effect8,T8],
	{ok,PS,Mer_Info}.



%查找该经脉是否有修炼
check_can_uplvl(PlayerStatus,PlayerId,MeridianId) ->
	Player_Id = PlayerStatus#player.id,
	[MeridianInfo] = case Player_Id =:= PlayerId of
				   true-> 
					   case get_player_meridian_info(PlayerId) of
						   []->[[]];
						   Info->Info
					   end;
				   false->
						get_other_player_meridian(PlayerId)
					 end,
	if Player_Id =:= PlayerId ->
		{ok,[Mer_up,Mer_time]} = check_uplvl_meridian(PlayerId,MeridianInfo),
		TimeNow = util:unixtime(),
		if
			Mer_up =/= 0 andalso Mer_time =< TimeNow andalso MeridianId =:= Mer_up ->
				NewMeridianInfo = meridian_uplvl_change(PlayerId,MeridianInfo,Mer_up,1),
				PS = mod_meridian:meridian_uplvl_finish(PlayerStatus,NewMeridianInfo,false),
				Value = 0;
			Mer_up =/= 0 andalso Mer_time > TimeNow andalso MeridianId =:= Mer_up->
				NewMeridianInfo = MeridianInfo,
				Value = Mer_time-TimeNow,
				PS = PlayerStatus;
			true ->
				NewMeridianInfo = MeridianInfo,
				Value = 0,
				PS =PlayerStatus
		end,
	   {PS,Value,NewMeridianInfo};
	   true ->
		   {PlayerStatus,0,MeridianInfo}
	end.

check_can_uplvl1(PlayerStatus,MeridianInfo,Type)->
	PlayerId = PlayerStatus#player.id,
	{ok,[Mer_up,Mer_time]} = check_uplvl_meridian(PlayerId,MeridianInfo),
	TimeNow = util:unixtime(),
	if
		Mer_up =/= 0 andalso Mer_time =< TimeNow  ->
			[PS,NewMeridianInfo] = case Type of
				2->
					NewMeridianInfo1 = meridian_uplvl_change(PlayerId,MeridianInfo,Mer_up,1),
					[mod_meridian:meridian_uplvl_finish(PlayerStatus,NewMeridianInfo1,false),NewMeridianInfo1];
				_->[PlayerStatus,MeridianInfo]
			end,
			Value = 0;
		Mer_up =/= 0 andalso Mer_time > TimeNow ->
			NewMeridianInfo = MeridianInfo,
			Value = Mer_time-TimeNow,
			PS = PlayerStatus;
		true ->
			NewMeridianInfo = MeridianInfo, 
			Value = 0,
			PS=PlayerStatus
	end,
	{PS,Value,NewMeridianInfo}.

%%获取当前经脉属性加成
get_meridian_att_current(PlayerId,MeridianInfo)->
	{ok,Data_Lvl,Data_LingGen,_} = check_meridian_info_all(null,PlayerId,MeridianInfo),
	%%[阳，阴，维，任，督，冲，带，奇]
	[Lvl1,Lvl2,Lvl3,Lvl4,Lvl5,Lvl6,Lvl7,Lvl8] = Data_Lvl,
	[LG1,LG2,LG3,LG4,LG5,LG6,LG7,LG8] = Data_LingGen,
	%%气血
	Hp= get_meridian_effect(1,Lvl1,LG1),
	%%防御
	Def= get_meridian_effect(2,Lvl2,LG2),
	%%法力
	Mp= get_meridian_effect(3,Lvl3,LG3),
	%%命中
	Hit= get_meridian_effect(4,Lvl4,LG4),
	%%暴击
	Cirt= get_meridian_effect(5,Lvl5,LG5),
	%%闪躲
	Dodge= get_meridian_effect(6,Lvl6,LG6),
	%%攻击
	Att= get_meridian_effect(7,Lvl7,LG7),
	%%全抗
	Ten= get_meridian_effect(8,Lvl8,LG8),
	%%灵根加成[力量，敏捷，智力，体质]
	[LgHp,LgMp,LgAtt] = get_lg_atb_add(Data_LingGen),
	[LvHp,LvMp,LvAtt] = get_lv_atb_add(Data_Lvl),
	{ok,[Hp,Def,Mp,Hit,Cirt,Dodge,Att,Ten,LgHp+LvHp,LgMp+LvMp,LgAtt+LvAtt]}.

%%获取经脉等级属性加成
%% [气血，法力，攻击]
get_lv_atb_add(LvBag)->
	case LvBag of
		[]->[0,0,0];
		_->
			Lv = lists:min(LvBag),
			if Lv == 0 -> [0,0,0];
			   Lv =< 4 -> [150,10,15];
			   Lv =< 7 -> [300,20,30];
			   Lv =< 9 -> [500,60,50];
			   Lv =< 11 -> [750,80,75];
			   Lv =< 14 -> [1050,110,105];
			   true->
				   [1400,140,150]
			end
	end.

%%获取经脉灵根属性加成
%% [气血，法力，攻击]
get_lg_atb_add(LgBag)->
	case LgBag of
		[]->[0,0,0];
		_->
			MinLg = lists:min(LgBag),
			if MinLg =< 20 -> [0,0,0];
			   MinLg =< 40 -> [300,30,30];
			   MinLg =< 60 -> [600,80,80];
			   MinLg =< 80 -> [1200,150,150];
			   MinLg =< 90 -> [2000,300,300];
			   MinLg =< 100 -> [3000,500,500];
			   true -> [0,0,0]
			end
	end.


%查找关联经脉等级
check_relation_meridian_lvl(MeridianInfo,_PlayerId,MeridianType)->
	if
		MeridianType =:= mer_ren	->
			[MeridianInfo#ets_meridian.mer_ren,MeridianInfo#ets_meridian.mer_yang,MeridianInfo#ets_meridian.mer_yin,MeridianInfo#ets_meridian.ren_top];
		MeridianType =:= mer_du	->
			[MeridianInfo#ets_meridian.mer_du,MeridianInfo#ets_meridian.mer_wei,MeridianInfo#ets_meridian.mer_ren,MeridianInfo#ets_meridian.du_top];
		MeridianType =:= mer_chong	->
			[MeridianInfo#ets_meridian.mer_chong,MeridianInfo#ets_meridian.mer_wei,MeridianInfo#ets_meridian.mer_ren,MeridianInfo#ets_meridian.chong_top];
		MeridianType =:= mer_dai	->
			[MeridianInfo#ets_meridian.mer_dai,MeridianInfo#ets_meridian.mer_du,MeridianInfo#ets_meridian.mer_chong,MeridianInfo#ets_meridian.dai_top];
		MeridianType =:= mer_wei	->
			[MeridianInfo#ets_meridian.mer_wei,MeridianInfo#ets_meridian.mer_yang,MeridianInfo#ets_meridian.mer_yin,MeridianInfo#ets_meridian.wei_top];
		MeridianType =:= mer_qi	->
			[MeridianInfo#ets_meridian.mer_qi,MeridianInfo#ets_meridian.mer_du,MeridianInfo#ets_meridian.mer_chong,MeridianInfo#ets_meridian.qi_top];
		MeridianType =:= mer_yin	->
			[MeridianInfo#ets_meridian.mer_yin,MeridianInfo#ets_meridian.mer_qi,MeridianInfo#ets_meridian.mer_dai,MeridianInfo#ets_meridian.yin_top];
		MeridianType =:= mer_yang	->
			[MeridianInfo#ets_meridian.mer_yang,MeridianInfo#ets_meridian.mer_qi,MeridianInfo#ets_meridian.mer_dai,MeridianInfo#ets_meridian.yang_top];
		true ->
			[]
	end.

%查找前置经脉等级
check_relation_meridian_prea(MeridianInfo,_PlayerId,MeridianType)->
	if
		MeridianType =:= mer_ren	->
			[MeridianInfo#ets_meridian.mer_ren,MeridianInfo#ets_meridian.mer_wei];
		MeridianType =:= mer_du	->
			[MeridianInfo#ets_meridian.mer_du,MeridianInfo#ets_meridian.mer_ren];
		MeridianType =:= mer_chong	->
			[MeridianInfo#ets_meridian.mer_chong,MeridianInfo#ets_meridian.mer_du];
		MeridianType =:= mer_dai	->
			[MeridianInfo#ets_meridian.mer_dai,MeridianInfo#ets_meridian.mer_qi];
		MeridianType =:= mer_wei	->
			[MeridianInfo#ets_meridian.mer_wei,MeridianInfo#ets_meridian.mer_yin];
		MeridianType =:= mer_qi	->
			[MeridianInfo#ets_meridian.mer_qi,MeridianInfo#ets_meridian.mer_chong];
		MeridianType =:= mer_yin	->
			[MeridianInfo#ets_meridian.mer_yin,MeridianInfo#ets_meridian.mer_yang];
		MeridianType =:= mer_yang	->
			[MeridianInfo#ets_meridian.mer_yang,1];
		true ->
			[0,0,0]
	end.

%开始修炼
start_uplvl_meridian(PlayerId,MeridianInfo,MerId,Timestamp)->
	spawn(fun()->catch(db_agent:meridian_uplvl_start(PlayerId,MerId,Timestamp))end),
	%更新缓存
	MeridianInfoNew = MeridianInfo#ets_meridian{meridian_uplevel_typeId = MerId,meridian_uplevel_time=Timestamp },
	ets:insert(?ETS_MERIDIAN,MeridianInfoNew),
	MerType = id_to_type(MerId),
	{ok,[MerLv,_Lg,_Value]} = check_meridian_lvl_and_linggen(PlayerId,MeridianInfo,MerType),
	spawn(fun()->catch(db_agent:meridian_log(PlayerId,MerId,MerLv+1,util:unixtime()))end).

%%经脉加速
speed_uplvl_meridian(MeridianInfo,PlayerId,Timestamp)->
	spawn(fun()->catch(db_agent:meridian_uplvl_speed(PlayerId,Timestamp))end),
	%更新缓存
	MeridianInfoNew = MeridianInfo#ets_meridian{meridian_uplevel_time=Timestamp },
	ets:insert(?ETS_MERIDIAN,MeridianInfoNew).

%%检查是否可升级
uplvl_check(PlayerId,MerType,MeridianInfo)->
	case check_uplvl_meridian(PlayerId,MeridianInfo) of
		{ok,[0,0]}->false;
		{ok,_}-> 
			case mod_meridian:check_condition(MeridianInfo,PlayerId,MerType)  of
				{ok,_}->
					true;
				_->
					false
			end
	end.

%经脉修炼完成，升级
meridian_uplvl_change(PlayerId,MeridianInfo,MerId,LvlUp)->
	%%merId,11081
	MerType = id_to_type(MerId),
	case uplvl_check(PlayerId,MerType,MeridianInfo) orelse LvlUp=:= 1 of
		true->
			%更新缓存
			if 
				MerId =:=1->
					Lvl=MeridianInfo#ets_meridian.mer_yang,
					LG = MeridianInfo#ets_meridian.mer_yang_linggen,
		 			MeridianInfoNew = MeridianInfo#ets_meridian{mer_yang=Lvl+LvlUp,
									meridian_uplevel_typeId = 0,meridian_uplevel_time=0 },
					spawn(fun()->catch(db_agent:meridian_uplvl_finish(PlayerId,MerType,LvlUp))end);
			 	MerId =:=2->
					Lvl = MeridianInfo#ets_meridian.mer_yin,
					LG = MeridianInfo#ets_meridian.mer_yin_linggen,
		 			MeridianInfoNew = MeridianInfo#ets_meridian{mer_yin=Lvl+LvlUp,
									meridian_uplevel_typeId = 0,meridian_uplevel_time=0},
					spawn(fun()->catch(db_agent:meridian_uplvl_finish(PlayerId,MerType,LvlUp))end);
				MerId =:=3->
					Lvl = MeridianInfo#ets_meridian.mer_wei,
					LG = MeridianInfo#ets_meridian.mer_wei_linggen,
					MeridianInfoNew = MeridianInfo#ets_meridian{mer_wei=Lvl+LvlUp,
									meridian_uplevel_typeId = 0,meridian_uplevel_time=0},
					spawn(fun()->catch(db_agent:meridian_uplvl_finish(PlayerId,MerType,LvlUp))end);
				MerId =:=4->
					Lvl = MeridianInfo#ets_meridian.mer_ren,
					LG = MeridianInfo#ets_meridian.mer_ren_linggen,
 					MeridianInfoNew = MeridianInfo#ets_meridian{mer_ren=Lvl+LvlUp,
									meridian_uplevel_typeId = 0,meridian_uplevel_time=0},
					spawn(fun()->catch(db_agent:meridian_uplvl_finish(PlayerId,MerType,LvlUp))end);
				MerId =:=5->
					Lvl = MeridianInfo#ets_meridian.mer_du,
					LG = MeridianInfo#ets_meridian.mer_du_linggen,
		 			MeridianInfoNew = MeridianInfo#ets_meridian{mer_du=Lvl+LvlUp,
									meridian_uplevel_typeId = 0,meridian_uplevel_time=0},
					spawn(fun()->catch(db_agent:meridian_uplvl_finish(PlayerId,MerType,LvlUp))end);
				MerId =:=6->
					Lvl = MeridianInfo#ets_meridian.mer_chong,
					LG = MeridianInfo#ets_meridian.mer_chong_linggen,
 					MeridianInfoNew = MeridianInfo#ets_meridian{mer_chong=Lvl+LvlUp,
									meridian_uplevel_typeId = 0,meridian_uplevel_time=0},
					spawn(fun()->catch(db_agent:meridian_uplvl_finish(PlayerId,MerType,LvlUp))end);
				MerId =:=7->
					Lvl = MeridianInfo#ets_meridian.mer_qi,
					LG = MeridianInfo#ets_meridian.mer_qi_linggen,
 					MeridianInfoNew = MeridianInfo#ets_meridian{mer_qi=Lvl+LvlUp,
									meridian_uplevel_typeId = 0,meridian_uplevel_time=0},
					spawn(fun()->catch(db_agent:meridian_uplvl_finish(PlayerId,MerType,LvlUp))end);
				MerId =:=8->
					Lvl = MeridianInfo#ets_meridian.mer_dai,
					LG = MeridianInfo#ets_meridian.mer_dai_linggen,
 					MeridianInfoNew = MeridianInfo#ets_meridian{mer_dai=Lvl+LvlUp,
									meridian_uplevel_typeId = 0,meridian_uplevel_time=0},
					spawn(fun()->catch(db_agent:meridian_uplvl_finish(PlayerId,MerType,LvlUp))end);
				true ->
					Lvl = 0,
					LG=0,
					MeridianInfoNew=MeridianInfo#ets_meridian{meridian_uplevel_typeId = 0,meridian_uplevel_time=0},
					spawn(fun()->catch(db_agent:meridian_uplvl_finish(PlayerId,MerType,0))end)
			end;
		false->
			Lvl=0,LG=0,
			MeridianInfoNew=MeridianInfo#ets_meridian{meridian_uplevel_typeId = 0,meridian_uplevel_time=0},
			spawn(fun()->catch(db_agent:meridian_uplvl_finish(PlayerId,MerType,0))end)
	end,
	ets:insert(?ETS_MERIDIAN,MeridianInfoNew),
	if LvlUp=/= 0->
	 	spawn(fun()->finish_msg(PlayerId,MerId,Lvl+1,LG)end);
	   true->skip
	end,
	MeridianInfoNew.

%%经脉修炼完成属性提示
finish_msg(PlayerId,MerId,Lv,LG)->
	NewValue = get_meridian_effect(MerId,Lv,LG),
%% 	OldValue = get_meridian_effect(MerId,Lv-1,LG),
	Msg=io_lib:format("~s修炼完成，~s增加~p",[get_name_by_id(MerId),get_atp_by_id(MerId),round(NewValue)]),
	{ok, BinData} = pt_25:write(25011, Msg),
	lib_send:send_to_uid(PlayerId, BinData),
	ok.

%查看修炼中的经脉
check_uplvl_meridian(_PlayerId,MeridianInfo) ->
	case MeridianInfo of 
		[]->
			{ok, [0,0]};
		_ ->			
			{ok, [MeridianInfo#ets_meridian.meridian_uplevel_typeId,MeridianInfo#ets_meridian.meridian_uplevel_time]}
    end. 	

%查看经脉信息
check_meridian_info_all(_PlayerStatus,_PlayerId,MeridianInfo)->
	case MeridianInfo of 
		[]->
			{ok, [0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0]};
		_ ->
			{_,_,_,Yang,Yin,Wei,Ren,Du,Chong,Qi,Dai,YangLG,YinLG,WeiLG,RenLG,DuLG,ChongLG,QiLG,DaiLG,_,_,YangTop,YinTop,WeiTop,RenTop,DuTop,ChongTop,QiTop,DaiTop} = MeridianInfo,
			{ok, [Yang,Yin,Wei,Ren,Du,Chong,Qi,Dai],[YangLG,YinLG,WeiLG,RenLG,DuLG,ChongLG,QiLG,DaiLG],[YangTop,YinTop,WeiTop,RenTop,DuTop,ChongTop,QiTop,DaiTop]}
	end.

%灵根洗练
update_meridian_linggen(PlayerId,MeridianInfo,MerLGType,Value)->
	spawn(fun()->catch(db_agent:update_meridian_linggen(PlayerId,MerLGType,Value))end),
	%更新缓存
	if 
		MerLGType =:=mer_yang_linggen->
			YangLG = MeridianInfo#ets_meridian.mer_yang_linggen,
 			MeridianInfoNew = MeridianInfo#ets_meridian{mer_yang_linggen=YangLG+Value};
	 	MerLGType =:=mer_yin_linggen->
			YinLG = MeridianInfo#ets_meridian.mer_yin_linggen,
 			MeridianInfoNew = MeridianInfo#ets_meridian{mer_yin_linggen=YinLG+Value};
		MerLGType =:=mer_wei_linggen->
			WeiLG = MeridianInfo#ets_meridian.mer_wei_linggen,
 			MeridianInfoNew = MeridianInfo#ets_meridian{mer_wei_linggen=WeiLG+Value};
		MerLGType =:=mer_ren_linggen->
			RenLG = MeridianInfo#ets_meridian.mer_ren_linggen,
 			MeridianInfoNew = MeridianInfo#ets_meridian{mer_ren_linggen=RenLG+Value};
		MerLGType =:=mer_du_linggen->
			DuLG = MeridianInfo#ets_meridian.mer_du_linggen,
 			MeridianInfoNew = MeridianInfo#ets_meridian{mer_du_linggen=DuLG+Value};
		MerLGType =:=mer_chong_linggen->
			ChongLG = MeridianInfo#ets_meridian.mer_chong_linggen,
 			MeridianInfoNew = MeridianInfo#ets_meridian{mer_chong_linggen=ChongLG+Value};
		MerLGType =:=mer_qi_linggen->
			QiLG = MeridianInfo#ets_meridian.mer_qi_linggen,
 			MeridianInfoNew = MeridianInfo#ets_meridian{mer_qi_linggen=QiLG+Value};
		MerLGType =:=mer_dai_linggen->
			DaiLG = MeridianInfo#ets_meridian.mer_dai_linggen,
 			MeridianInfoNew = MeridianInfo#ets_meridian{mer_dai_linggen=DaiLG+Value};
		true ->
			MeridianInfoNew=MeridianInfo
	end,
	ets:insert(?ETS_MERIDIAN,MeridianInfoNew),
	MeridianInfoNew.

%经脉突破
update_meridian_break_through(PlayerId,MeridianInfo,TopType,Value)->
	spawn(fun()->catch(db_agent:update_break_through(PlayerId,TopType,Value))end),
	%更新缓存
	if 
		TopType =:=yang_top->
			YangLG = MeridianInfo#ets_meridian.yang_top,
 			MeridianInfoNew = MeridianInfo#ets_meridian{yang_top=YangLG+Value};
	 	TopType =:=yin_top->
			YinLG = MeridianInfo#ets_meridian.yin_top,
 			MeridianInfoNew = MeridianInfo#ets_meridian{yin_top=YinLG+Value};
		TopType =:=wei_top->
			WeiLG = MeridianInfo#ets_meridian.wei_top,
 			MeridianInfoNew = MeridianInfo#ets_meridian{wei_top=WeiLG+Value};
		TopType =:=ren_top->
			RenLG = MeridianInfo#ets_meridian.ren_top,
 			MeridianInfoNew = MeridianInfo#ets_meridian{ren_top=RenLG+Value};
		TopType =:=du_top->
			DuLG = MeridianInfo#ets_meridian.du_top,
 			MeridianInfoNew = MeridianInfo#ets_meridian{du_top=DuLG+Value};
		TopType =:=chong_top->
			ChongLG = MeridianInfo#ets_meridian.chong_top,
 			MeridianInfoNew = MeridianInfo#ets_meridian{chong_top=ChongLG+Value};
		TopType =:=qi_top->
			QiLG = MeridianInfo#ets_meridian.qi_top,
 			MeridianInfoNew = MeridianInfo#ets_meridian{qi_top=QiLG+Value};
		TopType =:=dai_top->
			DaiLG = MeridianInfo#ets_meridian.dai_top,
 			MeridianInfoNew = MeridianInfo#ets_meridian{dai_top=DaiLG+Value};
		true ->
			MeridianInfoNew=MeridianInfo
	end,
	ets:insert(?ETS_MERIDIAN,MeridianInfoNew),
	MeridianInfoNew.

%查找经脉等级和灵根
check_meridian_lvl_and_linggen(_PlayerId,Result,MerType)->
	case Result of 
		[]->{ok,[0,0]};
		_->
			MerId = type_to_id(MerType),
			if
				MerId =:=1->
					{ok,[Result#ets_meridian.mer_yang,Result#ets_meridian.mer_yang_linggen,Result#ets_meridian.yang_top]};
				MerId =:=2->
					{ok,[Result#ets_meridian.mer_yin,Result#ets_meridian.mer_yin_linggen,Result#ets_meridian.yin_top]};
				MerId =:=3->
					{ok,[Result#ets_meridian.mer_wei,Result#ets_meridian.mer_wei_linggen,Result#ets_meridian.wei_top]};
				MerId =:=4->
					{ok,[Result#ets_meridian.mer_ren,Result#ets_meridian.mer_ren_linggen,Result#ets_meridian.ren_top]};
				MerId =:=5->
					{ok,[Result#ets_meridian.mer_du,Result#ets_meridian.mer_du_linggen,Result#ets_meridian.du_top]};
				MerId =:=6->
					{ok,[Result#ets_meridian.mer_chong,Result#ets_meridian.mer_chong_linggen,Result#ets_meridian.chong_top]};
				MerId =:=7->
					{ok,[Result#ets_meridian.mer_qi,Result#ets_meridian.mer_qi_linggen,Result#ets_meridian.qi_top]};
				MerId =:=8->
					{ok,[Result#ets_meridian.mer_dai,Result#ets_meridian.mer_dai_linggen,Result#ets_meridian.dai_top]};
				true->
					{ok,[0,0]}
			end
	end.

check_meridian_lvl_and_linggen(PlayerId,MerType)->
	MerId = type_to_id(MerType),
	case get_player_meridian_info(PlayerId) of 
		[]->
			{ok, [0,0,0]};
		[Result] ->
			if
				MerId =:=1->
					{ok,[Result#ets_meridian.mer_yang,Result#ets_meridian.mer_yang_linggen,Result#ets_meridian.yang_top]};
				MerId =:=2->
					{ok,[Result#ets_meridian.mer_yin,Result#ets_meridian.mer_yin_linggen,Result#ets_meridian.yin_top]};
				MerId =:=3->
					{ok,[Result#ets_meridian.mer_wei,Result#ets_meridian.mer_wei_linggen,Result#ets_meridian.wei_top]};
				MerId =:=4->
					{ok,[Result#ets_meridian.mer_ren,Result#ets_meridian.mer_ren_linggen,Result#ets_meridian.ren_top]};
				MerId =:=5->
					{ok,[Result#ets_meridian.mer_du,Result#ets_meridian.mer_du_linggen,Result#ets_meridian.du_top]};
				MerId =:=6->
					{ok,[Result#ets_meridian.mer_chong,Result#ets_meridian.mer_chong_linggen,Result#ets_meridian.chong_top]};
				MerId =:=7->
					{ok,[Result#ets_meridian.mer_qi,Result#ets_meridian.mer_qi_linggen,Result#ets_meridian.qi_top]};
				MerId =:=8->
					{ok,[Result#ets_meridian.mer_dai,Result#ets_meridian.mer_dai_linggen,Result#ets_meridian.dai_top]};
				true->
					{ok,[0,0]}
    		end
	end.


%获取经脉升级相关限制属性
get_meridian_uplvl_value(MerId,MerLvl)->
	case get_meridian_base_info(MerId,MerLvl) of
		[]->
			 [];
		[Result] ->
			%player_level,timestamp,spirit
			[Result#ets_base_meridian.player_level,Result#ets_base_meridian.timestamp,Result#ets_base_meridian.spirit]
	end.

%%获取经脉属性加成效果
get_meridian_effect(MerId,Lvl,LG)->
	%%X脉实际加成值=X脉原始加成值*（1+X脉灵根值/200）
	if Lvl>17->
		   Lvl1 = 17;
	true->
			Lvl1 = Lvl
	end,
	if Lvl=:= 0 ->
		   0;
	   true->
		Value = get_value_list(MerId,Lvl1),
		round(Value  *( 1 + LG / 200))
	end.

%经脉ID=>经脉类型
id_to_type(MeridianId) ->
    if
        MeridianId =:= 1 -> mer_yang;
        MeridianId =:= 2 -> mer_yin;
        MeridianId =:= 3 -> mer_wei;
        MeridianId =:= 4 -> mer_ren;
        MeridianId =:= 5 -> mer_du;
        MeridianId =:= 6 -> mer_chong;
        MeridianId =:= 7 -> mer_qi;
        MeridianId =:= 8 -> mer_dai;
        true -> mer_yang
    end.

%经脉类型=>经脉ID
type_to_id(MeridianType) ->
    if
        MeridianType =:= mer_dai -> 8;
		MeridianType =:= mer_qi -> 7;
        MeridianType =:= mer_chong -> 6;
        MeridianType =:= mer_du -> 5;
		MeridianType =:= mer_ren -> 4;
        MeridianType =:= mer_wei -> 3;
        MeridianType =:= mer_yin -> 2;
        MeridianType =:= mer_yang -> 1;
        true -> 1
    end.

%经脉类型 ->经脉灵根
mertype_to_linggen(MeridianType)	->
	if
        MeridianType =:= mer_ren -> mer_ren_linggen;
        MeridianType =:= mer_du -> mer_du_linggen;
        MeridianType =:= mer_chong -> mer_chong_linggen;
        MeridianType =:= mer_dai -> mer_dai_linggen;
        MeridianType =:= mer_wei -> mer_wei_linggen;
        MeridianType =:= mer_qi -> mer_qi_linggen;
        MeridianType =:= mer_yin -> mer_yin_linggen;
        MeridianType =:= mer_yang -> mer_yang_linggen;
        true -> mer_yang_linggen
    end.

mertype_to_topvalue(MeridianType)->
	if
        MeridianType =:= mer_ren -> ren_top;
        MeridianType =:= mer_du -> du_top;
        MeridianType =:= mer_chong -> chong_top;
        MeridianType =:= mer_dai -> dai_top;
        MeridianType =:= mer_wei -> wei_top;
        MeridianType =:= mer_qi -> qi_top;
        MeridianType =:= mer_yin -> yin_top;
        MeridianType =:= mer_yang -> yang_top;
        true -> yang_top
    end.

%%突破所需铜板和灵力
break_through_value(Value,_MerId)->
	if Value < 10-> {10000,1000,5000};
	   Value < 20-> {10000,2000,5000};
	   Value < 30-> {10000,3000,5000};
	   Value < 40-> {9500,4000,5000};
	   Value < 50-> {9000,5000,5000};
	   Value < 60-> {8000,6000,5000};
	   Value < 70-> {7000,7000,5000};
	   Value < 80-> {6000,8000,5000};
	   Value < 90-> {5000,9000,5000};
	   true-> {2000,10000,5000}
	end.

%经脉匹配
match_meridian(Mer1,Mer2,Timestamp)	->
	if 
		Mer1=:=Mer2	-> Timestamp;
		true -> 0
	end.


%%初始化基础经脉数据
init_base_meridian() ->
    F = fun(Mer) ->
			MerInfo = list_to_tuple([ets_base_meridian] ++ Mer),
            ets:insert(?ETS_BASE_MERIDIAN, MerInfo)
           end,
	L = db_agent:get_base_meridian(),
	lists:foreach(F, L),
    ok.

%获取经脉升级基础值信息
get_meridian_base_info(MerId,MerLvl)->
	Pattern = #ets_base_meridian{mer_type = MerId,mer_lvl = MerLvl,_='_'},
	case match_all(?ETS_BASE_MERIDIAN,Pattern) of 
		[] ->
			case db_agent:select_meridian_basedata(MerId,MerLvl) of
				[] ->
					[];
				Result ->
					Data = match_basedata_ets_format(Result),
					ets:insert(?ETS_BASE_MERIDIAN,Data),
					match_all(?ETS_BASE_MERIDIAN, Pattern)
			end;
		Info ->
		 	Info
	end.
%匹配经脉基础属性ets格式
match_basedata_ets_format(Data)->
	[Id,Name,MerType,MerLvl,Hp,Def,Mp,Hit,Crit,Shun,Att,Ten,PLvl,Spirit,Timestamp]=Data,
	NewData = #ets_base_meridian{
	  id=Id,                                     %% 编号	
	  name = Name,
      mer_type = MerType,                           %% 经脉种类	
      mer_lvl = MerLvl,                            %% 等级种类	
      hp = Hp,                                 %% 气血值	
      def = Def,                                %% 防御值	
      mp = Mp,                                 %% 内力值	
      hit = Hit,                                %% 命中值	
      crit = Crit,                               %% 暴击值	
      shun = Shun,                               %% 闪避值	
      att = Att,                                %% 攻击值	
      ten = Ten,                                %% 全抗值	
      player_level = PLvl,                       %% 玩家修炼等级	
      spirit = Spirit,                             %% 灵力需求	
      timestamp = Timestamp                         %% 修炼时间需求
	},
	NewData.


%%列表求和
%% sum([H|T]) ->H + sum(T);
%% sum([]) -> 0.
%% %%生成一个连续列表
%% seq(Y,Y) -> [Y];
%% seq(X,Y) -> [X|seq(X+1,Y)].

get_value_list(MerId,Lvl)->
	[Data] = get_meridian_base_info(MerId,Lvl),
	if
		MerId =:= 1 -> Data#ets_base_meridian.hp;
		MerId =:= 2 -> Data#ets_base_meridian.def;
		MerId =:= 3 -> Data#ets_base_meridian.mp;
		MerId =:= 4 -> Data#ets_base_meridian.hit;
		MerId =:= 5 -> Data#ets_base_meridian.crit;
		MerId =:= 6 -> Data#ets_base_meridian.shun;
		MerId =:= 7 -> Data#ets_base_meridian.att;
		MerId =:= 8 -> Data#ets_base_meridian.ten;
		true -> 0
    end.
	
%获取玩家经脉属性信息
get_player_meridian_info(PlayerId)->
	Pattern = #ets_meridian{player_id=PlayerId,_='_'},
	case match_all(?ETS_MERIDIAN, Pattern) of
		[]->
			case db_agent:select_meridian_by_playerid(PlayerId) of 
				[]->
					db_agent:new_meridian(PlayerId),
					Data = [0,PlayerId,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
					MeridianInfo = match_playemeridian_ets_format(Data),
					ets:insert(?ETS_MERIDIAN,MeridianInfo),
					match_all(?ETS_MERIDIAN, Pattern);
				Result ->
					Data = match_playemeridian_ets_format(Result),
					ets:insert(?ETS_MERIDIAN,Data),
					match_all(?ETS_MERIDIAN, Pattern)
			end;
		Result->Result
	end.

%%获取其他玩家经脉数据
get_other_player_meridian(PlayerId)->
	case get_player_meridian_info(PlayerId) of
		[]->
			PlayerStatus = lib_player:get_online_info(PlayerId),
			case PlayerStatus of
				[]->[[]];
				_->
					gen_server:call(PlayerStatus#player.other#player_other.pid_meridian,{meridian,PlayerId})
			end;
		Meridian->Meridian
	end.

match_all(Table, Pattern) ->
    ets:match_object(Table, Pattern).

%匹配玩家经脉ets格式
match_playemeridian_ets_format(Data)->
	[Id,Player_id,Mer_yang,Mer_yin,Mer_wei,Mer_ren,Mer_du,Mer_chong,Mer_qi,Mer_dai,
	 Mer_yang_linggen,Mer_yin_linggen,Mer_wei_linggen,Mer_ren_linggen,Mer_du_linggen,
	 Mer_chong_linggen,Mer_qi_linggen,Mer_dai_linggen,UpType,UpTime,
	 YangTop,YinTop,WeiTop,RenTop,DuTop,ChongTop,QiTop,DaiTop]= Data,
	F_Data = #ets_meridian{
	  id=Id,                                     %% 经脉ID	
      player_id = Player_id,                          %% 玩家ID	
      mer_yang = Mer_yang,                       %% 阳脉等级	
      mer_yin = Mer_yin,                        %% 阴脉等级	
      mer_wei = Mer_wei,                         %% 维脉等级	
      mer_ren = Mer_ren,                            %% 任脉等级	
      mer_du = Mer_du,                             %% 督脉等级	
      mer_chong = Mer_chong,                          %% 冲脉等级	
      mer_qi = Mer_qi,                        %% 奇脉等级	
      mer_dai = Mer_dai,                            %% 带脉等级	
      mer_yang_linggen = Mer_yang_linggen,               %% 阳脉灵根	
      mer_yin_linggen = Mer_yin_linggen,                %% 阴脉灵根	
      mer_wei_linggen = Mer_wei_linggen,                 %% 阴维脉灵根	
      mer_ren_linggen = Mer_ren_linggen,                    %% 任脉灵根	
      mer_du_linggen = Mer_du_linggen,                     %% 督脉灵根	
      mer_chong_linggen = Mer_chong_linggen,                  %% 冲脉灵根	
      mer_qi_linggen = Mer_qi_linggen,                %% 奇脉灵根	
      mer_dai_linggen = Mer_dai_linggen,                    %% 带脉灵根	
      meridian_uplevel_typeId = UpType,            %% 升级中的经脉类型	
      meridian_uplevel_time = UpTime ,              %% 升级结束时间
	  yang_top = YangTop, %%阳脉突破值
	  yin_top = YinTop , %%阴脉突破值
	  wei_top = WeiTop, %%维脉突破值
	  ren_top = RenTop, %%任脉突破值
	  du_top = DuTop,%%督脉突破值
	  chong_top = ChongTop,%%冲脉突破值
	  qi_top = QiTop,%%奇脉突破值
	  dai_top = DaiTop%%带脉突破值 
							},
	F_Data.

%%玩家登陆，加载经脉信息
online(PlayerId)->
	case db_agent:select_meridian_by_playerid(PlayerId) of 
		[]->
			db_agent:new_meridian(PlayerId),
			Data = [0,PlayerId,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
			MeridianInfo = match_playemeridian_ets_format(Data),
			ets:insert(?ETS_MERIDIAN,MeridianInfo);
		Result ->
			Data = match_playemeridian_ets_format(Result),
			ets:insert(?ETS_MERIDIAN,Data)
	end.

%删除玩家经脉信息
delete_role_meridian(PlayerId)->
	db_agent:delete_role_meridian(PlayerId),
	ets:match_delete(?ETS_MERIDIAN, #ets_meridian{player_id=PlayerId,_='_'}),
	ok.

%%玩家下线
offline(PlayerId)->
	ets:match_delete(?ETS_MERIDIAN, #ets_meridian{player_id=PlayerId,_='_'}),
	ok.

%%测试
test(PlayerId)->
	DataBag = db_agent:get_linggen_log(PlayerId),
	[write_info(Data)||Data<-DataBag].

write_info(Data)->
	[_,_Pid,Mid,Old,New,Pt,Re,Time] = Data,
	LocalTime = util:term_to_string(util:seconds_to_localtime(Time)),
	Res = case Re of
			  1->"提升【成功】!";
			  0->"提升【失败】!"
		  end,
	Res1 = case Pt of
			1->"使用保护符";
			_->"没有使用保护符"
		   end,
	Msg = io_lib:format("~p,~p 提升~s,~p 提升前的灵根值为~p;提升后的灵根值为~p",[LocalTime,Res1,get_name_by_id(Mid),Res,Old,New]),
	{ok,S} = file:open("Linggen.txt",[append]),
	io:format(S,"~s~n",[Msg]),
	file:close(S),
	ok.

%%根据id获取经脉名称
get_name_by_id(Id)->
	case Id of
		1->"【阳脉】";
		2->"【阴脉】";
		3->"【维脉】";
		4->"【任脉】";
		5->"【督脉】";
		6->"【冲脉】";
		7->"【奇脉】";
		_->"【带脉】"
	end.

get_atp_by_id(Id)->
	case Id of
		1->"气血";
		2->"防御";
		3->"法力";
		4->"命中";
		5->"暴击";
		6->"躲闪";
		7->"攻击";
		_->"全抗"
	end.