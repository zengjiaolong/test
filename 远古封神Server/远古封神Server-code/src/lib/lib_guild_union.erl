%% Author: xianrongMai
%% Created: 2011-9-14
%% Description: 氏族 结盟/归附 逻辑处理
-module(lib_guild_union).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%%
%% Exported Functions
%%
-export([submit_union_members/5,		%% 40064  兼并/依附氏族族长提交成员列表
		 get_union_info/1,				%% 40061  氏族联合请求(返回40063或者40062)
		 agree_union_apply/5,			%% 40060  同意氏族兼并/归附申请
		 refuse_unioin_apply/4,			%% 40059  拒绝氏族兼并/归附申请
		 cancel_union_apply/4,			%% 40058  取消氏族兼并/归附申请
		 union_apply/5,					%% 40057  氏族兼并/归附申请
		 update_guild_info/2,			%%更新由于氏族信息更新 而引起 结盟/归附相关更新 的数据(警告：以下的方法不能在外调用！)
		 upgrade_guild/1,
		 upmem_guild/1,
		 demise_guild/1,
		 disband_guild/1,
		 skip_other/1,
		 cast_union_player_change/7,	%%玩家进程处理氏族联盟数据
		 handle_union_timeout/1,		%%过期的氏族联盟处理
		 ets_delete_union_object/1,		%%ets的操作
		 ets_delete_union_id/1,
		 ets_update_union/1,
		 ets_select_union/2,
		 db_update_union/2,				%%氏族结盟/归附的数据库操作
		 db_delete_union/1,
		 db_insert_union/1,
		 load_all_guild_union/0			%%加载所有的氏族结盟/归附数据
		]).

%%
%% API Functions
%%
%%加载所有的氏族结盟/归附数据
load_all_guild_union() ->
	Unions = db_agent:load_all_guild_union(),
%% 	io:format("load_all_guild_union:~p~n", [Unions]),
	lists:foreach(fun handle_each_union/1, Unions).

handle_each_union(Elem) ->
	[Id, Agid, Bgid, AGName, BGName, ACId, BCId, ACName, BCName, ALv, BLv, AMem, BMem, Type, Apt, Union] = Elem,
	GUnion = #guild_union{id = Id,                                    				%% 自增Id	
						  agid = Agid,                               				%% A氏族Id	
						  bgid = Bgid,                               				%% B氏族Id	
						  agname = AGName,                            				%% A氏族名称	
						  bgname = BGName,                            				%% B氏族名称	
						  acid = ACId,                           					%% A氏族族长ID	
						  bcid = BCId,                               				%% B氏族族长ID	
						  acname = ACName,                            				%% A氏族族长名称	
						  bcname = BCName,                          				%% B氏族族长名称	
						  alv = ALv,                               					%% A氏族等级	
						  blv = BLv,                               					%% B氏族等级	
						  amem = util:string_to_term(tool:to_list(AMem)),           %% A氏族成员情况[当前人口数，人口最大容量]	
						  bmem = util:string_to_term(tool:to_list(BMem)),           %% B氏族成员情况[当前人口数，人口最大容量]	
						  type = Type,                               				%% 申请类型	
						  apt = Apt,                               					%% 申请时间	
						  unions = Union                               				%% 当前结盟或归附的状态，0：申请中；1，2，3，4：流程中	
						 },
	ets_update_union(GUnion).

%%更新由于氏族信息更新 而引起 结盟/归附相关更新 的数据
update_guild_info(Type, Param) ->
	{Module, Method} = 
		case Type of
			upgrade ->%%氏族升级
				{lib_guild_union, upgrade_guild};
			upmem ->%%氏族成员变化
				{lib_guild_union, upmem_guild};
			demise_guild ->%%禅让族长
				{lib_guild_union, demise_guild};
			disband_guild ->%%氏族解散
				{lib_guild_union, disband_guild};
			_ ->
				{lib_guild_union, skip_other}
		end,
%% 	?DEBUG("update guiild info Module: ~p, Method: ~p, Type: ~p, Param: ~p", [Module, Method, Type, Param]),
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
						{apply_cast, Module, Method, [Param]}).

