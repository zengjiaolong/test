%% Author: xianrongMai
%% Created: 2011-12-20
%% Description: 处理氏族联盟的方法/接口
-module(lib_guild_alliance).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("guild_info.hrl").

%%
%% Exported Functions
%%
-export([
		 handle_alliances_apply_timeout/1,	%% 处理超时的氏族联盟申请
		 disband_guild_alliance/1,			%% 处理被解散的氏族的联盟数据
		 delete_update_alliance/2,			%% 处理被吞并的氏族的联盟数据
		 demise_guild_alliance/3,			%% 禅让族长修改氏族联盟数据
		 upmem_guild_alliance/3,			%% 氏族成员变化修改氏族联盟数据
		 upgrade_guild_alliance/2,			%% 氏族升级修改氏族联盟数据
		 
		 get_guild_alliances/1,				%% 获取当前氏族的联盟氏族信息
		 get_alliances_list/1,				%% 查询发起的联盟申请和收到的联盟申请
		 send_member_alliances/2,
		 
		 stop_alliance/3,					%% 40092 中止氏族联盟关系
		 refuse_alliance/3,					%% 40091 拒绝氏族联盟申请
		 agree_alliance/3,					%% 40090 同意氏族联盟申请
		 cancel_alliance/3,					%% 40089 取消氏族联盟申请
		 apply_alliance/3,					%% 40088 发出氏族联盟申请
		 
		 get_guild_alliance/1,				%% 获取联盟的氏族Id	
		 load_guild_alliance/0,				%% 加载氏族联盟表
		 load_guild_alliance_apply/0		%%  加载氏族联盟申请表
		 ]).

%%
%% API Functions
%%
%%加载氏族联盟表
load_guild_alliance() ->
	%%获取氏族联盟表
	Alliances = db_agent:get_all_alliances(),
	lists:foreach(fun(Elem) ->
						  [EId, EGid, EBGid, EBName, EBRealm] = Elem,
						  EAlliance = #ets_g_alliance{id = EId,
													  gid = EGid,
													  bgid = EBGid,
													  bname = EBName,
													  brealm = EBRealm},
						  ets_update_alliance(EAlliance)
				  end, Alliances).
%%加载氏族联盟申请表
load_guild_alliance_apply() ->
	%%获取氏族联盟申请表
	AApply = db_agent:get_all_alliance_apply(),
	lists:foreach(fun(Elem) ->
						  [EId, EAGid, EBGid, EAGName, EBGName, EALv, EBLv, 
						   EARealm, EBRealm, EAMemStr, EBMemStr, 
						   EACId, EBCId, EAChName, EBChName, ETime] = Elem,
						  EAMem = util:string_to_term(tool:to_list(EAMemStr)),
						  EBMem = util:string_to_term(tool:to_list(EBMemStr)),
						  EAApply = #ets_g_alliance_apply{	
														id = EId,                          %% 自增Id
														agid = EAGid,                      %% 申请氏族Id	
														bgid = EBGid,                      %% 被邀请氏族Id	
														agname = EAGName,                  %% 申请氏族名字	
														bgname = EBGName,                  %% 被邀请氏族名字	
														alv = EALv,                        %% 申请氏族等级	
														blv = EBLv,                        %% 被邀请氏族等级	
														arealm = EARealm,                  %% 申请氏族所属部落	
														brealm = EBRealm,                  %% 被邀请氏族所属部落	
														amem = EAMem,                      %% 申请氏族成员情况[当前人口数，人口最大容量]	
														bmem = EBMem,                      %% 被邀请氏族成员情况[当前人口数，人口最大容量]
														acid = EACId,                      %% 申请氏族族长Id	
														bcid = EBCId,                      %% 被邀请氏族族长Id	
														acname = EAChName,                 %% 申请氏族的族长名字	
														bcname = EBChName,                 %% 被邀请氏族族长名字	
														time = ETime                       %% 申请时间	
													   },
						  ets_update_alliance_apply(EAApply)
				  end, AApply).

