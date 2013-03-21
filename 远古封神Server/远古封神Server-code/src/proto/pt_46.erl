%% Author: Administrator
%% Created: 2011-10-19
%% Description: TODO: 副法宝协议
-module(pt_46).

-export([read/2, write/2]).

-include("common.hrl").
-include("record.hrl").



read(46000,<<Pid:32>>)->
	{ok,[Pid]};

%%查看所有副法宝
read(46001,<<Proflv:8>>) ->
	{ok,[Proflv]};

%%副法宝提升品质
read(46002,<<Auto_Purch:8>>) ->
	{ok,[Auto_Purch]};

%%副法宝提升潜能 
read(46003,<<Auto_Purch:8>>) ->
	{ok,[Auto_Purch]};

%%副法宝提升熟练度
read(46004,<<Type:8,Auto_Purch:8>>) ->
	{ok,[Type,Auto_Purch]};

%%突破瓶颈
read(46005,<<Auto_Purch:8>>) ->
	{ok,[Auto_Purch]};

%%洗练
read(46006,<<Type:8,Auto_Purch:8>>) ->
	{ok,[Type,Auto_Purch]};

%%洗练属性变更
read(46007,<<Type:8>>) ->
	{ok,[Type]};

%%学习技能
read(46008,<<Goods_id:32,Gid:32>>) ->
	{ok,[Goods_id,Gid]};

%%神器排行榜信息
read(46010,<<Player_id:32>>) ->
	{ok,[Player_id]};

read(_Cmd, _R) ->
	io:format("_LOST_46:~p~n",[[_Cmd,_R]]),
    {error, no_match}.


%%副法宝信息
write(46000,[PlayerId,DeputyInfo])->
	case DeputyInfo of
		[] ->
			 Color = 0 ,
			 Step = 0 ,
			 Prof = 0 ,
			 Prof_max = 0,
			 Prof_lv = 0,
			 Ratio_color = 0,
			 Lucky_color = 0,
			 Lucky_color_max = 0,
			 Ratio_step = 0,
			 Lucky_step = 0,
			 Lucky_step_max = 0,
			 Ratio_prof = 0,
			 Lucky_prof = 0,
			 Lucky_prof_max = 0,
			 Need_lv = 0,
			 Attack = 0,
			 Tick_r = 0,
			 Next_attack = 0,
			 Next_tick_r = 0,
			 EnameBin = <<>>,
			 EnameLen = 0,
			 SkillLen = 0,
			 SkillBin = <<>>,
			 PackAttBin = <<>> ;
		_ ->
			[
			 Ename,
			 Color,
			 Step,
			 Prof,
			 Prof_max,
			 Prof_lv,
			 Ratio_color,
			 Lucky_color,
			 Lucky_color_max,
			 Ratio_step,
			 Lucky_step,
			 Lucky_step_max,
			 Ratio_prof,
			 Lucky_prof,
			 Lucky_prof_max,
			 Need_lv,
			 Attack,
			 Tick_r,
			 Next_attack,
			 Next_tick_r,
			 SkillInfoList,
			 AttInfoList,
			 TmpAttInfoList
			 ] = DeputyInfo,
			EnameBin = tool:to_binary(Ename),
			EnameLen = byte_size(EnameBin),
			F_skill = fun([Skill_id,Lv]) ->
					  <<Skill_id:32,Lv:8>>
			  end,
			SkillLen = length(SkillInfoList),
			SkillBin = tool:to_binary(lists:map(F_skill, SkillInfoList)),
			ChangeInfoList = lists:reverse(cmp_att(AttInfoList,TmpAttInfoList,[])),
			PackAttBin = pack_attribute_list(Step,Color,AttInfoList,TmpAttInfoList,ChangeInfoList)
	end,	
	Bin = <<PlayerId:32,EnameLen:16,EnameBin/binary,Color:8,Step:8,Prof:32,Prof_max:32,Prof_lv:8,Ratio_color:8,Lucky_color:16,Lucky_color_max:16,
			Ratio_step:8,Lucky_step:16,Lucky_step_max:16,Ratio_prof:8,Lucky_prof:16,Lucky_prof_max:16,Need_lv:8,Attack:32,Tick_r:8,Next_attack:32,Next_tick_r:8,SkillLen:16,SkillBin/binary,PackAttBin/binary>>,
	
	{ok,pt:pack(46000,Bin)};

%%查看所有法宝
write(46001,[InfoList]) ->
	Len = length(InfoList),
	F = fun([Skillid,State]) ->
				<<Skillid:32,State:8>>
		end,
	InfoBin = tool:to_binary(lists:map(F,InfoList)),
	{ok,pt:pack(46001,<<Len:16,InfoBin/binary>>)};

%%提升品质
write(46002,[Code,LuckyColor,LuckyColorMax,Gold,Coin,Bcoin]) ->
	{ok,pt:pack(46002,<<Code:8,LuckyColor:16,LuckyColorMax:16,Gold:32,Coin:32,Bcoin:32>>)};

%%提升品阶
write(46003,[Code,LuckStep,LuckyStepMax,Gold,Coin,Bcoin]) ->
	{ok,pt:pack(46003,<<Code:8,LuckStep:16,LuckyStepMax:16,Gold:32,Coin:32,Bcoin:32>>)};
	