%%过期的氏族联盟处理
handle_union_timeout(NowTime) ->
	Ms = ets:fun2ms(fun(Union) when (NowTime - Union#guild_union.apt) > ?ONE_DAY_SECONDS ->
%% 	Ms = ets:fun2ms(fun(Union) when (NowTime - Union#guild_union.apt) > 100 ->%%测试用
							Union
					end),
	PUnions = ets:select(?GUILD_UNION, Ms),
	lists:foreach(fun(Elem) ->
%%						  ?DEBUG("time out union: ~p, ~p", [NowTime, Elem#guild_union.apt]),
						  #guild_union{id = EUnionId,
									   agid = AGId,
									   bgid = BGId,
									   agname = AGName,
									   bgname = BGName,
									   type = Type,
									   unions = UnionSTate,
									   acname = ACName,
									   bcname = BCName} = Elem,
						  %%传输ets
						  ets_delete_union_id(EUnionId),
						  %%删除数据库
						  EWhereList = [{id, EUnionId}],
						  db_delete_union(EWhereList),
						  case UnionSTate of
							  0 ->
								  %%邮件通知
								  lib_guild:send_guild_mail(union_timeout, [BGName, Type, ACName]);
							  1 ->
								  %%吞并方已经接受了，需要修改氏族的信息
								  %%获取氏族
								  PGuild = lib_guild_inner:get_guild(AGId),
								  TarGuild = lib_guild_inner:get_guild(BGId),
								  case is_record(PGuild, ets_guild) of
									  true ->
										  NPGuild = PGuild#ets_guild{unions = 0,
																	 union_gid = 0,
																	 union_id = 0,
																	 targid = 0},
										  PValueList = [{unions, 0},{union_id, 0}, {union_gid, 0}, {targid, 0}],
										  PWhereList = [{id, NPGuild#ets_guild.id}],
										  %%修改ets
										  lib_guild_inner:update_guild(NPGuild),
										  %%修改数据库
										  db_update_guild_union(PValueList, PWhereList);
									  false ->
										  skip
								  end,
								  case is_record(TarGuild, ets_guild) of
									  true ->
										  NTarGuild = TarGuild#ets_guild{unions = 0,
																		 union_gid = 0,
																		 union_id = 0,
																		 targid = 0},
										  TarValueList = [{unions, 0},{union_id, 0}, {union_gid, 0}, {targid, 0}],
										  TarWhereList = [{id, NTarGuild#ets_guild.id}],
										  %%修改ets
										  lib_guild_inner:update_guild(NTarGuild),
										  %%修改数据库
										  db_update_guild_union(TarValueList, TarWhereList);
									  false ->
										  skip
								  end,
								  %%邮件通知
								  lib_guild:send_guild_mail(union_timeout, [BGName, 3, ACName]),
								  lib_guild:send_guild_mail(union_timeout, [AGName, 3, BCName]);
							  2 ->%%已经在合并流程了
								  %%获取氏族
								  PGuild = lib_guild_inner:get_guild(AGId),
								  TarGuild = lib_guild_inner:get_guild(BGId),
								  case Type of
									  1 ->%%兼并
										AGuild = PGuild,
										BGuild = TarGuild;
									  2 ->
										  AGuild = TarGuild,
										  BGuild = PGuild
								  end,
								  case is_record(AGuild, ets_guild) of%%吞并方
									  true ->
										  %%修改氏族相关
										  NAGuild = AGuild#ets_guild{unions = 0,
																	 union_id = 0,
																	 union_gid = 0,
																	 targid = 0},
										  AValueList = [{unions, 0},{union_id, 0}, {union_gid, 0}, {targid, 0}],
										  AWhereList = [{id, NAGuild#ets_guild.id}],
										  %%修改ets
										  lib_guild_inner:update_guild(NAGuild),
										  %%修改数据库
										  db_update_guild_union(AValueList, AWhereList);
									  false ->%%没有氏族，没办法了，不做数据回滚
										  skip
								  end,
								  case is_record(BGuild, ets_guild) of
									  true ->%%被吞并的那一方，需要顺便修改成员的数据
										  %%获取被吞并的那一方的被勾选的成员
										  Members = lib_guild_inner:get_union_guild_member(BGuild#ets_guild.id),
										  %%更新ets的数据
										  lists:foreach(fun(MElem) ->
																NMElem = MElem#ets_guild_member{unions = 0},
																lib_guild_inner:update_guild_member(NMElem)
														end, Members),
										  %%改数据库数据
										  BValueList = [{unins, 0}],
										  BWhereList = [{guild_id, BGuild#ets_guild.id}],
										  db_update_member_union(BValueList, BWhereList),
										  %%修改氏族相关
										  NBGuild = BGuild#ets_guild{unions = 0,
																	 union_id = 0,
																	 union_gid = 0,
																	 targid = 0},
										  PValueList = [{unions, 0},{union_id, 0}, {union_gid, 0}, {targid, 0}],
										  PWhereList = [{id, NBGuild#ets_guild.id}],
										  %%修改ets
										  lib_guild_inner:update_guild(NBGuild),
										  %%修改数据库
										  db_update_guild_union(PValueList, PWhereList);
									  false ->
										  skip
								  end,
								  %%邮件通知
								  lib_guild:send_guild_mail(union_timeout, [BGName, 3, ACName]),
								  lib_guild:send_guild_mail(union_timeout, [AGName, 3, BCName])
						  end
				  end, PUnions).
	  
%%ets的操作
ets_update_union(GUnion) ->
	ets:insert(?GUILD_UNION, GUnion).
ets_delete_union_id(UnionId) ->
	ets:delete(?GUILD_UNION, UnionId).
ets_delete_union_object(Union) ->
	ets:delete_object(?GUILD_UNION, Union).
ets_lookup_union(Id) ->
	ets:lookup(?GUILD_UNION, Id).
ets_select_union(Type, GId) ->
	Ms =
		case Type of
			a ->%%找A氏族的
				ets:fun2ms(fun(Union) when Union#guild_union.agid =:= GId ->
								   Union
						   end);
			b ->%%找B氏族的
				ets:fun2ms(fun(Union) when Union#guild_union.bgid =:= GId ->
								   Union
						   end)
		end,
	ets:select(?GUILD_UNION, Ms).
ets_find_unioin(AGId, BGId) ->
	Ms = 
		ets:fun2ms(fun(Union) when Union#guild_union.agid =:= AGId andalso Union#guild_union.bgid =:= BGId->
						   Union
				   end),
	ets:select(?GUILD_UNION, Ms).
ets_find_unioin(AGId, BGId, Type) ->
	Ms = 
		ets:fun2ms(fun(Union) when Union#guild_union.agid =:= AGId andalso Union#guild_union.bgid =:= BGId
						andalso Union#guild_union.type =:= Type ->
						   Union
				   end),
	ets:select(?GUILD_UNION, Ms).

%%db的操作
db_delete_union(WhereList) ->
	db_agent:db_delete_union(guild_union, WhereList).
db_insert_union(GUnion) ->
	db_agent:db_insert_union(GUnion).
db_update_union(ValueList, WhereList) ->
	db_agent:db_update_union(guild_union, ValueList, WhereList).
db_update_guild_union(ValueList, WhereList) ->
	db_agent:db_update_union(guild, ValueList, WhereList).
db_update_member_union(ValueList, WhereList) ->
	db_agent:db_update_union(guild_member, ValueList, WhereList).
db_delete_member_union(WhereList) ->
	db_agent:db_delete_union(guild_member, WhereList).

%% =========================================================================================================
%% ===========================================	协议操作 	====================================================
%% =========================================================================================================

%% -----------------------------------------------------------------
%% 40057  氏族兼并/归附申请
%% -----------------------------------------------------------------
union_apply(PId, PGId, PPost, TarGId, Type) ->
%% 	?DEBUG("union_apply  PId:~p, PGId:~p, PPost:~p, TarGId:~p, Type:~p",[PId, PGId, PPost, TarGId, Type]),
	PGuild = lib_guild_inner:get_guild(PGId),
	TarGuild = lib_guild_inner:get_guild(TarGId),
	Unions = ets_find_unioin(PGId,TarGId),
	if
		is_record(PGuild, ets_guild) =:= false orelse is_record(TarGuild, ets_guild) =:= false ->%%没有这个氏族
			0;
		PGuild#ets_guild.id =:= TarGuild#ets_guild.id ->%%不能是自己氏族
			9;
		Type =:= 1 andalso PGuild#ets_guild.level < TarGuild#ets_guild.level -> %%对方氏族等级比你所在氏族等级高，不能申请兼并
			10;
		Type =:= 2 andalso PGuild#ets_guild.level > TarGuild#ets_guild.level -> %%对方氏族等级比你所在氏族等级低，不能申请归附
			11;
		PGuild#ets_guild.chief_id =/= PId orelse PPost =/= 1 ->%%不是族长
			4;
		PGuild#ets_guild.unions =/= 0 ->%%你所在氏族正在进行兼并/依附流程
			5;
		TarGuild#ets_guild.unions =/= 0 ->%%对方氏族正在进行兼并/依附流程
			2;
		PGuild#ets_guild.realm =/= TarGuild#ets_guild.realm -> %%不同部落
			8;
		length(Unions) =/= 0 ->
			3;
		true ->%%可以啦	
			%%计算氏族人数上限
			APLv = lib_guild:get_guild_skill_level(PGuild#ets_guild.id, 3),
			AMLimit = data_guild:get_guild_config(guild_member_base,[]) + APLv * 5,
			BPLv = lib_guild:get_guild_skill_level(TarGuild#ets_guild.id, 3),
			BMLimit = data_guild:get_guild_config(guild_member_base,[]) + BPLv * 5,
			case Type of%%人口是否合法判断
				1 when AMLimit =< PGuild#ets_guild.member_num ->%%兼并
					6;
				2 when BMLimit =< TarGuild#ets_guild.member_num ->%%归附
					7;
				_ ->
					APT = util:unixtime(),
					NewUnions = 
						#guild_union{agid = PGuild#ets_guild.id,                               				%% A氏族Id	
									 bgid = TarGuild#ets_guild.id,                               			%% B氏族Id	
									 agname = PGuild#ets_guild.name,                            			%% A氏族名称	
									 bgname = TarGuild#ets_guild.name,                            			%% B氏族名称	
									 acid = PGuild#ets_guild.chief_id,                           			%% A氏族族长ID	
									 bcid = TarGuild#ets_guild.chief_id,                               		%% B氏族族长ID	
									 acname = PGuild#ets_guild.chief_name,                            		%% A氏族族长名称	
									 bcname = TarGuild#ets_guild.chief_name,                          		%% B氏族族长名称	
									 alv = PGuild#ets_guild.level,                               			%% A氏族等级	
									 blv = TarGuild#ets_guild.level,                               			%% B氏族等级	
									 amem = [PGuild#ets_guild.member_num,AMLimit],            				%% A氏族成员情况[当前人口数，人口最大容量]	
									 bmem = [TarGuild#ets_guild.member_num,BMLimit],         				%% B氏族成员情况[当前人口数，人口最大容量]	
									 type = Type,                               							%% 申请类型	
									 apt = APT,                               								%% 申请时间	
									 unions = 0                               								%% 当前结盟或归附的状态，0：申请中；1，2，3，4：流程中	
									},
					{_, Id} = db_insert_union(NewUnions),%%更新数据库
					GUnions = NewUnions#guild_union{id = Id},%%赋予新的ID
					ets_update_union(GUnions),%%更新ets
					1
			end
	end.
	
%% -----------------------------------------------------------------
%% 40058  取消氏族兼并/归附申请
%% -----------------------------------------------------------------
cancel_union_apply(PId, PGId, PPost, TarGId) ->
%% 	?DEBUG("PId:~p, PGId:~p, PPost:~p, TarGId:~p", [PId, PGId, PPost, TarGId]),
	PGuild = lib_guild_inner:get_guild(PGId),
	TarGuild = lib_guild_inner:get_guild(TarGId),
	Unions = ets_find_unioin(PGId,TarGId),
	if
		is_record(PGuild, ets_guild) =:= false orelse is_record(TarGuild, ets_guild) =:= false ->%%没有这个氏族
			0;
		PGuild#ets_guild.chief_id =/= PId orelse PPost =/= 1 ->%%不是族长
			2;
		length(Unions) =:= 0 ->
			3;
		true ->%%可以啦
			UnionIds =  
				lists:map(fun(Union) ->
								  %%删除ets
								  ets_delete_union_id(Union#guild_union.id),
								  %%删除数据库所用的ID
								  Union#guild_union.id
						  end,Unions),
			%%删除数据库数据
			WhereList = [{id, "in", UnionIds}],
			db_delete_union(WhereList),
			1
	end.

%% -----------------------------------------------------------------
%% 40059  拒绝氏族兼并/归附申请
%% -----------------------------------------------------------------
refuse_unioin_apply(PId, PGId, PPost, TarGId) ->
%% 	?DEBUG("PId:~p, PGId:~p, PPost:~p, TarGId:~p", [PId, PGId, PPost, TarGId]),
	PGuild = lib_guild_inner:get_guild(PGId),
	TarGuild = lib_guild_inner:get_guild(TarGId),
	Unions = ets_find_unioin(TarGId,PGId),
	if
		is_record(PGuild, ets_guild) =:= false orelse is_record(TarGuild, ets_guild) =:= false ->%%没有这个氏族
			0;
		PGuild#ets_guild.chief_id =/= PId orelse PPost =/= 1 ->%%不是族长
			2;
		length(Unions) =:= 0 ->%%该申请已经没有了
			3;
		true ->
			UnionIds = 
				lists:map(fun(Union) ->
								  %%删除ets
								  ets_delete_union_id(Union#guild_union.id),
								  %%删除数据库所用的ID
								  Union#guild_union.id
						  end,Unions),
			%%删除数据库数据
			WhereList = [{id, "in", UnionIds}],
			db_delete_union(WhereList),
			[UnionOne|_] = Unions,
			%%邮件通知
			lib_guild:send_guild_mail(refuse_guild_union, [UnionOne#guild_union.type, UnionOne#guild_union.bgname, UnionOne#guild_union.acname]),
			1
	end.
	
%% -----------------------------------------------------------------
%% 40060  同意氏族兼并/归附申请
%% -----------------------------------------------------------------
agree_union_apply(PId, PGId, PPost, TarGId, Type) ->
	PGuild = lib_guild_inner:get_guild(PGId),
	TarGuild = lib_guild_inner:get_guild(TarGId),
	Unions = ets_find_unioin(TarGId,PGId, Type),
%% 	?DEBUG("00000000000", []),
	if
		is_record(PGuild, ets_guild) =:= false orelse is_record(TarGuild, ets_guild) =:= false ->%%没有这个氏族
			0;
		PGuild#ets_guild.chief_id =/= PId orelse PPost =/= 1 ->%%不是族长
			2;
		length(Unions) =:= 0 ->%%该申请已经没有了
			3;
		PGuild#ets_guild.realm =/= TarGuild#ets_guild.realm -> %%不同部落
			4;
		PGuild#ets_guild.id =:= TarGuild#ets_guild.id ->%%居然是自己氏族
			5;
		TarGuild#ets_guild.unions =/= 0 ->
			6;
		PGuild#ets_guild.unions =/= 0 ->
			0;
		true ->%%可以做了
			NowTime = util:unixtime(),
			[Union|Other] = Unions,
%% 			?DEBUG("111111", []),
			%%处理垃圾数据
			erlang:spawn(fun() ->
								 EIds = 
									 lists:map(
									   fun(Elem) ->
											   %%更新ets
											   ets_delete_union_id(Elem#guild_union.id),
											   %%更新数据库数据所要的ID
											   Elem#guild_union.id 
									   end, Other),
								 %%删除数据库数据
								 EWhereList = [{id, "in", EIds}],
								 db_delete_union(EWhereList)
						 end),
%% 			?DEBUG("222222", []),
			%更新ets
			NewUnion = Union#guild_union{unions = 1},
			ets_update_union(NewUnion),
			%%更新数据库数据
			WhereList = [{id, Union#guild_union.id}],
			ValueList = [{unions, 1}, {apt, NowTime}],
			db_update_union(ValueList, WhereList),
			%%修改氏族部分数据
			UnionGId = 
				case Union#guild_union.type of
					1 -> %%兼并
						PGuild#ets_guild.id;
					2 -> %%归附
						TarGuild#ets_guild.id
				end,
%% 			?DEBUG("333333", []),
			NPGuild = PGuild#ets_guild{unions = 1,
									   union_id = Union#guild_union.id,
									   union_gid = UnionGId,
									   targid = TarGuild#ets_guild.id},
			PValueList = [{unions, 1},{union_id, Union#guild_union.id}, {union_gid, UnionGId}, {targid, TarGuild#ets_guild.id}],
			PWhereList = [{id, NPGuild#ets_guild.id}],
			NTarGuild = TarGuild#ets_guild{unions = 1,
										   union_id = Union#guild_union.id,
										   union_gid = UnionGId,
										   targid = PGuild#ets_guild.id},
			TarValueList = [{unions, 1},{union_id, Union#guild_union.id}, {union_gid, UnionGId}, {targid, PGuild#ets_guild.id}],
			TarWhereList = [{id, NTarGuild#ets_guild.id}],
			%%修改ets
			lib_guild_inner:update_guild(NPGuild),
			lib_guild_inner:update_guild(NTarGuild),
			%%修改数据库
			db_update_guild_union(PValueList, PWhereList),
			db_update_guild_union(TarValueList, TarWhereList),
%% 			?DEBUG("444444444", []),
			%%邮件通知
			lib_guild:send_guild_mail(agree_guild_union, [Union#guild_union.type, Union#guild_union.bgname, Union#guild_union.acname]),
			1
	end.
						
%% -----------------------------------------------------------------
%% 40061  氏族联合请求(返回40063或者40062)
%% -----------------------------------------------------------------
get_union_info(PGId) ->
%% 	?DEBUG("1111111111111111111111111",[]),
	PGuild = lib_guild_inner:get_guild(PGId),
	if
		is_record(PGuild, ets_guild) =:= false ->%%没有这个氏族
			{1,{[],[], [],[]}};
		true ->
			#ets_guild{unions = UnionState,
					   union_gid = UnionGId,
					   union_id = UnionId,
					   targid = TarGId} = PGuild,
			case ets_lookup_union(UnionId) of
				[] ->%%已经删除了，开始还原氏族的数据
					case UnionState of
						0 ->%%没有在流程里，直接返回40062
							Type = 1,
							AList = ets_select_union(a, PGId),
							BList = ets_select_union(b, PGId),
%% 							?DEBUG("2222222222222222222222222222222222",[]),
							%%获取发出和收到的联盟的信息
							{SAllianceList, RAllianceList} = lib_guild_alliance:get_alliances_list(PGId),
							{Type,{AList, BList, SAllianceList, RAllianceList}};
						1 ->%%吞并方已经接受了，需要修改氏族的信息
							%%获取目标氏族
							TarGuild = lib_guild_inner:get_guild(TarGId),
							NPGuild = PGuild#ets_guild{unions = 0,
													   union_gid = 0,
													   union_id = 0,
													   targid = 0},
							PValueList = [{unions, 0},{union_id, 0}, {union_gid, 0}, {targid, 0}],
							PWhereList = [{id, NPGuild#ets_guild.id}],
							%%修改ets
							lib_guild_inner:update_guild(NPGuild),
							
							%%修改数据库
							db_update_guild_union(PValueList, PWhereList),
							case is_record(TarGuild, ets_guild) of
								true ->
									NTarGuild = TarGuild#ets_guild{unions = 0,
																   union_gid = 0,
																   union_id = 0,
																   targid = 0},
									TarValueList = [{unions, 0},{union_id, 0}, {union_gid, 0}, {targid, 0}],
									TarWhereList = [{id, NTarGuild#ets_guild.id}],
									%%修改ets
									lib_guild_inner:update_guild(NTarGuild),
									%%修改数据库
									db_update_guild_union(TarValueList, TarWhereList);
								false ->
									skip
							end,
							%%获取一批列表
							Type = 1,
							AList = ets_select_union(a, PGId),
							BList = ets_select_union(b, PGId),
							%%获取发出和收到的联盟的信息
							{SAllianceList, RAllianceList} = lib_guild_alliance:get_alliances_list(PGId),
							{Type, {AList, BList, SAllianceList, RAllianceList}};
						2 ->%%已经有提交人选了，不过过期而已
							%%获取被吞并的那一方的被勾选的成员
							Members = lib_guild_inner:get_union_guild_member(TarGId),
							%%更新ets的数据
							lists:foreach(fun(Elem) ->
												  NElem = Elem#ets_guild_member{unions = 0},
												  lib_guild_inner:update_guild_member(NElem)
										  end,Members),
							%%改数据库数据
							ValueList = [{unins, 0}],
							WhereList = [{guild_id, TarGId}],
							db_update_member_union(ValueList, WhereList),
							%%获取目标氏族
							TarGuild = lib_guild_inner:get_guild(TarGId),
							%%修改氏族相关
							NPGuild = PGuild#ets_guild{unions = 0,
													   union_id = 0,
													   union_gid = 0,
													   targid = 0},
							PValueList = [{unions, 0},{union_id, 0}, {union_gid, 0}, {targid, 0}],
							PWhereList = [{id, NPGuild#ets_guild.id}],
					
							%%修改ets
							lib_guild_inner:update_guild(NPGuild),
							
							%%修改数据库
							db_update_guild_union(PValueList, PWhereList),
							
							case is_record(TarGuild, ets_guild) of
								true ->
									NTarGuild = TarGuild#ets_guild{unions = 0,
																   union_id = 0,
																   union_gid = 0,
																   targid = 0},
									TarValueList = [{unions, 0},{union_id, 0}, {union_gid, 0}, {targid, 0}],
									TarWhereList = [{id, NTarGuild#ets_guild.id}],
									%%修改ets
									lib_guild_inner:update_guild(NTarGuild),
									%%修改数据库
									db_update_guild_union(TarValueList, TarWhereList);
								false ->
									skip
							end,
%% 							%%获取一批列表
							Type = 1,
							AList = ets_select_union(a, PGId),
							BList = ets_select_union(b, PGId),
							%%获取发出和收到的联盟的信息
							{SAllianceList, RAllianceList} = lib_guild_alliance:get_alliances_list(PGId),
							{Type, {AList, BList, SAllianceList, RAllianceList}}
					end;
				[Union] ->
					case UnionState of
						0 ->%%没有在流程里,返回40063
							Type = 1,
							AList = ets_select_union(a, PGId),
							BList = ets_select_union(b, PGId),
							%%获取发出和收到的联盟的信息
							{SAllianceList, RAllianceList} = lib_guild_alliance:get_alliances_list(PGId),
							{Type, {AList, BList, SAllianceList, RAllianceList}};
						_ ->%%在流程里了，返回40063
							%%确认兼并方/归附方
							
							UnionType = 
								case UnionGId =:= PGId of
									true ->
										2;
									false ->
										1
								end,
							#guild_union{agid = AGId,
										 bgid = BGId} = Union,
							%%获取目标氏族
							TarGuild = 
								case AGId =:= PGId of
									true ->
										lib_guild_inner:get_guild(BGId);
									false ->
										lib_guild_inner:get_guild(AGId)
								end,
							if
								is_record(TarGuild, ets_guild) =:= false ->
									{2,{UnionType,UnionState,0,[]}};
								true ->
									ReMNum = 
										case UnionType of
											1 ->%%兼并方
												%%计算氏族人数上限
												GLv = lib_guild:get_guild_skill_level(PGuild#ets_guild.id, 3),
												MLimit = data_guild:get_guild_config(guild_member_base,[]) + GLv * 5,
												abs(MLimit - PGuild#ets_guild.member_num);
											2 ->%%归附方
												%%计算氏族人数上限
												GLv = lib_guild:get_guild_skill_level(TarGuild#ets_guild.id, 3),
												MLimit = data_guild:get_guild_config(guild_member_base,[]) + GLv * 5,
												abs(MLimit - TarGuild#ets_guild.member_num)
										end,
									Members = 
										case UnionState of
											1 when UnionType =:= 1 ->%%兼并方
												[];
											1 when UnionType =:= 2 ->%%归附方，还未选人
												lib_guild_inner:get_guild_member_by_guild_id(UnionGId);
											2 when UnionType =:= 1 ->%%归附方已经选人了，在=待兼并方答应
												lib_guild_inner:get_union_guild_member(UnionGId);
											2 when UnionType =:= 2 ->%%归附方已经选人了，归附方不显示名单了
												[];
											_ ->%%有状况
												[]
										end,
									{2,{UnionType, UnionState, ReMNum, Members}}
							end
					end
			end
	end.
					

%% -----------------------------------------------------------------
%% 40064  兼并/依附氏族族长提交成员列表
%% -----------------------------------------------------------------
submit_union_members(PId, PGId, PPost, Handle, SubmitList) ->
	PGuild = lib_guild_inner:get_guild(PGId),
	BGId = PGuild#ets_guild.targid,
	%%获取目标氏族
	TarGuild = lib_guild_inner:get_guild(BGId),
%% 	TarGuild = lib_guild_inner:get_guild(TarGId),
%% 	Unions = ets_find_unioin(TarGId,PGId, Type),
	if
		is_record(PGuild, ets_guild) =:= false orelse is_record(TarGuild, ets_guild) =:= false ->%%没有这个氏族
			{0, 0, 0};
		PGuild#ets_guild.id =/= PGId ->%%不属于本氏族的
			{4, 0, 0};
		PPost =/= 1 orelse PGuild#ets_guild.chief_id =/= PId ->%%不是族长，没权限
			{5, 0, 0};
		true ->
			#ets_guild{union_id = UnionId} = PGuild,
			case ets_lookup_union(UnionId) of
				[] ->%%记录已经被删除了，取消掉了
					NPGuild = PGuild#ets_guild{unions = 0,
											   union_gid = 0,
											   union_id = 0,
											   targid = 0},
					PValueList = [{unions, 0},{union_id, 0}, {union_gid, 0}, {targid, 0}],
					PWhereList = [{id, NPGuild#ets_guild.id}],
					%%修改ets
					lib_guild_inner:update_guild(NPGuild),
					%%修改数据库
					db_update_guild_union(PValueList, PWhereList),
					NTarGuild = TarGuild#ets_guild{unions = 0,
												   union_gid = 0,
												   union_id = 0,
												   targid = 0},
					TarValueList = [{unions, 0},{union_id, 0}, {union_gid, 0}, {targid, 0}],
					TarWhereList = [{id, NTarGuild#ets_guild.id}],
					%%修改ets
					lib_guild_inner:update_guild(NTarGuild),
					%%修改数据库
					db_update_guild_union(TarValueList, TarWhereList),
					{2, 0, 0};
				[Union] ->
					#guild_union{id = UnionId} = Union,
					case Handle of
						3 ->%%吞并方拒绝加入确认
%% 							?DEBUG("refuse_submit_union", []),
							refuse_submit_union(UnionId,PGuild,TarGuild);
						2 ->%%吞并方同意加入确认
%% 							?DEBUG("agree_submit_union", []),
							agree_submit_union(Union,PGuild,TarGuild,SubmitList);
						1 ->%%被吞并方提交
%% 							?DEBUG("submit_union_panel", []),
							submit_union_panel(Union,PGuild,TarGuild,SubmitList)
					end
			end
	end.

%%吞并方拒绝加入确认					
refuse_submit_union(UnionId,PGuild,TarGuild) ->							
	#ets_guild{id = PGId,
			   union_gid = PUGId} = PGuild,
	#ets_guild{id = TarGId} = TarGuild,
%% 	?DEBUG("refuse_submit_union:~p,~p,~p", [PUGId, PGId, TarGId]),
	if
		PUGId =/= PGId andalso PUGId =/= TarGId ->
			{6, 0, 0};
		PUGId =/= TarGId ->
			{0, 0, 0};
		true ->
			%%获取被吞并的那一方的被勾选的成员
			Members = lib_guild_inner:get_union_guild_member(PUGId),
			%%更新ets的数据
			lists:foreach(fun(Elem) ->
								  NElem = Elem#ets_guild_member{unions = 0},
								  lib_guild_inner:update_guild_member(NElem)
						  end,Members),
			%%改数据库数据
			ValueList = [{unins, 0}],
			WhereList = [{guild_id, PUGId}],
			db_update_member_union(ValueList, WhereList),
			%%修改氏族相关
			NPGuild = PGuild#ets_guild{unions = 0,
									   union_id = 0,
									   union_gid = 0,
									   targid = 0},
			PValueList = [{unions, 0},{union_id, 0}, {union_gid, 0}, {targid, 0}],
			PWhereList = [{id, NPGuild#ets_guild.id}],
			NTarGuild = TarGuild#ets_guild{unions = 0,
										   union_id = 0,
										   union_gid = 0,
										   targid = 0},
			TarValueList = [{unions, 0},{union_id, 0}, {union_gid, 0}, {targid, 0}],
			TarWhereList = [{id, NTarGuild#ets_guild.id}],
			%%修改ets
			lib_guild_inner:update_guild(NPGuild),
			lib_guild_inner:update_guild(NTarGuild),
			%%修改数据库
			db_update_guild_union(PValueList, PWhereList),
			db_update_guild_union(TarValueList, TarWhereList),
			%%邮件通知
			lib_guild:send_guild_mail(refuse_chose_member, 
									  [PGuild#ets_guild.name, NTarGuild#ets_guild.chief_name]),
			%%删除申请条目
			UWhereList = [{id, UnionId}],
			ets_delete_union_id(UnionId),
			db_delete_union(UWhereList),
			{1, 0, 0}
	end.
	
%%吞并方同意加入确认
agree_submit_union(Union,PGuild,TarGuild,SubmitList) ->
	#guild_union{unions = UnionState} = Union,
	#ets_guild{id = PGId,
			   name = PGName,
			   union_gid = PUGId,
			   member_num = Mem} = PGuild,
	#ets_guild{id = TarGId,
			   name = TarGName,
			   chief_id = ChiefId,
			   chief_name = ChiefName} = TarGuild,
%% 	?DEBUG("agree_submit_union:~p,~p,~p, UnionState:~p", [PUGId, PGId, TarGId, UnionState]),
	if
		PUGId =:= PGId orelse TarGId =:= PGId ->%%居然是被吞并方?
			{8, 0, 0};
		PUGId =/= TarGId ->%%有状况
			{0, 0, 0};
		true ->
			%%计算氏族人数上限
			PGLv = lib_guild:get_guild_skill_level(PGuild#ets_guild.id, 3),
			PMLimit = data_guild:get_guild_config(guild_member_base,[]) + PGLv * 5,
			MRest = abs(PMLimit - Mem),
			%%判断族长是否在名单里面
			NSubmitList = 
						case lists:keyfind(ChiefId, 1, SubmitList) of
							false ->
								[{ChiefId, ChiefName}|SubmitList];
							_Tuple ->
								SubmitList
							
						end,
			LenSubmit = length(NSubmitList),
			if
				MRest < LenSubmit ->%%人数超了
					{7, MRest, LenSubmit};
				UnionState =/= 2 ->%%流程居然出问题了
					{0, 0, 0};
				true ->%%可以了吧
					%%解散氏族时，传出领地中的所有的成员
					mod_guild_manor:send_out_all_manor(TarGId),
					%%处理被吞并的氏族的联盟数据
					lib_guild_alliance:delete_update_alliance(TarGId, PGId),
					%%获取联盟的氏族Id	
					NewAId = lib_guild_alliance:get_guild_alliance(PGId),
					
					%%处理选中的成员
					DepartName = tool:to_binary(""),
					{_MemIds, MemNames} = 
						lists:foldl(fun({MemId, MemName}, AccIn) ->
%% 											?DEBUG("~p", [{MemId, MemName}]),
											case lib_guild_inner:get_guild_member_by_guildandplayer_id(PUGId, MemId) of
												[] ->
													AccIn;
												Member ->
%% 													?DEBUG("1111111111111111111111111111", []),
													{EMemIds, EMemNames} = AccIn,
													%%处理成员表
													NewMember = Member#ets_guild_member{unions = 0,
																						guild_id = PGId,
																						guild_name = PGName,
																						donate_funds = 0,
																						guild_position = 12,
																						guild_depart_name = DepartName,
																						guild_depart_id = 5},
%% 													?DEBUG("22222222222222222222222222222222222222", []),
													%%改ets
													lib_guild_inner:update_guild_member(NewMember),
													MValueList = [{unions, 0}, {guild_id, PGId}, {guild_name, PGName}, 
																 {donate_funds, 0}, {guild_depart_name, DepartName}, 
																 {guild_depart_id, 5}],
													MWhereList = [{player_id, MemId}],
													%%改数据库
													db_update_member_union(MValueList, MWhereList),
													%%处理玩家表
													union_player_change(1,MemId, PGId, PGName, DepartName, NewAId),
													case MemId =:= ChiefId of
														true ->
															AccIn;
														false ->
															{[MemId|EMemIds], [MemName|EMemNames]}
													end
											end
									end, {[],[]}, NSubmitList),
%% 					?DEBUG("666666666666666666666666666", []),
					%%邮件通知(通知被选中加入的成员)
					lib_guild:send_guild_mail(union_succeed_chose, 
									  [PGName, MemNames]),
					
					%%处理没选中的成员
					% 广播% 通知氏族成员
					OMems = lib_guild_inner:get_guild_member_by_guild_id(PUGId),
					ONameList = 
						lists:map(fun(OElem) ->
											union_player_change(0, OElem#ets_guild_member.player_id, 0, tool:to_binary(""), DepartName, []),
											OElem#ets_guild_member.player_name
									end, OMems),
					%%邮件通知(通知没有被选中加入的成员)
					lib_guild:send_guild_mail(union_succeed_unchose, 
									  [PGName, ONameList]),
					
					
					%%处理氏族表
					NewPGuild = PGuild#ets_guild{member_num = LenSubmit + Mem,
												 unions = 0,
												 union_id = 0,
												 union_gid = 0,
												 targid = 0},
					GValueList = [{member_num, LenSubmit + Mem},
								  {unions, 0},{union_id, 0}, {union_gid, 0}, {targid, 0}],
					GWhereList = [{id, NewPGuild#ets_guild.id}],
					%%修改ets
					lib_guild_inner:update_guild(NewPGuild),
					%%修改数据库
					db_update_guild_union(GValueList, GWhereList),
					
					%%删除不用的氏族
					%%删除氏族升级的记录
					lib_guild_inner:delete_ets_guild_upgrade(TarGId),	
					% 删除氏族表
					db_agent:guild_delete(TarGId),
					% 删除氏族申请表
					db_agent:guild_apply_delete(TarGId),
					% 删除氏族邀请表
					db_agent:guild_invite_delete(TarGId),
					%%氏族解散，删除氏族仓库的所有物品
					lib_guild_warehouse:delete_warehouse_disband(TarGId),
					% 更新缓存
					lib_guild_inner:delete_guild(TarGId),
					lib_guild_inner:delete_guild_invite_by_guild_id(TarGId),
					lib_guild_inner:delete_guild_apply_by_guild_id(TarGId),
					%%删除氏族技能信息表
					lib_guild_inner:delete_guild_skills_attribute(TarGId),
					%%删除ets中 的有关该氏族日志记录
					lib_guild_inner:delete_log_guild(TarGId),
					%%邮件通知被兼并的氏族的族长
					lib_guild:send_guild_mail(union_succeed_chief, 
											  [PGName, ChiefName]),
					
					%%处理申请表
					 %%删除ets
					UWhereList = [{id, Union#guild_union.id}],
					ets_delete_union_id(Union#guild_union.id),
					%%删除数据库记录
					db_delete_union(UWhereList),
					%%把相关两个氏族的联合全部删除
					delete_relate_unions(PGId, TarGId),
					%%添加合并日志
					UnionTime = util:unixtime(),
					add_gunion_log(PGId,TarGId,PGName,TarGName,UnionTime),
					{10, 0, 0}
			end
	end.
%%把相关两个氏族的联合全部删除
delete_relate_unions(PGId, TarGId) ->
	%%把自己申请的所有删掉
	PA = ets_select_union(a, TarGId),
	PB = ets_select_union(b, TarGId),
	lists:foreach(fun(EA) ->
						  EAWhereList1 = [{id, EA#guild_union.id}],
						  %%删除ets
						  ets_delete_union_id(EA#guild_union.id),
						  %%删除数据库记录
						  db_delete_union(EAWhereList1)
				  end,PA),
	lists:foreach(fun(EB) ->
						  EBWhereList1 = [{id, EB#guild_union.id}],
						  %%删除ets
						  ets_delete_union_id(EB#guild_union.id),
						  %%删除数据库记录
						  db_delete_union(EBWhereList1)
				  end,PB),
	%%删除两者的
	Pattern1 = ets_find_unioin(PGId, TarGId),
	Pattern2 = ets_find_unioin(TarGId, PGId),
%% 	?DEBUG("Pattern1:~p Pattern2:~p", [Pattern1, Pattern2]),
	lists:foreach(fun(Elem1) ->
						  UWhereList1 = [{id, Elem1#guild_union.id}],
						  %%删除ets
						  ets_delete_union_id(Elem1#guild_union.id),
						  %%删除数据库记录
						  db_delete_union(UWhereList1)
				  end,Pattern1),
	lists:foreach(fun(Elem2) ->
						  UWhereList2 = [{id, Elem2#guild_union.id}],
						  %%删除ets
						  ets_delete_union_id(Elem2#guild_union.id),
						  %%删除数据库记录
						  db_delete_union(UWhereList2)
				  end,Pattern2).
	
%%氏族进程处理 联盟成员数据
union_player_change(Type, MemId, GId, GName, DepartName, AllianceId) ->
	case Type of
		0 ->%%处理没被选中的成员
%% 			% 删除氏族成员表
			MemWhereList = [{player_id, MemId}],
			db_delete_member_union(MemWhereList),
			% 更新缓存
			lib_guild_inner:delete_guild_member_by_player_id(MemId),
			case lib_player:get_player_pid(MemId) of
				[] ->%%不在线呢
					ValueList = [{guild_id, 0}, 
								 {guild_name, ""}, 
								 {guild_position, 0},
								 {quit_guild_time, 0},
								 {guild_title, ""},
								 {guild_depart_name, DepartName},
								 {guild_depart_id, 0}],
					WhereList = [{id, MemId}],
					db_agent:guild_player_update_info(ValueList, WhereList);
				Pid ->%%在线喔
					gen_server:cast(Pid, {'union_player_change', Type, MemId, GId, GName, DepartName, AllianceId})
			end;
		1 ->%%处理被选中的成员
			case lib_player:get_player_pid(MemId) of
				[] ->%%不在线呢
					ValueList = [{guild_id, GId}, 
								 {guild_name, GName}, 
								 {guild_position, 12},
								 {guild_title, ""},
								 {guild_depart_name, DepartName},
								 {guild_depart_id, 5}],
					WhereList = [{id, MemId}],
					db_agent:guild_player_update_info(ValueList, WhereList);
				Pid ->%%在线喔
					gen_server:cast(Pid, {'union_player_change', Type, MemId, GId, GName, DepartName, AllianceId})
			end
	end.

%%玩家进程处理氏族联盟数据
cast_union_player_change(Player, Type, MemId, GId, GName, DepartName, AllianceId) ->
%% 	?DEBUG("PlayerId:~p, Type:~p, MemId:~p, GId:~p, GName:~p, DepartName:~p", [Player#player.id, Type, MemId, GId, GName, DepartName]),
	case Type of
		0 ->%%处理没被选中的成员
			NewPlayer = Player#player{guild_id = GId,
									  guild_name = GName,
									  guild_position = 0,
									  quit_guild_time = 0,
									  guild_title = "",
									  guild_depart_name = DepartName,
									  guild_depart_id = 0,
									  other = Player#player.other#player_other{g_alliance = []}	%%联盟中的氏族Id清空
									 },
			ValueList = [{guild_id, 0}, 
						 {guild_name, ""},
						 {guild_position, 0},
						 {quit_guild_time, 0},
						 {guild_title, ""},
						 {guild_depart_name, DepartName},
						 {guild_depart_id, 0}],
			WhereList = [{id, MemId}],
			db_agent:guild_player_update_info(ValueList, WhereList),
			mod_player:save_online_diff(Player, NewPlayer),
			%%氏族任务处理
			gen_server:cast(Player#player.other#player_other.pid_task, {'guild_task_del',NewPlayer}),
			{ok, Bin} = pt_40:write(40065, [GId, GName, 0, 0, "", DepartName, 5]),
			lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, Bin),
			NewPlayer;
		1 ->
			NewPlayer = Player#player{guild_id = GId,
									  guild_name = GName,
									  guild_position = 12,
									  guild_title = "",
									  guild_depart_name = DepartName,
									  guild_depart_id = 5,
									  other = Player#player.other#player_other{g_alliance = AllianceId}	%%联盟中的氏族Id
									 },
			ValueList = [{guild_id, GId}, 
						 {guild_name, GName}, 
						 {guild_position, 12},
						 {guild_title, ""},
						 {guild_depart_name, DepartName},
						 {guild_depart_id, 5}],
			WhereList = [{id, MemId}],
			db_agent:guild_player_update_info(ValueList, WhereList),
			mod_player:save_online_diff(Player, NewPlayer),
			{ok, Bin} = pt_40:write(40065, [GId, GName, 12, 0, "", DepartName, 5]),
			lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, Bin),
			NewPlayer
	end.
	
			
			

%%被吞并方提交
submit_union_panel(Union, PGuild, TarGuild, SubmitList) ->
%% 	?DEBUG("submit_union_panel", []),
	#guild_union{unions = UnionState} = Union,
	#ets_guild{id = PGId,
			   union_gid = PUGId,
			   chief_id = ChiefId,
			   chief_name = ChiefName} = PGuild,
	#ets_guild{id = TarGId,
			   member_num = Mem} = TarGuild,
	if
		PUGId =/= PGId andalso TarGId =/= PUGId ->%%不是被吞并方?
%% 			?DEBUG("AAAAA:~p,~p,~p", [PUGId, PGId, TarGId]),
			{6, 0, 0};
		PUGId =/= PGId ->%%有状况
			{0, 0, 0};
		true ->
%% 			?DEBUG("BBBBB", []),
			%%计算氏族人数上限
			TarGLv = lib_guild:get_guild_skill_level(TarGuild#ets_guild.id, 3),
			TarMLimit = data_guild:get_guild_config(guild_member_base,[]) + TarGLv * 5,
			MRest = abs(TarMLimit - Mem),
			%%判断族长是否在名单里面
			NSubmitList = 
						case lists:keyfind(ChiefId, 1, SubmitList) of
							false ->
								[{ChiefId, ChiefName}|SubmitList];
							_Tuple ->
								SubmitList
							
						end,
			LenSubmit = length(NSubmitList),
			if
				MRest < LenSubmit ->%%人数超了
					{7, MRest, LenSubmit};
				UnionState =/= 1 ->%%流程居然出问题了
%% 					?DEBUG("UnionState:~p", [UnionState]),
					{0, 0, 0};
				true ->%%可以了吧
%% 					io:format("LenSubmit:~p", [LenSubmit]),
					%%改ets
					lists:map(fun({MemId, _MemName}) ->
									  case lib_guild_inner:get_guild_member_by_guildandplayer_id(PGId, MemId) of
										  [] ->
											  skip;
										  Member ->
%% 											  io:format("{MemId:~p, _MemName:~p};;", [MemId, _MemName]),
											  NewMember = Member#ets_guild_member{unions = 1},
											  lib_guild_inner:update_guild_member(NewMember),
											  %%改数据库
											  ValueList = [{unions, 1}],
											  WhereList = [{player_id, MemId}, {guild_id, PGId}],
%% 											  io:format("444444444444444444444  ~p", [WhereList]),
											  db_update_member_union(ValueList, WhereList)
									  end
							  end, NSubmitList),
%% 					io:format("11111111111"),
%% 					%%改数据库
%% 					ValueList = [{unions, 1}],
%% 					WhereList = [{player_id, "in", MemIds}, {guild_id, PGId}],
%% %% 					io:format("444444444444444444444  ~p", [WhereList]),
%% 					db_update_member_union(ValueList, WhereList),
%% 					io:format("dddsdfasdfasdfsdafsadfsdafsdf"),
					%%修改氏族相关
					NPGuild = PGuild#ets_guild{unions = 2},
					PValueList = [{unions, 2}],
					PWhereList = [{id, NPGuild#ets_guild.id}],
					NTarGuild = TarGuild#ets_guild{unions = 2},
					TarValueList = [{unions, 2}],
					TarWhereList = [{id, NTarGuild#ets_guild.id}],
%% 					io:format("555555555555555"),
					%%修改ets
					lib_guild_inner:update_guild(NPGuild),
					lib_guild_inner:update_guild(NTarGuild),
					%%修改数据库
					db_update_guild_union(PValueList, PWhereList),
					db_update_guild_union(TarValueList, TarWhereList),
					%%更新申请条目
					NowTime = util:unixtime(),
					NewUnion = Union#guild_union{apt = NowTime,
												 unions = 2},
					ets_update_union(NewUnion),
					UValueList = [{apt, NowTime}, {unions, 2}],
					UWhereList = [{id, NewUnion#guild_union.id}],
					db_update_union(UValueList, UWhereList),
					%%邮件通知
%% 					io:format("Name:~p,ChiefName:~p", [PGuild#ets_guild.name, NTarGuild#ets_guild.chief_name]),
					lib_guild:send_guild_mail(chose_union_member, 
											  [PGuild#ets_guild.name, NTarGuild#ets_guild.chief_name]),
%% 					io:format("333333333333"),
					{1, 0, 0}
			end
	end.
					

					
					
					
					
%%
%% Local Functions
%%
%%氏族合并日志
add_gunion_log(AGId,BGId,AGName,BGName,Time) ->
	Fields = [agid,bgid,agname,bgname,time],
	Values = [AGId,BGId,AGName,BGName,Time],
	spawn(fun() -> db_agent:add_gunion_log(Fields, Values) end).
%% ==============================================================
%% 处理由于氏族数据发生变化后引起的氏族联盟数据更新的异步处理
%% ==============================================================
%%氏族升级
upgrade_guild(Param) ->
	{GuildId,NewLevel} = Param,
	AUnions = ets_select_union(a,GuildId),
	BUnions = ets_select_union(b,GuildId),
	lists:foreach(fun(AElem) ->
						  NewAElem = AElem#guild_union{alv = NewLevel},
						  ets_update_union(NewAElem),
						  WhereList = [{id, NewAElem#guild_union.id}],
						  ValueList = [{alv, NewLevel}],
						  db_update_union(ValueList, WhereList)
				  end, AUnions),
	lists:foreach(fun(BElem) ->
						  NewBElem = BElem#guild_union{blv = NewLevel},
						  ets_update_union(NewBElem),
						  WhereList = [{id, NewBElem#guild_union.id}],
						  ValueList = [{blv, NewLevel}],
						  db_update_union(ValueList, WhereList)
				  end, BUnions),
	%%处理氏族的联盟数据
	lib_guild_alliance:upgrade_guild_alliance(GuildId,NewLevel).

%%氏族成员变化
upmem_guild(Param) ->
	{GuildId,Mem,MLimit} = Param,
	AUnions = ets_select_union(a,GuildId),
	BUnions = ets_select_union(b,GuildId),
	MemData = [Mem,MLimit],
	MemDataStr = util:term_to_string(MemData),
	lists:foreach(fun(AElem) ->
						  NewAElem = AElem#guild_union{amem = MemData},
						  ets_update_union(NewAElem),
						  WhereList = [{id, NewAElem#guild_union.id}],
						  ValueList = [{amem, MemDataStr}],
						  db_update_union(ValueList, WhereList)
				  end, AUnions),
	lists:foreach(fun(BElem) ->
						  NewBElem = BElem#guild_union{bmem = MemData},
						  ets_update_union(NewBElem),
						  WhereList = [{id, NewBElem#guild_union.id}],
						  ValueList = [{bmem, MemDataStr}],
						  db_update_union(ValueList, WhereList)
				  end, BUnions),
	%%处理氏族的联盟数据
	lib_guild_alliance:upmem_guild_alliance(GuildId,Mem,MLimit).

%%禅让族长
demise_guild(Param) ->
	{GuildId, CId, CName} = Param,
	AUnions = ets_select_union(a,GuildId),
	BUnions = ets_select_union(b,GuildId),
	lists:foreach(fun(AElem) ->
						  NewAElem = AElem#guild_union{acid = CId,
													   acname = CName},
						  ets_update_union(NewAElem),
						  WhereList = [{id, NewAElem#guild_union.id}],
						  ValueList = [{acid, CId}, {acname, CName}],
						  db_update_union(ValueList, WhereList)
				  end, AUnions),
	lists:foreach(fun(BElem) ->
						  NewBElem = BElem#guild_union{bcid = CId,
													   bcname = CName},
						  ets_update_union(NewBElem),
						  WhereList = [{id, NewBElem#guild_union.id}],
						  ValueList = [{bcid, CId}, {bcname, CName}],
						  db_update_union(ValueList, WhereList)
				  end, BUnions),
	%%处理氏族的联盟数据
	lib_guild_alliance:demise_guild_alliance(GuildId, CId, CName).

%%氏族解散
disband_guild(Param) ->
	{GuildId} = Param,
	AUnions = ets_select_union(a,GuildId),
	BUnions = ets_select_union(b,GuildId),
	AIds = 
		lists:map(fun(AElem) ->
						  AUnionId = AElem#guild_union.id,
						  ets_delete_union_id(AUnionId),
						  AUnionId
				  end, AUnions),
	BIds = 
		lists:foreach(fun(BElem) ->
						  BUnionId = BElem#guild_union.id,
						  ets_delete_union_id(BUnionId),
						  BUnionId
					  end, BUnions),
	Ids = lists:concat([AIds,BIds]),
	WhereList = [{id, "in", Ids}],
	db_delete_union(WhereList),
	%%处理氏族的联盟数据
	lib_guild_alliance:disband_guild_alliance(GuildId).

%%额外的处理
skip_other(_Param) ->
	ok.

%% ==============================================================
%% ==============================================================