%%处理超时的氏族联盟申请
handle_alliances_apply_timeout(NowTime) ->
	Time = NowTime - ?ONE_DAY_SECONDS,
%% 	Time = NowTime - 20,
	Ms = ets:fun2ms(fun(M) when M#ets_g_alliance_apply.time < Time ->
							M#ets_g_alliance.id
					end),
	List = ets:select(?GUILD_ALLIANCE_APPLY, Ms),
	lists:foreach(fun(Elem) ->
						  WhereList = [{id, Elem}],
						  db_agent:delete_alliance(guild_alliance_apply, WhereList),
						  ets_delete_id_alliance(?GUILD_ALLIANCE_APPLY, Elem)
				  end, List).
%% -----------------------------------------------------------------
%% 40088 发出氏族联盟申请
%% -----------------------------------------------------------------
apply_alliance(PlayerId, SourGid, DestGid) ->
	SourGuild = lib_guild_inner:get_guild(SourGid),
	DestGuild = lib_guild_inner:get_guild(DestGid),
	if
		is_record(SourGuild, ets_guild) =:= false orelse is_record(DestGuild, ets_guild) =:= false ->
			0;
		true ->
			#ets_guild{chief_id = SourChiefId,
					   chief_name = SourChName,
					   name = SourName,
					   level = SourLv,
					   member_num = SourMNum,
					   realm = SourRealm,
					   unions = SourUnions,
					   del_alliance = DelTime} = SourGuild,
			#ets_guild{chief_id = DestChiefId,
					   chief_name = DestChName,
					   name = DestName,
					   level = DestLv,
					   member_num = DestMNum,
					   realm = DestRealm,
					   unions = DestUnions} = DestGuild,
			NowTime = util:unixtime(),
			Diff = NowTime - DelTime,
			if
				SourChiefId =/= PlayerId ->%%只有氏族长才能发起联盟申请
					5;
				SourRealm =:= DestRealm ->%%不能对跟自己部落相同的氏族发起申请
					3;
				SourUnions =/= 0 ->%%本氏族正在进行氏族合并，无法发起联盟申请
					8;
				DestUnions =/= 0 ->%%对方氏族正在进行氏族合并，无法发起联盟申请
					9;
				Diff =< ?ONE_DAY_SECONDS ->%%您离上次取消联盟的时间不足24小时
					10;
				true ->
					case ets_get_realm_alliance(SourGid, DestRealm) of
						[] ->%%没有该部落的联盟
							case ets_get_realm_alliance(DestGid, SourRealm) of
								[] ->%%受邀方没有本部落的联盟
									case ets_get_realm_apply(SourGid, DestRealm) of
										[] ->%%没有做申请
											%%计算氏族人数上限
											SourPLv = lib_guild:get_guild_skill_level(SourGid, 3),
											SourMLimit = data_guild:get_guild_config(guild_member_base,[]) + SourPLv * 5,
											DestPLv = lib_guild:get_guild_skill_level(DestGid, 3),
											DestMLimit = data_guild:get_guild_config(guild_member_base,[]) + DestPLv * 5,
											%%统计人口数量数据
											SourMem = [SourMNum,SourMLimit],
											DestMem = [DestMNum,DestMLimit],
											
											Data = [SourGid, DestGid, SourName, DestName, SourLv, DestLv, 
													SourRealm, DestRealm, 
													util:term_to_string(SourMem),util:term_to_string(DestMem),
													SourChiefId, SourChName, DestChiefId, DestChName,
													NowTime],
											%%更新数据库
											{_, Id} = db_agent:db_insert_alliance_apply(Data),
											%%更新ets
											AApply = #ets_g_alliance_apply{id = Id,
																		   agid = SourGid,
																		   bgid = DestGid,
																		   agname = SourName,
																		   bgname = DestName,
																		   alv = SourLv,
																		   blv = DestLv,
																		   arealm = SourRealm,
																		   brealm = DestRealm,
																		   amem = SourMem,
																		   bmem = DestMem,
																		   acid = SourChiefId,
																		   bcid = DestChiefId,
																		   acname = SourChName,
																		   bcname = DestChName,
																		   time = NowTime},
											ets_update_alliance_apply(AApply),
											%%发邮件
											Param = {DestChName, SourName},
											send_alliance_mail(Param, alliance_apply),
											1;
										_SA ->%%您已经向该部落的氏族踢出了一个联盟申请
											6
									end;
								_DH ->%%该氏族已有一个您所在部落的氏族联盟
									7
							end;
						_SH ->%%你已经有该部落的氏族联盟了
							12
					end
			end
	end.
	
