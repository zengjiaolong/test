%%%--------------------------------------
%%% @Module  : pp_skill
%%% @Author  : ygzj
%%% @Created : 2010.10.06 
%%% @Description:  技能管理
%%%--------------------------------------
-module(pp_skill).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%% 学习技能
handle(21001, Player, SkillId) ->
    lib_skill:upgrade_skill(Player, SkillId, 0);
	
%% 获取技能列表
handle(21002, Player, _) ->
    Skills = data_skill:get_skill_id_list(Player#player.career),
    {ok, BinData} = pt_21:write(21002, [Skills, Player#player.other#player_other.skill]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

%%轻功技能等级信息
handle(21003,Status,_) ->
	SkillList = Status#player.other#player_other.light_skill,
	Light_Lv = 
	case lists:keyfind(50000, 1, SkillList) of
			false -> 
				0;
			%% 升级技能
			{_, Skill_Lv} ->  
				Skill_Lv
		end,
	{ok, BinData} = pt_21:write(21003, [Light_Lv]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);

%% 学习被动技能
handle(21004, Player, SkillId) ->
	IsCost = 
		case lists:member(SkillId,data_passive_skill:get_book_skill_list()) of
			true -> 0;
			false -> 1
		end,
    lib_skill:upgrade_passive_skill(Player, SkillId, IsCost);
	
%% 获取被动技能列表
handle(21005, Player, _) ->
    Skills = data_passive_skill:get_skill_id_list(),
    {ok, BinData} = pt_21:write(21005, [Skills, Player#player.other#player_other.passive_skill]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

handle(21006,Status,[])->
	case lib_skill:use_couple_skill(Status) of
		[ok,Cd,NewStatus]->
			{ok,BinData} = pt_21:write(21006, [1,Cd]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			{ok,NewStatus};
		[Error,Cd]->
			{ok,BinData} = pt_21:write(21006, [Error,Cd]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
	end;

handle(_Cmd, _Status, _Data) ->
    {error, "pp_skill no match"}.