%%提升熟练度
write(46004,[Code,Prof,Prof_max,Prof_lv]) ->
	{ok,pt:pack(46004,<<Code:8,Prof:16,Prof_max:16,Prof_lv:8>>)};

%%突破瓶颈
write(46005,[Code,LuckyProf,LuckyProfMax,Gold,Coin,Bcoin]) ->
	{ok,pt:pack(46005,<<Code:8,LuckyProf:16,LuckyProfMax:16,Gold:32,Coin:32,Bcoin:32>>)};

%%洗练
write(46006,[Code,Gold,Coin,Bcoin,Step,Color,Str_Spirit,AttInfoList,TmpAttInfoList,ChangeInfoList]) ->
	PackAttBin = pack_attribute_list(Step,Color,AttInfoList,TmpAttInfoList,ChangeInfoList),
	Bin_Spirit = tool:to_binary(Str_Spirit),
	Bin_len = byte_size(Bin_Spirit),
	{ok,pt:pack(46006,<<Code:8,Gold:32,Coin:32,Bcoin:32,Bin_len:16,Bin_Spirit/binary,PackAttBin/binary>>)};

%%洗练属性变更
write(46007,[Step,Color,AttList]) ->
	Len = length(AttList),
	F = fun([Attid,Val]) ->
				[_,Max,_,_] = data_deputy:get_wash_deputy_att(Step,Color,Attid),
				<<Attid:32,Val:32,Max:32>>
		end,
	Bin = tool:to_binary(lists:map(F, AttList)),
	{ok,pt:pack(46007,<<Len:16,Bin/binary>>)};

%% 学习技能
write(46008,[Code,Culture,Gold,Coin,Bcoin]) ->
	{ok,pt:pack(46008,<<Code:8,Culture:32,Gold:32,Coin:32,Bcoin:32>>)};

%% 技能提示
write(46009,[Skill_id,Lv,Aid,Dtype,Did]) ->
	{ok,pt:pack(46009,<<Skill_id:32,Lv:16,Aid:32,Dtype:8,Did:32>>)};

%%神器排行榜信息
write(46010,DeputyInfo) ->
	case DeputyInfo of
		[Player_id,Ename,Prof_lv,Color,Step,SkillInfoList,AttInfoList] ->
			EnameBin = tool:to_binary(Ename),
			EnameLen = byte_size(EnameBin),
			F_skill = fun([Skill_id,Lv]) ->
						<<Skill_id:32,Lv:8>>
				end,
			SkillLen = length(SkillInfoList),
			SkillBin = tool:to_binary(lists:map(F_skill, SkillInfoList)),
			F_att = fun([Att_id,Value]) ->
					[_,Max,_,_] = data_deputy:get_wash_deputy_att(Step,Color,Att_id),
				<<Att_id:32,Value:32,Max:32>>
			end,
			AttLen = length(AttInfoList),
			AttBin = tool:to_binary(lists:map(F_att,AttInfoList));
		[] ->
			Player_id = 0,
			EnameLen = 0,
			EnameBin = <<>>,
			Prof_lv = 0,
			Color = 0,
			Step = 0,
			SkillLen = 0,
			SkillBin = <<>> ,
			AttLen = 0,
			AttBin = <<>>
	end,
	{ok,pt:pack(46010,<<Player_id:32,EnameLen:16,EnameBin/binary,Prof_lv:8,Color:16,Step:16,SkillLen:16,SkillBin/binary,AttLen:16,AttBin/binary>>)};
%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

%%固定打包
pack_attribute_list(Step,Color,AttInfoList,TmpAttInfoList,ChangeInfoList) ->
	F_att = fun([Att_id,Value]) ->
					[_,Max,_,_] = data_deputy:get_wash_deputy_att(Step,Color,Att_id),
					<<Att_id:32,Value:32,Max:32>>
			end,
	AttLen = length(AttInfoList),
	AttBin = tool:to_binary(lists:map(F_att,AttInfoList)),
	F_att_tmp = fun([Att_id,Value]) ->
						[_,Max,_,_] = data_deputy:get_wash_deputy_att(Step,Color,Att_id),
						<<Att_id:32,Value:32,Max:32>>
				end,
	Att_tmpLen = length(TmpAttInfoList),
	TmpAttBin = tool:to_binary(lists:map(F_att_tmp,TmpAttInfoList)),
	F_c = fun([Att_id,Change]) ->
				  <<Att_id:32,Change:8>>
		  end,
	ChangeLen = length(ChangeInfoList),
	ChangeBin = tool:to_binary(lists:map(F_c,ChangeInfoList)),
	<<AttLen:16,AttBin/binary,Att_tmpLen:16,TmpAttBin/binary,ChangeLen:16,ChangeBin/binary>>.

%%获取属性变化
cmp_att([],_,Change) ->
	Change;
cmp_att(_,[],Change) ->
	Change;
cmp_att([],[],Change) ->
	Change;
cmp_att([[A1,V1]|Att],[[A2,V2]|TmpAtt],Change) ->
	if
		A1 == A2 andalso V1 < V2 -> %%升
			cmp_att(Att,TmpAtt,[[A1,1] | Change]);
		A1 == A2 andalso V1 > V2 -> %%降
			cmp_att(Att,TmpAtt,[[A1,0] | Change]);
		true ->
			cmp_att(Att,TmpAtt,[[A1,2] | Change])
	end.