%% -----------------------------------------------------------------
%% 40089 取消氏族联盟申请
%% -----------------------------------------------------------------
cancel_alliance(PlayerId, SourGid, DestGid) ->		
	SourGuild = lib_guild_inner:get_guild(SourGid),
	if
		is_record(SourGuild, ets_guild) =:= false ->
			0;
		true ->
			#ets_guild{chief_id = SourChId} = SourGuild,
			if
				SourChId =/= PlayerId ->
					3;
				true ->
					case ets_get_gid_apply(SourGid, DestGid) of
						[] ->
							4;
						Applies when is_list(Applies)->
							%%删除数据库
							WhereList = [{agid, SourGid}, {bgid, DestGid}],
							db_delete_alliance(guild_alliance_apply, WhereList),
							Pattern = #ets_g_alliance_apply{agid = SourGid, bgid = DestGid, _ = '_'},
							ets_delete_alliance(?GUILD_ALLIANCE_APPLY, Pattern),
							1;
						_Other ->
							0
					end
			end
	end.

%% -----------------------------------------------------------------
%% 40090 同意氏族联盟申请
%% -----------------------------------------------------------------
agree_alliance(PlayerId, SourGid, DestGid) ->
	SourGuild = lib_guild_inner:get_guild(SourGid),
	DestGuild = lib_guild_inner:get_guild(DestGid),
	if
		is_record(SourGuild, ets_guild) =:= false orelse is_record(DestGuild, ets_guild) =:= false ->
			0;
		true ->
			#ets_guild{chief_id = SourChiefId,
					   name = SourName,
					   realm = SourRealm,
					   del_alliance = DelTime} = SourGuild,
			#ets_guild{chief_name = DestChName,
					   name = DestName,
					   realm = DestRealm} = DestGuild,
			NowTime = util:unixtime(),
			Diff = NowTime - DelTime,
			if
				SourChiefId =/= PlayerId ->%%只有氏族长才能同意联盟申请
					5;
				SourRealm =:= DestRealm ->%%部落居然一样，出错了
					8;
				Diff =< ?ONE_DAY_SECONDS ->%%您离上次取消联盟的时间不足24小时
					9;
				true ->
					case ets_get_realm_alliance(SourGid, DestRealm) of
						[] ->%%没有该部落的联盟
							case ets_get_realm_alliance(DestGid, SourRealm) of
								[] ->%%受邀方没有本部落的联盟
									case ets_get_realm_apply(DestGid, SourRealm) of
										[] ->%%没有做申请
											6;
										_A ->%%ok
											%%删除申请记录
											WhereList1 = [{agid, SourGid}, {brealm, DestRealm}],
											WhereList2 = [{agid, DestGid}, {brealm, SourRealm}],
											WhereList3 = [{bgid, "in", [SourGid, DestGid]}],
											erlang:spawn(fun() ->
																 db_delete_alliance(guild_alliance_apply, WhereList1),
																 db_delete_alliance(guild_alliance_apply, WhereList2),
																 db_delete_alliance(guild_alliance_apply, WhereList3)
														 end),
											%%删除ets
											ets_select_delete_apply(SourGid, SourRealm, DestGid, DestRealm),
											%%添加一条联盟数据
											Data1 = [SourGid, DestGid, DestName, DestRealm],
											Data2 = [DestGid, SourGid, SourName, SourRealm],
											{_R1, Id1} = db_agent:db_insert_alliance(Data1),
											{_R2, Id2} = db_agent:db_insert_alliance(Data2),
											%%更新ets
											Alliance1 = 
												#ets_g_alliance{
																id = Id1,                                     %% 自增Id	
																gid = SourGid,                                %% 氏族Id	
																bgid = DestGid,                               %% 联盟氏族的Id	
																bname = DestName,                             %% 联盟氏族的名字	
																brealm = DestRealm                            %% 联盟的氏族的部落Id	
															   },
											Alliance2 = 
												#ets_g_alliance{
																id = Id2,                                     %% 自增Id	
																gid = DestGid,                                %% 氏族Id	
																bgid = SourGid,                               %% 联盟氏族的Id	
																bname = SourName,                             %% 联盟氏族的名字	
																brealm = SourRealm                            %% 联盟的氏族的部落Id	
															   },
											ets_update_alliance(Alliance1),
											ets_update_alliance(Alliance2),
											%%通知在线的玩家联盟数据更新
											notice_guild_alliance(SourGid, DestGid),
											%%发邮件
											Param = {DestChName, SourName},
											send_alliance_mail(Param, agreee_apply),
											%%添加日志
											guild_alliance_log(deal, SourGid, SourName, DestGid, DestName, NowTime),
											%%后台添加联盟日志
											db_insert_alliance_log(SourGid, DestGid, SourName, DestName, 1, NowTime),
											MSG = io_lib:format("恭喜[<font color='#FEDB4F'>~s</font>]氏族和[<font color='#FEDB4F'>~s</font>]氏族强强联合，结为盟族并肩作战！", 
																[SourName, DestName]),
											spawn(fun()->lib_chat:broadcast_sys_msg(2, MSG)end),
											1
									end;
								_DH ->
									3
							end;
						_SH ->
							2
					end
			end
	end.
		
