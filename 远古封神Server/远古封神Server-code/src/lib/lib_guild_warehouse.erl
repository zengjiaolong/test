%% Author: xiaomai
%% Created: 2011-1-24
%% Description: 氏族仓库处理方法
-module(lib_guild_warehouse).

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
-export([insert_warehouse_goods_attributes/1,%%此方法只是export，但不提供对外调用(待定)
		 init_guild_warehouse/0,
		 get_storage_num/3,
		 get_guild_goods/3,
		 takeout_warehouse_goods/6,
		 put_goods_into_bag/5,
		 putin_warehouse_goods/5,
		 delete_goods_from_player/2,
		 get_warehouse_goods_info/5,
		 delete_warehouse_disband/1,
		 insert_warehouse_flow_log/5]).
%% -compile([export_all]).

%%
%% API Functions
%%
%%进初始化氏族仓库相关的ets表
init_guild_warehouse() ->
	%%记录氏族仓库是否已经被加载
	ets:new(?ETS_GUILD_WAREHOUSE_INIT_TRACE, [{keypos, 1}, named_table, public, set,?ETSRC, ?ETSWC]),
	%%氏族仓库物品表
	ets:new(?ETS_GUILD_WAREHOUSE_GOODS, [{keypos, #goods.id}, named_table, public, set,?ETSRC, ?ETSWC]),
	%%氏族仓库物品属性表
	ets:new(?ETS_GUILD_WAREHOUSE_ATTRIBUTES, [{keypos, #goods_attribute.id}, named_table, public, set,?ETSRC, ?ETSWC]).


get_guild_storage(GuildId) ->
	F = fun(Goods,AccIn) ->
				{GoodsIdList,GoodsList} = AccIn,
				GoodsInfo = list_to_tuple([goods] ++ Goods),
				ets:insert(?ETS_GUILD_WAREHOUSE_GOODS, GoodsInfo),
				{[GoodsInfo#goods.id|GoodsIdList], [GoodsInfo|GoodsList]}
         end,
	GoodsIdList =
		case db_agent:get_guild_storage(GuildId) of
		[] ->
			skip,
			{[],[]};
		GoodsList when is_list(GoodsList) ->
			lists:foldl(F, {[], []}, GoodsList);
		_ ->
			skip,
			{[],[]}
	end,
	GoodsIdList.

get_guild_storage_attributes(GoodsIdList) ->
	F = fun(GoodsId) ->
				case db_agent:get_warehouse_goods_attribute(GoodsId) of
					[] ->
						skip;
					GoodsAttrrList when is_list(GoodsAttrrList) ->
						lists:foreach(fun insert_goods_attris_into_ets/1, GoodsAttrrList);
					_ ->
						skip
				end
		end,
	lists:foreach(F, GoodsIdList).
insert_goods_attris_into_ets(GoodsAttr) ->
	GoodsAttriEts = list_to_tuple([goods_attribute] ++ GoodsAttr),
	ets:insert(?ETS_GUILD_WAREHOUSE_ATTRIBUTES, GoodsAttriEts).

%% -----------------------------------------------------------------
%% 40050 获取氏族仓库当前物品总数
%% -----------------------------------------------------------------
get_storage_num(PidSend, MyGuildId, GuildId) ->
	StorageLimit = 
	case MyGuildId =:= GuildId of
		true ->
			case lib_guild_inner:get_guild(GuildId) of
				[] ->
					0;
				Guild ->
					Guild#ets_guild.storage_num
			end;
		false ->
			0
	end,
	{ok, BinData} = pt_40:write(40050, [StorageLimit]),
	lib_send:send_to_sid(PidSend, BinData).
%% -----------------------------------------------------------------
%% 40051 获取氏族仓库物品列表
%% -----------------------------------------------------------------
get_guild_goods(PidSend, MyGuildId, GuildId) ->
	[RetCapacity, RetGuildGoodsList] = 
	case MyGuildId =:= GuildId of
		true ->
			case lib_guild_inner:get_guild(GuildId) of
				[] ->
					[0, []];
				Guild ->
					case get_guild_skill_level(GuildId, 1) of
						[] ->
							[0, []];
						[SkillAttribute] ->
							if SkillAttribute#ets_guild_skills_attribute.skill_level =< 0 ->
								   [0, []];
							   true ->
								   GoodsList = get_warehouse_goods(GuildId),
								   Len = length(GoodsList),
								   case Len =:= Guild#ets_guild.storage_num of
									   true when Len =:= 0->
										    WarehouseLevel = lib_guild:get_guild_skill_level(GuildId, 1),
											WarehoseBase = data_guild:get_guild_config(guild_warehouse_base, []),
											WarehouseCapacity = WarehouseLevel * WarehoseBase,
											[WarehouseCapacity, []];
									   true  ->
										   %%计算氏族仓库容量
										   WarehouseLevel = lib_guild:get_guild_skill_level(GuildId, 1),
										   WarehoseBase = data_guild:get_guild_config(guild_warehouse_base, []),
										   WarehouseCapacity = WarehouseLevel * WarehoseBase,
										   GuildGoodsList = lists:map(fun handle_each_warehouse_goods/1, GoodsList),
										   [WarehouseCapacity, GuildGoodsList];
									   false ->
										   %%计算氏族仓库容量
										   WarehouseLevel = lib_guild:get_guild_skill_level(GuildId, 1),
										   WarehoseBase = data_guild:get_guild_config(guild_warehouse_base, []),
										   WarehouseCapacity = WarehouseLevel * WarehoseBase,
										   case Len =< WarehouseCapacity of
											   true ->
												   NewGuild = Guild#ets_guild{storage_num = Len},
												   update_guild_warehouse(NewGuild, GuildId),
												   GuildGoodsList = lists:map(fun handle_each_warehouse_goods/1, GoodsList),
												   [WarehouseCapacity, GuildGoodsList];
											   false ->
												   NewGuild = Guild#ets_guild{storage_num = WarehouseCapacity},
												   update_guild_warehouse(NewGuild, GuildId),
												   NewGoodsList = lists:nthtail(Len - WarehouseCapacity, GoodsList),
												   GuildGoodsList = lists:map(fun handle_each_warehouse_goods/1, NewGoodsList),
												   [WarehouseCapacity, GuildGoodsList]
										   end
								   end
							end
					end
			end
	end,
	{ok, BinData} = pt_40:write(40051, [RetCapacity, RetGuildGoodsList]),
	lib_send:send_to_sid(PidSend, BinData).

get_warehouse_goods(GuildId) ->
	case check_guild_loadornot(GuildId) of
		true ->
			Pattern = #goods{equip_type = GuildId, _='_'},
			ets:match_object(?ETS_GUILD_WAREHOUSE_GOODS, Pattern);
		false ->%%没有load仓库物品，这在第一次查看的时候load
			{GoodsIdList, GoodsList} = get_guild_storage(GuildId),
			mark_warehouse_loaded(GuildId),
			case GoodsIdList of
				[] ->
					skip;
				_ ->
					get_guild_storage_attributes(GoodsIdList)
			end,
			GoodsList
	end.
			
mark_warehouse_loaded(GuildId) ->
	NowTime = util:unixtime(),
	ets:insert(?ETS_GUILD_WAREHOUSE_INIT_TRACE, {GuildId, NowTime}).
check_guild_loadornot(GuildId) ->
	case ets:lookup(?ETS_GUILD_WAREHOUSE_INIT_TRACE, GuildId) of
		[] ->
			false;
		[_Info] ->
			true
	end.

handle_each_warehouse_goods(Goods) ->
	#goods{id = GoodsId,
		   goods_id = GoodsTypeId,
		   num = Num} = Goods,
	{GoodsId, GoodsTypeId, Num}.

%% -----------------------------------------------------------------
%% 40052 取出氏族仓库物品
%% -----------------------------------------------------------------
takeout_warehouse_goods(MyGuildId, GuildPosition, GuildId, GoodsId, GoodsPid, PlayerId) ->
	case MyGuildId =:= GuildId of
		true ->
			case lib_guild_inner:get_guild(GuildId) of
				[] ->
					error;
				Guild ->
					case get_guild_skill_level(GuildId, 1) of
						[] ->
							error;
						[SkillAttribute] ->
							if SkillAttribute#ets_guild_skills_attribute.skill_level =< 0 ->
								   error;%%仓库技能出错
							   true ->
								   if GuildPosition >= 8 ->
										  3;%%没权限
									  true ->
										  case get_goods_from_warehouse(GoodsId) of
											  [] ->%%没有该物品
												  4;
											  [GoodsInfo] when is_record(GoodsInfo, goods) ->
												  case GoodsInfo#goods.location =:= 8 of
													  true ->%%不在氏族仓库里，出错
														  AttributesList = get_goods_attributes_from_warehouse(GoodsId),
														  case catch(gen_server:call(GoodsPid, {'TACKOUT_FROM_GUILD_WAREHOUSE', GoodsInfo, AttributesList})) of
															  {ok} ->%%成功
																  delete_warehouse_goods(GoodsId),
																  delete_warehouse_goods_attributes(GoodsId),
																  NewGuild = Guild#ets_guild{storage_num = Guild#ets_guild.storage_num - 1},
																  update_guild_warehouse(NewGuild, GuildId),
																  %%发送仓库物品更新消息通知
																  lib_guild_inner:send_guild(0, PlayerId, MyGuildId, guild_wareshoue_goods, [0, GoodsId]),
																  %%添加氏族仓库的物品流向记录日志
																  spawn(lib_guild_warehouse, insert_warehouse_flow_log,
																		[GuildId, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, PlayerId, 0]),
																  1;
															  {fail, Result} ->%%物品有问题
																  Result;
															  _Error ->%%报错
																  error
														  end;
													  false ->
														  4
												  end;
											  _OtherError ->
												  4
										  end
								   end
							end
					end
			end;
		false ->
			2
	end.
					
put_goods_into_bag(GoodsInfo, Cell, Location, AttributesList, PlayerId) ->
	NewGoodsInfo = GoodsInfo#goods{player_id = PlayerId, cell = Cell, location = Location, equip_type = 0},
	case db_agent:put_goods_into_bag(PlayerId, Cell, 0, Location, NewGoodsInfo#goods.id) of
		1 ->
			ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
			lists:foreach(fun(Elem) ->
								  NewElem = Elem#goods_attribute{player_id = PlayerId},
								  ets:insert(?ETS_GOODS_ATTRIBUTE, NewElem)
						  end, AttributesList),
			ok;
		_ ->
			error
	end.

%% -----------------------------------------------------------------
%% 40053 放入氏族仓库物品
%% -----------------------------------------------------------------
putin_warehouse_goods(MyGuildId, GuildId, GoodsId, GoodsPid, PlayerId) ->
	case MyGuildId =:= GuildId of
		true ->
			case lib_guild_inner:get_guild(GuildId) of
				[] ->
					error;
				Guild ->
					case get_guild_skill_level(GuildId, 1) of
						[] ->
							error;
						[SkillAttribute] ->
							if 
								SkillAttribute#ets_guild_skills_attribute.skill_level =< 0 ->
									error;
								true ->
									%%计算氏族仓库容量
									WarehouseLevel = lib_guild:get_guild_skill_level(GuildId, 1),
									WarehoseBase = data_guild:get_guild_config(guild_warehouse_base, []),
									WarehouseCapacity = WarehouseLevel * WarehoseBase,
									case WarehouseCapacity > Guild#ets_guild.storage_num of
										true  ->
											case catch(gen_server:call(GoodsPid, {'PUT_INTO_GUILD_WAREHOUSE', GoodsId, GuildId})) of
												{ok, GoodsInfo, Attributes} ->
													update_goods_player_to_warehouse(GuildId, GoodsInfo, Attributes),
													NewGuild = Guild#ets_guild{storage_num = Guild#ets_guild.storage_num + 1},
													update_guild_warehouse(NewGuild, GuildId),
													%%发送仓库物品更新消息通知
													lib_guild_inner:send_guild(0, PlayerId, GuildId, guild_wareshoue_goods, [1, GoodsId]),
													%%添加氏族仓库的物品流向记录日志
													spawn(lib_guild_warehouse, insert_warehouse_flow_log,
														  [GuildId, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, PlayerId, 1]),
													1;
												{fail, Result} ->
													Result;
												_Error ->
													error
											end;
										false ->%%仓库容量不足
											4
									end
							end
					end
			end;
		false ->
			2
	end.
	
delete_goods_from_player(GoodsId, GuildId) ->
	case db_agent:goods_player_to_warehouse(GoodsId, GuildId, 8, 0) of
		1 ->
			ets:delete(?ETS_GOODS_ONLINE, GoodsId),
			Pattern = #goods_attribute{gid = GoodsId, _ = '_'},
			ets:match_delete(?ETS_GOODS_ATTRIBUTE, Pattern),
			ok;
		_ ->
			fail
	end.
update_goods_player_to_warehouse(GuildId, GoodsInfo, Attributes) ->
	NewGoodsInfo = GoodsInfo#goods{cell = 0,
								   player_id = 0,
								   location = 8,
								   equip_type = GuildId},
	insert_warehouse_goods(NewGoodsInfo),
	goods_attrs_player_to_warehouse(Attributes).
goods_attrs_player_to_warehouse(Attributes) ->
	F = fun(Attribute) ->
				NewAttribute = Attribute#goods_attribute{player_id = 0},
				insert_warehouse_goods_attribute(NewAttribute)
		end,
	lists:map(F, Attributes).


%% -----------------------------------------------------------------
%% 40054 获取物品详细信息(仅在氏族模块用)
%% -----------------------------------------------------------------
get_warehouse_goods_info(PidSend, MyGuildId, _GuildPosition, GuildId, GoodsId) ->
%% 	?DEBUG("get_warehouse_goods_info2222222222222", []),
	[Result, Info] = 
	case MyGuildId =:=  GuildId of
		true ->
			case lib_guild_inner:get_guild(GuildId) of
				[] ->
					[0, {}];
				_Guild ->
					case get_goods_from_warehouse(GoodsId) of
						[] ->
							[2, {}];
						[GoodsInfo] ->
							case is_record(GoodsInfo,goods) of
								true when GoodsInfo#goods.equip_type =:= GuildId ->
									case goods_util:has_attribute(GoodsInfo) of
										true ->
											AttributeList = get_goods_attributes_from_warehouse(GoodsId);
										false ->
											AttributeList = []
									end,
									[1, {GoodsInfo, 0, AttributeList}];
								_Error ->
									[2, {}]
							end
					end
			end;
		false ->
			[0, {}]
	end,
	{ok, BinData} = pt_40:write(40054, [Result, Info]),
	lib_send:send_to_sid(PidSend, BinData).
					
%% -----------------------------------------------------------------
%% 40002 解散氏族,删除氏族仓库的所有物品
%% -----------------------------------------------------------------
delete_warehouse_disband(GuildId) ->
	case get_goods_id_from_warehouse(GuildId) of
		[] ->
			skip;
		GoodsIdList when is_list(GoodsIdList)->
			lists:foreach(fun delete_warehouse_each_disband/1, GoodsIdList);
		_Error ->
			skip
	end.
delete_warehouse_each_disband(GoodsId) ->
	db_agent:delete_warehouse_each_disband(GoodsId),
	delete_warehouse_goods(GoodsId),
	delete_warehouse_goods_attributes(GoodsId).
			
%%
%% Local Functions
%%
%%获取氏族仓库的物品相关信息
%%get
get_goods_from_warehouse(GoodsId) ->
	ets:lookup(?ETS_GUILD_WAREHOUSE_GOODS, GoodsId).
get_goods_id_from_warehouse(GuildId) ->
	Ms = ets:fun2ms(fun(T) when T#goods.equip_type =:= GuildId ->
							T#goods.id
					end),
	ets:select(?ETS_GUILD_WAREHOUSE_GOODS, Ms).
get_goods_attributes_from_warehouse(GoodsId) ->
	Pattern = #goods_attribute{gid = GoodsId, _ = '_'},
	ets:match_object(?ETS_GUILD_WAREHOUSE_ATTRIBUTES, Pattern).

%%insert
insert_warehouse_goods(GoodsInfo) ->
	ets:insert(?ETS_GUILD_WAREHOUSE_GOODS, GoodsInfo).
insert_warehouse_goods_attributes(AttributesList) ->
	F = fun(Attribute) ->
				ets:insert(?ETS_GUILD_WAREHOUSE_ATTRIBUTES, Attribute)
		end,
	lists:foreach(F, AttributesList).
insert_warehouse_goods_attribute(Attribute) ->
	ets:insert(?ETS_GUILD_WAREHOUSE_ATTRIBUTES, Attribute).
%%delete
delete_warehouse_goods(GoodsId) ->
	ets:delete(?ETS_GUILD_WAREHOUSE_GOODS, GoodsId).
delete_warehouse_goods_attributes(GoodsId) ->
	Pattern = #goods_attribute{gid = GoodsId, _ = '_'},
	ets:match_delete(?ETS_GUILD_WAREHOUSE_ATTRIBUTES, Pattern).


update_guild_warehouse(NewGuild, GuildId) ->
	db_agent:update_guild_warehouse(guild, [{storage_num, NewGuild#ets_guild.storage_num}], [{id, GuildId}]),
	lib_guild_inner:update_guild(NewGuild).
get_guild_skill_level(GuildId, SkillId) ->
	Pattern = #ets_guild_skills_attribute{guild_id = GuildId, skill_id = SkillId, _ = '_'},
	ets:match_object(?ETS_GUILD_SKILLS_ATTRIBUTE, Pattern).

%%添加氏族仓库的物品流向记录日志
insert_warehouse_flow_log(GuildId, GoodsId, GoodsTypeId, PlayerId, FlowType) ->
	FlowTime = util:unixtime(),
	WarehouseGoodsDir = 
		#ets_log_warehouse_flowdir{guild_id = GuildId,
								   gid = GoodsId,
								   goods_id = GoodsTypeId,
								   player_id = PlayerId,
								   flow_type = FlowType,
								   flow_time = FlowTime},
	db_agent:insert_warehouse_flow_log(WarehouseGoodsDir).
