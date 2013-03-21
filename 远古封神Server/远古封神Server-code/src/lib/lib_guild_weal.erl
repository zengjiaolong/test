%% Author: xiaomai
%% Created: 2011-3-18
%% Description: 氏族福利处理
-module(lib_guild_weal).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("guild_info.hrl").


-define(LEVEL_LIMIT, 10).
%%
%% Exported Functions
%%
-export([
%% 		 check_member_weal/1,
		 load_all_guild_h_skills/0,
		 init_h_skill/1,
		 get_weal_lasttime/1,
		 check_get_member_weal/2,
		 get_guild_level/2,
		 get_guild_skilltoken/2,
		 make_h_skills/3,
		 upgrade_h_skill/5,
		 get_guild_h_skills_info/2,
		 get_guild_h_skills_info_inner/2,
		 add_guild_reputation/4,
		 lib_add_guild_reputation/4,
		 mod_drop_add_reputation/4,		%%物品掉落直接增加氏族的技能令(模块外调用)
		 lib_mod_drop_add_reputation/4,	%%不对外提供调用 ,如需，请调用 mod_drop_add_reputation/4
		 lib_guild_call_boss/4]).

%%
%% API Functions
%%
load_all_guild_h_skills() ->
%% 	io:format("load h skills\n"),
	Objects = ets:tab2list(?ETS_GUILD),
	handle_guild_h_skill(Objects).
handle_guild_h_skill([]) ->
%% 	io:format("ok\n"),
	ok;
handle_guild_h_skill([Guild|Objects]) ->
	GuildId = Guild#ets_guild.id,
	HSkills = get_h_skills(GuildId),
	case HSkills =:= [] of
		false  ->
%% 			io:format("noaction:~p\n", [GuildId]),
			skip;
		true ->
%% 			io:format(" go action:~p\n", [GuildId]),
			init_h_skill(GuildId)
	end,
	handle_guild_h_skill(Objects).

%%对物品使用的接口
%%添加玩家所属的氏族技能令
add_guild_reputation(GuildId, SkillsTos, PlayerId, PlayerName) ->
	%%因为涉及到并发问题，此操作专门使用Id号为24的进程执行
	ProcessName = misc:create_process_name(guild_p, [24]),
	GuildPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->
						Pid;
					false ->
						mod_guild:start_mod_guild(ProcessName)
				end;
			_ ->
				mod_guild:start_mod_guild(ProcessName)
		end,
	
	gen_server:cast(GuildPid, 
					{apply_cast, lib_guild_weal, lib_add_guild_reputation, [GuildId, SkillsTos, PlayerId, PlayerName]}).

lib_add_guild_reputation(GuildId, SkillsTos, _PlayerId, PlayerName) ->
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			skip;
		Guild ->
			NewReputation = Guild#ets_guild.reputation + SkillsTos,
			ValueList = [{reputation, NewReputation}],
			FieldList = [{id, GuildId}],
			db_agent:add_guild_reputatioin(ValueList, FieldList),
			% 广播氏族成员
			lib_guild_inner:send_guild(0, 0, GuildId, add_guild_reputation, [SkillsTos, PlayerName]),
			NewGuild = Guild#ets_guild{reputation = NewReputation},
			lib_guild_inner:update_guild(NewGuild)
	end.
%%物品掉落直接增加氏族的技能令
mod_drop_add_reputation(GuildName, GuildId, BossName, Num) ->
	gen_server:cast(mod_guild:get_mod_guild_pid(), {apply_cast, lib_guild_weal, lib_mod_drop_add_reputation, [GuildName, GuildId, BossName, Num]}).

lib_mod_drop_add_reputation(GuildName, GuildId, BossName, Num) ->
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			skip;
		Guild ->
			NewReputation = Guild#ets_guild.reputation + Num,
			ValueList = [{reputation, NewReputation}, {boss_sv, 0}],
			FieldList = [{id, GuildId}],
			db_agent:add_guild_reputatioin(ValueList, FieldList),
			NewGuild = Guild#ets_guild{reputation = NewReputation,
									   boss_sv = 0},