%% -----------------------------------------------------------------
%% 40091 拒绝氏族联盟申请
%% -----------------------------------------------------------------
refuse_alliance(PlayerId, SourGid, DestGid) ->
	SourGuild = lib_guild_inner:get_guild(SourGid),
	if
		is_record(SourGuild, ets_guild) =:= false ->
			0;
		true ->
			#ets_guild{chief_id = SourChId} = SourGuild,
			if
				SourChId =/= PlayerId ->
					3;
				true ->
					case ets_get_gid_apply(DestGid, SourGid) of
						[] ->
							1;
						Applies when is_list(Applies)->
							%%删除数据库
							WhereList = [{bgid, SourGid}, {agid, DestGid}],
							db_delete_alliance(guild_alliance_apply, WhereList),
							Pattern = #ets_g_alliance_apply{bgid = SourGid, agid = DestGid, _ = '_'},
							ets_delete_alliance(?GUILD_ALLIANCE_APPLY, Pattern),
							1;
						_Other ->
							0
					end
			end
	end.					
%% -----------------------------------------------------------------
%% 40092 中止氏族联盟关系
%% -----------------------------------------------------------------
stop_alliance(PlayerId, SourGid, DestGid) ->
	SourGuild = lib_guild_inner:get_guild(SourGid),
	DestGuild = lib_guild_inner:get_guild(DestGid),
	if
		is_record(SourGuild, ets_guild) =:= false orelse is_record(DestGuild, ets_guild) =:= false ->
			0;
		true ->
			#ets_guild{chief_id = SourChiefId,
					   name = SourName} = SourGuild,
			#ets_guild{chief_name = DestChName,
					   name = DestName} = DestGuild,
			if
				SourChiefId =/= PlayerId ->%%只有氏族长才能执行终端联盟
					3;
				true ->
					case ets_get_gid_alliance(SourGid, DestGid) of
						[] ->
							5;
						S when is_list(S)->
							case ets_get_gid_alliance(DestGid, SourGid) of
								[] ->
									5;
								D when is_list(D)->
									%%删除数据库
									WhereList1 = [{gid, SourGid}, {bgid, DestGid}],
									WhereList2 = [{gid, DestGid}, {bgid, SourGid}],
									erlang:spawn(fun() ->
														 db_delete_alliance(guild_alliance, WhereList1),
														 db_delete_alliance(guild_alliance, WhereList2)
												 										 end),
									%%删除ets
									Pattern1 = #ets_g_alliance{gid = SourGid, bgid = DestGid, _ = '_'},
									Pattern2 = #ets_g_alliance{gid = DestGid, bgid = SourGid, _ = '_'},
									ets_delete_alliance(?GUILD_ALLIANCE, Pattern1),
									ets_delete_alliance(?GUILD_ALLIANCE, Pattern2),
									%%通知在线的玩家联盟数据更新
									notice_guild_alliance(SourGid, DestGid),
									%%发邮件
									Param = {DestChName, SourName},
									send_alliance_mail(Param, stop_alliance),
									%%更新 中止的时间
									%%修改数据库
									NowTime = util:unixtime(),
									ValueList = [{del_alliance, NowTime}],
									WhereList = [{id, SourGid}],
									db_agent:db_update_guild_alliance(ValueList, WhereList),
									%%改ets
									NSourGuild = SourGuild#ets_guild{del_alliance = NowTime},
									lib_guild_inner:update_guild(NSourGuild),
									%%添加日志
									guild_alliance_log(stop, SourGid, SourName, DestGid, DestName, NowTime),
									%%后台添加联盟日志
									db_insert_alliance_log(SourGid, DestGid, SourName, DestName, 0, NowTime),
									1;
								_DOther ->
									0
							end;
						_SOther ->
							0
					end
			end
	end.
			
			
