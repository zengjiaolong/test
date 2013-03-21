%%%------------------------------------
%%% @Module  : pt_26
%%% @Author  : dhq
%%% @Email   : denghuiqiang@jieyou.com
%%% @Created : 2010.10.07
%%% @Description: 挂机协议
%%%------------------------------------

-module(pt_26).
-export([read/2, write/2]).
-include("common.hrl").

%%
%% 客户端 -> 服务端
%%

%% 场景怪物信息
read(26001, <<SceneId:32>>) ->
    {ok, SceneId};

%% 打开挂机面板
read(26002, <<>>) ->
    {ok, <<>>};

%% 开始/停止挂机
read(26003, <<Sign:8>>) ->
    {ok, Sign};

%% 保存挂机设置
read(26004, <<SkillConfig:8, _SkillLen:16, Skill1:32, Skill2:32, Skill3:32, Skill4:32, Skill5:32, 
		  _CSkillLen:16, CSkill1:32, CSkill2:32, CSkill3:32, CSkill4:32, CSkill5:32, HookNum:8, 
		  _EquipConfigLen:16, EquipConfig1:32, EquipConfig2:32, EquipConfig3:32, EquipConfig4:32, 
		  _QualityConfigLen:16, QualityConfig1:32, QualityConfig2:32, QualityConfig3:32, QualityConfig4:32, 
		  Pick:8, HpPool:8, MpPool:8, Repair:8, Hp:8, HpVal:8, Mp:8, MpVal:8, 
		  Revive:8, ReviveStyle:8, Pet:8, Exp:8, ExpStyle:8, HpOpt:8, MpOpt:8,TaskMonFir:8>>) ->
	SkillList = [Skill1, Skill2, Skill3, Skill4, Skill5],
	ColiseumSkillList = [CSkill1, CSkill2, CSkill3, CSkill4, CSkill5],
   	EquipConfig = [EquipConfig1, EquipConfig2, EquipConfig3, EquipConfig4],
  	QualityConfig = [QualityConfig1, QualityConfig2, QualityConfig3, QualityConfig4],
	Config = [SkillConfig, SkillList, ColiseumSkillList, HookNum, EquipConfig, QualityConfig, Pick, HpPool, MpPool, Repair, Hp, HpVal, Mp, MpVal, Revive, ReviveStyle, Pet, Exp, ExpStyle, HpOpt, MpOpt,TaskMonFir],
   	{ok, Config};

read(26006, <<>>) ->
    {ok, []};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%% 服务端 -> 客户端
%%

%% 场景怪物信息
write(26001, [SceneId, Mon]) ->
    Len = length(Mon),
    F = fun({MonId, Name, X, Y}) ->
        NewName = tool:to_binary(Name),
        NLen = byte_size(NewName),
        <<MonId:32, NLen:16, NewName/binary, X:16, Y:16>>
    end,
    RB = tool:to_binary([F(M) || M <- Mon]),
    Data = <<SceneId:32, Len:16, RB/binary>>,
    {ok, pt:pack(26001, Data)};

%% 打开挂机面板
write(26002, [SkillConfig, SkillList, ColiseumSkillList, HookVal, EquipConfig, QualityConfig, Pick, HpPool, MpPool, Repair, Hp, HpVal, Mp, MpVal, Revive, ReviveStyle, Pet, Exp, ExpStyle, HpOpt, MpOpt,TaskMonFir]) ->
    SkillLen = length(SkillList),
    NewSkillList = tool:to_binary([<<S:32>> || S <- SkillList]),
	ColiseumSkillLen = length(ColiseumSkillList),
    NewColiseumSkillList = tool:to_binary([<<CS:32>> || CS <- ColiseumSkillList]),
    EquipConfigLen = length(EquipConfig),
    NewEquipConfig = tool:to_binary([<<E:32>> || E <- EquipConfig]),
    QualityConfigLen = length(QualityConfig),
    QualityConfig1 = tool:to_binary([<<Q:32>> || Q <- QualityConfig]),
    Data = <<SkillConfig:8, SkillLen:16, NewSkillList/binary, ColiseumSkillLen:16, NewColiseumSkillList/binary, HookVal:8, EquipConfigLen:16, 
			 NewEquipConfig/binary, QualityConfigLen:16, QualityConfig1/binary, Pick:8, HpPool:8, MpPool:8, 
			 Repair:8, Hp:8, HpVal:8, Mp:8, MpVal:8, Revive:8, ReviveStyle:8, Pet:8, Exp:8, ExpStyle:8, HpOpt:8, MpOpt:8,TaskMonFir:8>>,
    {ok, pt:pack(26002, Data)};

%% 开始/停止挂机
write(26003, [Result, Sta]) ->
    Data = <<Result:8, Sta:8>>,
    {ok, pt:pack(26003, Data)};

%% 保存挂机设置
%% Result 1保存成功，0失败
write(26004, Result) ->
    Data = <<Result:8>>,
    {ok, pt:pack(26004, Data)};

%%查询最高经验挂机时间
write(26006,[Timestamp])->
	{ok,pt:pack(26006,<<Timestamp:32>>)};

write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.