%% 			?DEBUG("new BossSV:~p", [NewGuild#ets_guild.boss_sv]),
			lib_guild_inner:update_guild(NewGuild),
			%%广播
			ConTent1 = io_lib:format("在 <font color='#FEDB4F'>[~s]</font></a> 氏族成员的一轮猛攻之下，<font color='#FEDB4F'>[~s]</font>缓缓地倒下了。",
								[GuildName, BossName]),
			case Num > 0 of
				true ->
					ConTent2 = io_lib:format("<font color='#FFFF32'>[~s]</font>氏族成员在<font color='#FFFF32'>[~s]</font>的残骸中搜索出了技能令。",
											[GuildName, BossName]);
				false ->
					ConTent2 = ""
			end,
			ConTent  = ConTent1 ++ ConTent2,
			spawn(lib_chat, broadcast_sys_msg, [2, ConTent])
	end.

lib_guild_call_boss(ScenePid, Post, GuildId, Type) ->
	{NeedLv, NeedFunds, MonId, MonName, X, Y} = data_guild:get_guild_call_boss(Type),
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			[0];
		Guild ->
			#ets_guild{name = GuildName, 
					   level = GLv,
					   funds = Funds,
					   lct_boss = LastCTime,
					   boss_sv = BossSV} = Guild,
			if 
				Post =< 0 orelse Post > 3 ->
					[3];%%没权限
				Funds =< 0 orelse Funds < NeedFunds ->
				   [5];
			   BossSV =/= 0 ->
				   [6];
			   NeedLv > GLv ->
				   [8];%%等级不够
			   true ->
				   NowTime = util:unixtime(),
				   LCTimes = util:string_to_term(tool:to_list(LastCTime)),
				   LCTime = lists:nth(Type, LCTimes),
				   NowDate = util:get_date(),
				   case lists:member(NowDate, ?GUILD_CALL_BOSS_DATE) of
					   true ->
						   case util:is_same_date(LCTime, NowTime) of
							   true ->%%是同一天，不能多召唤相同的怪
								   [2];
							   false ->
								   [Time1, Time2, Time3] = LCTimes,
								   NewLCTimes = 
									   case Type of
										   1 ->
											   [NowTime, Time2, Time3];
										   2 ->
											   [Time1, NowTime, Time3];
										   3 ->
											   [Time1, Time2, NowTime]
									   end,
								   gen_server:cast(ScenePid, {create_mon_boss, GuildId, MonId, X, Y, MonName, GuildName}),
								   NewLCTime = util:term_to_string(NewLCTimes),
								   ValueList = [{lct_boss, NewLCTime},
												{funds, NeedFunds, sub},
												{boss_sv, MonId}],
								   FieldList = [{id, Guild#ets_guild.id}],
								   db_agent:update_guild_lct_boss(ValueList, FieldList),
								   NewGuild = Guild#ets_guild{lct_boss = NewLCTime,
															  funds = Funds - NeedFunds,
															  boss_sv = MonId},
								   lib_guild_inner:update_guild(NewGuild),
								   [1]
						   end;
					   false ->%%不是周一三五，不能召唤
						   [9]
				   end
			end
	end.

%% -----------------------------------------------------------------
%% 40025 领取福利
%% -----------------------------------------------------------------
check_get_member_weal(Status, LTGetWeal) ->
	case Status#player.guild_id of
		0 ->%%没氏族
			[0, Status];
		GuildId ->
%% 			case check_member_weal(Status#player.id, LTGetWeal) of
%% 				[1] ->%%已经领取过了
%% 					[2, Status];
%% 				[0] ->
					case catch mod_guild_manor:get_guild_level(GuildId, Status#player.id) of
						{ok, Contribute, GLevel, GFunds} ->
							if 
								GFunds < 0 ->%%资金为负，不能领取
									[3, Status];
								true ->
									case check_member_weal(Status#player.id, LTGetWeal) of
										[1] ->%%已经领取过了
											[2, Status];
										[0] ->
											PostType = get_guild_posttype(Status#player.guild_position),
											Welfare = count_welfare_bcoin(Contribute, PostType, GLevel),
											NewStatus = lib_goods:add_money(Status, Welfare, bcoin, 4025),
											[1, NewStatus]
									end
							end;
						_OtherError  ->
							[0, Status]
					end
%% 			end
	end.

%%获取上一次领取氏族福利的时间
get_weal_lasttime(PlayerId) ->
	case get_guildweal_dict(guild_welfare) of
		undefined ->
			case db_agent:get_weal_lasttime(PlayerId) of
				[] ->
					0;
				[LTGetTime] ->
					LTGetTime
			end;
		Value ->
			Value
	end.
%% -----------------------------------------------------------------
%% 40026  获取氏族高级技能信息
%% -----------------------------------------------------------------
get_guild_skilltoken(PidSend, GuildId) ->
	[ReturnSkTo, ReturnSkInfo] = 
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			[0, []];
		Guild ->
			#ets_guild{id = GuildId,
					   reputation = KillsTo} = Guild,
			HSkills = get_h_skills(GuildId),
			case HSkills =/= [] of
				true when length(HSkills) =:= 7->
					HSksList = lists:map(fun(X) -> 
												 lib_guild_inner:handle_guild_skills_info(X)
										 end, HSkills),
					[KillsTo, HSksList];
				true -> 
					[0, []];
				false ->
					NewHSkills = init_h_skill(GuildId),
					Result = lists:any(fun(Elem) ->  case is_record(Elem, ets_guild_skills_attribute) of
														 true ->
															 false ;
														 false ->
															 true
													 end
									   end, NewHSkills),
					case Result of
						false ->
							HSksList = lists:map(fun(X) -> 
														 lib_guild_inner:handle_guild_skills_info(X)
												 end, HSkills),
							[KillsTo, HSksList];
						true ->
							[0, []]
					end
			end
	end,
	{ok, BinData} = pt_40:write(40026, [ReturnSkTo, ReturnSkInfo]),
	lib_send:send_to_sid(PidSend, BinData).

upgrade_h_skill(PGuildId, GuildPost, GuildId, HSkillId, HKLevel) ->
	if
		PGuildId =:= 0 ->
			[2, HKLevel, 0];
		PGuildId =/= GuildId ->
			[2, HKLevel, 0];
		GuildPost =/= 1 ->
			[3, HKLevel, 0];
		true ->
			case lib_guild_inner:get_guild(GuildId) of
				[] ->
					error;
				Guild ->
					case lib_guild_inner:get_ets_guild_skill_attribute_one(GuildId, HSkillId) of
						[] ->
							error;
						[HSkill] ->
						#ets_guild{reputation = Reputation,
								   level = GuildLevel,
								   funds = GuildFunds} =  Guild,
						HKLevelOld = HSkill#ets_guild_skills_attribute.skill_level,
						if 
							HKLevelOld >= ?LEVEL_LIMIT ->
								[4, HKLevel, 0];%%最高等级了
							true ->
								{_Add, NeedFunds, RepuNeed} = data_guild:get_guild_h_skill_base(HSkillId, HKLevelOld + 1),
								if
									HKLevelOld >= GuildLevel ->
										[5, HKLevel, 0];%%不能高于氏族等级
									Reputation =< 0 orelse Reputation < RepuNeed ->
										[6, HKLevel, 0];%%技能令不足
									NeedFunds >= GuildFunds ->
										[7, HKLevel, 0];
									true ->%%可以升级
										NewHKillLv = HKLevelOld + 1,
										lib_guild_inner:guild_skills_level_upgrade(GuildId, HSkillId, NewHKillLv),
										GuildSkillNew = HSkill#ets_guild_skills_attribute{skill_level = NewHKillLv},
										%%更新氏族技能缓存
										NewGuildFunds = GuildFunds - NeedFunds,
										ReputationRest = Reputation - RepuNeed,
										lib_guild_inner:update_guild_skill_attribute(GuildSkillNew),
										ValueList = [{funds, NewGuildFunds},
													 {reputation, ReputationRest}],
										WhereList = [{id, GuildId}],
										lib_guild_inner:update_guild_by_skills(ValueList, WhereList),
										GuildNew = Guild#ets_guild{reputation = ReputationRest,
																   funds = NewGuildFunds},
										%%更新氏族缓存
										lib_guild_inner:update_guild(GuildNew),
										[1, NewHKillLv, Guild#ets_guild.chief_id]
								end
						end
					end
			end
	end.
								
								
							
							
								
						
					
		
		
	
%%获取高级技能信息
get_h_skills(GuildId) ->
	MG = ets:fun2ms(fun(G) when G#ets_guild_skills_attribute.guild_id == GuildId 
						 andalso G#ets_guild_skills_attribute.skill_id >= 4 
						 andalso G#ets_guild_skills_attribute.skill_id =< 10 ->
							G
					end),
	ets:select(?ETS_GUILD_SKILLS_ATTRIBUTE, MG).


%%获取氏族成员的贡献值和氏族等级
get_guild_level(GuildId, PlayerId) ->
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			fail;
		Guild ->
			case lib_guild_inner:get_guild_member_by_guildandplayer_id(GuildId, PlayerId) of
				[] ->
					fail;
				GuildMember ->
					Donate = GuildMember#ets_guild_member.donate_total,
					Level = Guild#ets_guild.level,
					Funds = Guild#ets_guild.funds,
					{ok, Donate, Level, Funds}				
			end
	end.
%%更新玩家的高级氏族福利数据
make_h_skills(HSKillOld, HSKillAdd, HSkillId) ->
	case HSkillId of
		4 ->
			HSKillNew = HSKillOld#guild_h_skill{g_att = HSKillAdd};
		5 ->
			HSKillNew = HSKillOld#guild_h_skill{g_def = HSKillAdd};
		6 ->
			HSKillNew = HSKillOld#guild_h_skill{g_hp = HSKillAdd};
		7 ->
			HSKillNew = HSKillOld#guild_h_skill{g_mp = HSKillAdd};
		8 ->
			HSKillNew = HSKillOld#guild_h_skill{g_hit = HSKillAdd};
		9 ->
			HSKillNew = HSKillOld#guild_h_skill{g_dodge = HSKillAdd};
		10 ->
			HSKillNew = HSKillOld#guild_h_skill{g_crit = HSKillAdd}
	end,
	HSKillNew.

get_guild_h_skills_info(GuildId, PlayerId) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_weal, get_guild_h_skills_info_inner, [GuildId, PlayerId]})of
			error -> 
%% 				 ?DEBUG("get_guild_h_skills_info error",[]),
				 {[], 0, #guild_h_skill{}};
			 Data -> 
%% 				 ?DEBUG("get_guild_h_skills_info succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
%% 			?DEBUG("get_guild_h_skills_info fail for the reason:[~p]",[_Reason]),
			{[], 0, #guild_h_skill{}}
	end.
%%处理福利的数据
get_guild_h_skills_info_inner(GuildId, PlayerId) ->
	GFeats = lib_skyrush:get_member_feats(GuildId, PlayerId),
	%%联盟中的氏族Id
	GAlliance = lib_guild_alliance:get_guild_alliance(GuildId), 
	case get_h_skills(GuildId) of
		[] ->
			{GAlliance, GFeats, #guild_h_skill{}};
		HSKills when length(HSKills) =:= 7->
			GHSkill = init_h_skills_elem(#guild_h_skill{}, HSKills),
			{GAlliance, GFeats, GHSkill};
		_HSKillsOther ->
			{GAlliance, GFeats, #guild_h_skill{}}
	end.
%%循环修改福利数据
init_h_skills_elem(GHSKold, []) ->
	GHSKold;
init_h_skills_elem(GHSKold, [HSKill|HSKills]) ->
	#ets_guild_skills_attribute{skill_id = SkillId,
								skill_level = HKLevel} = HSKill,
	{Add, _NeedFunds, _RepuNeed} = data_guild:get_guild_h_skill_base(SkillId, HKLevel),
	GHSKNew = make_h_skills(GHSKold, Add, SkillId),
	init_h_skills_elem(GHSKNew, HSKills).
	

%% get_player_g_skilltos(PlayerId) ->
%% 	case get(player_g_skilltos) of
%% 		undefined ->
%% 			case db_agent:get_player_g_skilltos(PlayerId) of
%% 				[] ->
%% 					db_agent:add_guild_manor_cd(PlayerId, 300, 0, 0, 0),
%% 					put(player_g_skilltos, 0),
%% 					0;
%% 				[SkillTo] ->
%% 					SkillTo
%% 			end;
%% 		Value ->
%% 			Value
%% 	end.
%% update_player_g_skilltos(PlayerId, NewSkillTos) ->
%% 	put(player_g_skilltos, NewSkillTos),
%% 	db_agent:update_player_g_skilltos(PlayerId, NewSkillTos).
%%
%% Local Functions
%%
%% -----------------------------------------------------------------
%% 40024 查询今日是否领取过福利
%% -----------------------------------------------------------------
check_member_weal(PlayerId, LTGetWeal) -> 
	NowTime = util:unixtime(),
	%% 获取当天0点和第二天0点
	{Today, NextDay} = util:get_midnight_seconds(NowTime),
	if 
		LTGetWeal =:= 0 ->
			db_agent:add_guild_manor_cd(PlayerId, 300, 0, NowTime),
			put_guildweal_dict(guild_welfare, NowTime),
			[0];
		true ->
%% 			io:format("Today:~p, Now:~p, NextDay:~p\n", [Today, LTGetWeal, NextDay]),
			case Today =< LTGetWeal andalso LTGetWeal < NextDay of
				true ->%%已经领取过了
					[1];
				false ->
					db_agent:update_weal_lasttime(PlayerId, NowTime),
					put_guildweal_dict(guild_welfare, NowTime),
					[0]
			end
	end.

get_guildweal_dict(Type) ->
	get(Type).
put_guildweal_dict(Type, Value) ->
	put(Type, Value).

%%位置转化成职位加成
get_guild_posttype(Post) ->
	if
		Post =:= 1 ->
			1.3;
		Post >= 2 orelse post =< 3 ->
			1.2;
		Post >= 4 orelse Post =< 7 ->
			1.1;
		true ->
			1
	end.

%%福利公式转换
count_welfare_bcoin(Contribute, PostType, Level) ->
	BCoin = ?WELFARE_ONE * util:lnx(Contribute + 1) + ?WELFARE_TWO * PostType + ?WELFARE_THREE * Level,
	util:floor(BCoin).
%%初始化氏族的高级技能
init_h_skill(GuildId) ->
%% 	io:format("33333\n"),
	IDS = lists:seq(4, 10),
	lists:map(fun(Id) ->
%% 					  io:format("44444:~p\n", [Id]),
					  GSkillAtt = 
						  #ets_guild_skills_attribute{guild_id = GuildId,
													  skill_id = Id, 
													  skill_name = "",
													  skill_level = 0},
%% 					  io:format("3333232434:~p\n", [Id]),
					  case db_agent:init_guild_skill_attribute(GSkillAtt) of
						  {mongo, Ret} ->
%% 							  io:format("5555\n"),
							  GuildSkillsAttrEts = GSkillAtt#ets_guild_skills_attribute{id = Ret},
							  lib_guild_inner:update_guild_skill_attribute(GuildSkillsAttrEts),
							  GuildSkillsAttrEts;
						  1 ->
%% 							   io:format("6666\n"),
							  case db_agent:get_guild_skill_attribute(GuildId, Id) of
								  [] ->
									  [];
								  GuildSkillsAttr ->
									  GuildSkillsAttrEts = list_to_tuple([ets_guild_skills_attribute] ++ GuildSkillsAttr),
									  lib_guild_inner:update_guild_skill_attribute(GuildSkillsAttrEts),
									  GuildSkillsAttrEts
							  end;
						  _Other ->
%% 							   io:format("7777::~p\n", [_Other]),
							  []
					  end
			  end, IDS).

	