%%获取联盟的氏族Id	
get_guild_alliance(GuildId) ->
	Reslut = ets_get_alliance(GuildId),
	lists:map(fun(Elem) ->
					  Elem#ets_g_alliance.bgid
			  end, Reslut).

ets_update_alliance(EAlliance) ->
	ets:insert(?GUILD_ALLIANCE, EAlliance).
ets_update_alliance_apply(EAApply) ->
	ets:insert(?GUILD_ALLIANCE_APPLY, EAApply).
ets_get_realm_apply(Gid, Realm) ->
	Pattern = #ets_g_alliance_apply{agid = Gid, brealm = Realm, _ = '_'},
	ets:match_object(?GUILD_ALLIANCE_APPLY, Pattern).
ets_get_realm_alliance(Gid, Realm) ->
	Pattern = #ets_g_alliance{gid = Gid, brealm = Realm, _ = '_'},
	ets:match_object(?GUILD_ALLIANCE, Pattern).
ets_get_alliance(GuildId) ->
	Pattern = #ets_g_alliance{gid = GuildId, _ = '_'},
	ets:match_object(?GUILD_ALLIANCE, Pattern).
ets_get_gid_apply(SourGid, DestGid) ->
	Pattern = #ets_g_alliance_apply{agid = SourGid, bgid = DestGid, _ = '_'},
	ets:match_object(?GUILD_ALLIANCE_APPLY, Pattern).
ets_get_gid_alliance(SourGid, DestGid) ->
	Pattern = #ets_g_alliance{gid = SourGid, bgid = DestGid, _ = '_'},
	ets:match_object(?GUILD_ALLIANCE, Pattern).
ets_get_send_gid_apply(SourGid) ->
	Pattern = #ets_g_alliance_apply{agid = SourGid, _ = '_'},
	ets:match_object(?GUILD_ALLIANCE_APPLY, Pattern).
ets_get_receive_gid_apply(DestGid) ->
	Pattern = #ets_g_alliance_apply{bgid = DestGid, _ = '_'},
	ets:match_object(?GUILD_ALLIANCE_APPLY, Pattern).
ets_delete_alliance(EtsTable, Pattern) ->
	ets:match_delete(EtsTable, Pattern).
ets_delete_id_alliance(EtsTable, Key) ->
	ets:delete(EtsTable, Key).
			
ets_select_delete_apply(SourGid, SourRealm, DestGid, DestRealm) ->
	Ms = ets:fun2ms(fun(M) when M#ets_g_alliance_apply.bgid =:= SourGid 
						 orelse M#ets_g_alliance_apply.bgid =:= DestGid
						 orelse (M#ets_g_alliance_apply.agid =:= DestGid andalso M#ets_g_alliance_apply.brealm =:= SourRealm)
						 orelse (M#ets_g_alliance_apply.agid =:= SourGid andalso M#ets_g_alliance_apply.brealm =:= DestRealm) ->
							true
					end),
	ets:select_delete(?GUILD_ALLIANCE_APPLY, Ms).

ets_select_delete_alliance(SourGid) ->
	Ms = ets:fun2ms(fun(M) when M#ets_g_alliance.gid =:= SourGid
						 orelse M#ets_g_alliance.bgid =:= SourGid ->
							true
					end),
	ets:select_delete(?GUILD_ALLIANCE, Ms).
	

db_delete_alliance(Table, WhereList) ->
	db_agent:delete_alliance(Table, WhereList).
db_update_alliance(Table, ValueList, WhereList) ->
	db_agent:db_update_alliance(Table, ValueList, WhereList).

%%查询发起的联盟申请和收到的联盟申请
get_alliances_list(GuildId) ->
	Sour = ets_get_send_gid_apply(GuildId),
	Dest = ets_get_receive_gid_apply(GuildId),
%% 	?DEBUG("Sour:~p, Dest:~p", [Sour, Dest]),
	{Sour, Dest}.

%%获取当前氏族的联盟氏族信息
get_guild_alliances(GuildId) ->
	Alliances = ets_get_alliance(GuildId),
	case length(Alliances) > 2 of
		true ->
			[One|RTwo] = Alliances,
			[Two|_R] = RTwo,
			[{One#ets_g_alliance.brealm, One#ets_g_alliance.bgid, One#ets_g_alliance.bname},
			 {Two#ets_g_alliance.brealm, Two#ets_g_alliance.bgid, Two#ets_g_alliance.bname}];
		false ->
			lists:map(fun(Elem) ->
							  {Elem#ets_g_alliance.brealm, Elem#ets_g_alliance.bgid, Elem#ets_g_alliance.bname}
					  end, Alliances)
	end.

%%氏族升级修改氏族联盟数据
upgrade_guild_alliance(GuildId,NewLevel) ->
	SAlliances = ets_get_send_gid_apply(GuildId),
	RAlliances = ets_get_receive_gid_apply(GuildId),
	lists:foreach(fun(SElem) ->
						  %%改数据库
						  SWhereList = [{id, SElem#ets_g_alliance_apply.id}],
						  SValueList = [{alv, NewLevel}],
						  db_update_alliance(guild_alliance_apply, SValueList, SWhereList),
						  %%改ets
						  NewSElem = SElem#ets_g_alliance_apply{alv = NewLevel},
						  ets_update_alliance_apply(NewSElem)
				  end, SAlliances),
	lists:foreach(fun(RElem) ->
						  %%改数据库
						  RWhereList = [{id, RElem#ets_g_alliance_apply.id}],
						  RValueList = [{blv, NewLevel}],
						  db_update_alliance(guild_alliance_apply, RValueList, RWhereList),
						  %%改ets
						  NewRElem = RElem#ets_g_alliance_apply{blv = NewLevel},
						  ets_update_alliance_apply(NewRElem)
				  end, RAlliances).
	
%%氏族成员变化修改氏族联盟数据
upmem_guild_alliance(GuildId,Mem,MLimit) ->
	SAlliances = ets_get_send_gid_apply(GuildId),
	RAlliances = ets_get_receive_gid_apply(GuildId),
	MemData = [Mem,MLimit],
	MemDataStr = util:term_to_string(MemData),
	lists:foreach(fun(SElem) ->
						  %%改数据库
						  SWhereList = [{id, SElem#ets_g_alliance_apply.id}],
						  SValueList = [{amem, MemDataStr}],
						  db_update_alliance(guild_alliance_apply, SValueList, SWhereList),
						  %%改ets
						  NewSElem = SElem#ets_g_alliance_apply{amem = MemData},
						  ets_update_alliance_apply(NewSElem)
				  end, SAlliances),
	lists:foreach(fun(RElem) ->
						  %%改数据库
						  RWhereList = [{id, RElem#ets_g_alliance_apply.id}],
						  RValueList = [{bmem, MemDataStr}],
						  db_update_alliance(guild_alliance_apply, RValueList, RWhereList),
						  %%改ets
						  NewRElem = RElem#ets_g_alliance_apply{bmem = MemData},
						  ets_update_alliance_apply(NewRElem)
				  end, RAlliances).
%%禅让族长修改氏族联盟数据
demise_guild_alliance(GuildId, CId, CName) ->
	SAlliances = ets_get_send_gid_apply(GuildId),
	RAlliances = ets_get_receive_gid_apply(GuildId),
	lists:foreach(fun(SElem) ->
						  %%改数据库
						  SWhereList = [{id, SElem#ets_g_alliance_apply.id}],
						  SValueList = [{acid, CId}, {acname, CName}],
						  db_update_alliance(guild_alliance_apply, SValueList, SWhereList),
						  %%改ets
						  NewSElem = SElem#ets_g_alliance_apply{acid = CId,
																acname = CName},
						  ets_update_alliance_apply(NewSElem)
				  end, SAlliances),
	lists:foreach(fun(RElem) ->
						  %%改数据库
						  RWhereList = [{id, RElem#ets_g_alliance_apply.id}],
						  RValueList = [{bcid, GuildId}, {bcname, CName}],
						  db_update_alliance(guild_alliance_apply, RValueList, RWhereList),
						  %%改ets
						  NewRElem = RElem#ets_g_alliance_apply{bcid = CId,
																bcname = CName},
						  ets_update_alliance_apply(NewRElem)
				  end, RAlliances).

%%处理被吞并的氏族的联盟数据
delete_update_alliance(TarGId, PGId) ->
	Alliances = ets_get_alliance(TarGId),
	%%删除数据库
	erlang:spawn(fun() ->
						 WhereList1 = [{gid, TarGId}],
						 WhereList2 = [{bgid, TarGId}],
						 db_agent:delete_alliance(guild_alliance, WhereList1),
						 db_agent:delete_alliance(guild_alliance, WhereList2)
				 end),
	%%删除ets
	ets_select_delete_alliance(TarGId),
	lists:foreach(fun(Elem) ->
						  case Elem#ets_g_alliance.bgid =:= PGId of
							  true ->%%跟当前氏族有联盟关系的，不用通知了
								  skip;
							  false ->
								  SourAlliance = ets_get_alliance(Elem#ets_g_alliance.bgid),
								  send_member_alliances(Elem#ets_g_alliance.bgid, SourAlliance)
						  end
				  end, Alliances).

%%处理被解散的氏族的联盟数据						  
disband_guild_alliance(GuildId) ->
	%%删除数据库
	erlang:spawn(fun() ->
						 WhereList1 = [{gid, GuildId}],
						 WhereList2 = [{bgid, GuildId}],
						 db_agent:delete_alliance(guild_alliance, WhereList1),
						 db_agent:delete_alliance(guild_alliance, WhereList2)
				 end),
	%%删除ets
	ets_select_delete_alliance(GuildId).

%%
%% Local Functions
%%
send_alliance_mail(Param, Type) ->
	case Type of
		alliance_apply ->%%申请发邮件
			{ChiefName, GuildName} = Param,
			NameList = [tool:to_list(ChiefName)],
			Title = "氏族联盟申请",
			Content = io_lib:format("[~s]氏族向您的氏族提出了联盟申请，请前往确认。", [GuildName]),
			mod_mail:send_sys_mail(NameList, Title, Content, 0, 0, 0, 0, 0);
		agreee_apply ->
			{ChiefName, GuildName} = Param,
			NameList = [tool:to_list(ChiefName)],
			Title = "氏族联盟成功",
			Content = io_lib:format("恭喜，[~s]氏族同意了您的氏族联盟申请，齐心协力，并肩作战，请前往确认。", [GuildName]),
			mod_mail:send_sys_mail(NameList, Title, Content, 0, 0, 0, 0, 0);
		stop_alliance ->
			{ChiefName, GuildName} = Param,
			NameList = [tool:to_list(ChiefName)],
			Title = "氏族联盟取消",
			Content = io_lib:format("[~s]氏族与您所在的氏族取消了联盟关系，请前往确认。", [GuildName]),
			mod_mail:send_sys_mail(NameList, Title, Content, 0, 0, 0, 0, 0);
		_ ->
			skip
	end.

notice_guild_alliance(SourGid, DestGid) ->
	SourAlliance = ets_get_alliance(SourGid),
	DestAlliance = ets_get_alliance(DestGid),
	erlang:send_after(1000, self(), {'UPDATE_GUILD_ALLIANCES', SourGid, SourAlliance, DestGid, DestAlliance}).

send_member_alliances(GuildId, Alliances) ->
	{AlliancesId, SendInfo} = 
		case length(Alliances) > 2 of
			true ->
				[One|RTwo] = Alliances,
				[Two|_R] = RTwo,
				{[One#ets_g_alliance.bgid,Two#ets_g_alliance.bgid],
				 [{One#ets_g_alliance.brealm, One#ets_g_alliance.bgid, One#ets_g_alliance.bname},
				  {Two#ets_g_alliance.brealm, Two#ets_g_alliance.bgid, Two#ets_g_alliance.bname}]};
			false ->
				lists:foldl(fun(Elem, AccIn) ->
									{EA, EL} = AccIn,
									{[Elem#ets_g_alliance.bgid|EA],
									 [{Elem#ets_g_alliance.brealm, Elem#ets_g_alliance.bgid, Elem#ets_g_alliance.bname}|EL]}
							end, {[], []}, Alliances)
		end,
	case lib_guild_inner:get_guild_member_by_guild_id(GuildId) of
		[] ->
			no_action;
		MemberList ->
			F = fun(Mem) -> 
						case lib_player:get_player_pid(Mem#ets_guild_member.player_id) of
							[] -> skip;	
							Pid when is_pid(Pid) -> gen_server:cast(Pid, {'UPDATE_ALLIANCE_IDS', AlliancesId, SendInfo});
							_ -> skip
						end
				end,
			[F(Member) || Member <- MemberList]
	end.
			
guild_alliance_log(Type, SourGid, SourGName, DestGid, DestGName, Time) ->
	case Type of
		deal ->
			Control = "结成";
		stop ->
			Control = "取消"
	end,
	SourConTent = io_lib:format("本氏族已与[~s]氏族~s联盟关系.", [DestGName, Control]),
	DestConTent = io_lib:format("本氏族已与[~s]氏族~s联盟关系.", [SourGName, Control]),
	SourLog = #ets_log_guild{guild_id = SourGid,
							 guild_name = SourGName, 
							 time = Time, 
							 content	= SourConTent},
	DestLog = #ets_log_guild{guild_id = DestGid,
							 guild_name = DestGName, 
							 time = Time, 
							 content	= DestConTent},
	{_S, SourId} = db_agent:guild_log_insert(SourLog),
	{_S, DestId} = db_agent:guild_log_insert(DestLog),
	SourLogEts = SourLog#ets_log_guild{id = SourId},
	DestLogEts = DestLog#ets_log_guild{id = DestId},
	lib_guild_inner:update_guild_log(SourLogEts),
	lib_guild_inner:update_guild_log(DestLogEts).

	
%%后台添加联盟日志
db_insert_alliance_log(SourGid, DestGid, SourName, DestName, Type, NowTime) ->
	erlang:spawn(fun() -> db_agent:insert_alliance_log(SourGid, DestGid, SourName, DestName, Type, NowTime) end).

