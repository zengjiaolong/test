%%%--------------------------------------
%%% @Module  : mysql_to_emongo
%%% @Author  : ygzj
%%% @Created : 2011.03.03
%%% @Description: emongo数据库合服处理模块
%%%--------------------------------------
-module(union_to_emongo).
-compile([export_all]). 
-include("common.hrl").
-include("record.hrl").
-define(SAVE_PATH, "../logs/").

%%添加服号
-define(SN, config:get_server_number(gateway)). 

%%添加最大id数字
-define(Max_id, config:get_max_id(gateway)). 

%%添加服号数据表集合
-define(SN_List, [user,player,infant_ctrl_byuser]). 

%%删除数据等级限制
-define(DelLevel, 10). 

%%每次查询或更新记录条数
-define(PageSize, 100). 

%% monogo数据库连接初始化
init_mongo(App) ->
	try 
		[PoolId, Host, Port, DB, EmongoSize] = config:get_mongo_config(App),
		emongo_sup:start_link(),
		emongo_app:initialize_pools([PoolId, Host, Port, DB, EmongoSize]),
		misc:write_system_info({self(),mongo}, mongo, {PoolId, Host, Port, DB, EmongoSize}),
		{ok,master_mongo}
	catch
		_:_ ->  mongo_config_error
	end.

%% monogo数据库连接初始化
init_slave_mongo(App) ->
	try 
		[PoolId, Host, Port, DB, EmongoSize] = config:get_slave_mongo_config(App),
		emongo_sup:start_link(),
		emongo_app:initialize_pools([PoolId, Host, Port, DB, EmongoSize]),
		misc:write_system_info({self(),mongo_slave}, mongo_slave, {PoolId, Host, Port, DB, EmongoSize}),
		{ok,slave_mongo}
	catch
		_:_ -> slave_config_error %%没有配置从数据库
	end.



%% 启动合并程序
%%操作顺序 ：1.部分表加列sn 2.删除角色数据(可选)  3.更新名字=服号+nickname  4.更新所有id,保证id唯一  5.批处理导入数据  6.最后更新audo_ids的对应的id   7.合服后根据条件删除数据

%%在player,user,infant_ctrl_byuser表中添加服号
start(1) ->
	case ?SN > 0 of
		false -> 
			skip;
		true ->
			F = fun(Table_name) ->
						db_mongo:update(tool:to_list(Table_name), [{sn,?SN}], [])
				end,
			lists:foreach(F, ?SN_List)
	end,
	io:format("add server number finished!");
	
%%删除等级之下的所有角色	
start(2) ->
	IdList = lists:flatten(db_mongo:select_all("player", "id", [{lv, "<=", ?DelLevel}])),
	case IdList of
		[] -> 
			  skip;
		_ ->
			TableList = lib_player_rw:get_all_tables(),
			F = fun(Tablename) ->
						case Tablename of
							arena -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							arena_week -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);	
							box_scene -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							cards -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);	
							carry -> db_mongo:delete(Tablename, [{pid,"in",IdList}]);	
							consign_player -> db_mongo:delete(Tablename, [{pid,"in",IdList}]);	
							consign_task -> db_mongo:delete(Tablename, [{pid,"in",IdList}]);
							daily_bless -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							exc -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							feedback -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							fst_god -> db_mongo:delete(Tablename, [{uid,"in",IdList}]);
							goods -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							goods_attribute -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							goods_buff -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							goods_cd -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							%%帮派不能删除
 						    %%guild -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							guild_apply -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							guild_invite -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							guild_manor_cd -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							guild_member -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_backout -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_box_open -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_box_player -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_box_throw -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_compose -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_consume -> db_mongo:delete(Tablename, [{pid,"in",IdList}]);
							log_dungeon -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_employ -> db_mongo:delete(Tablename, [{pid,"in",IdList}]);
							log_exc -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_exc_exp -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_free_pet -> db_mongo:delete(Tablename, [{pid,"in",IdList}]);
							log_fst -> db_mongo:delete(Tablename, [{uid,"in",IdList}]);
							log_fst_mail -> db_mongo:delete(Tablename, [{uid,"in",IdList}]);
							log_hole -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_icompose -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_idecompose -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_identify -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_inlay -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_linggen -> db_mongo:delete(Tablename, [{pid,"in",IdList}]);
							log_mail -> db_mongo:delete(Tablename, [{uid,"in",IdList}]);
							log_merge -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_meridian -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_pay -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_practise -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_quality_out -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_quality_up -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_refine -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_sale -> db_mongo:delete(Tablename, [{buyer_id,"in",IdList}]), db_mongo:delete(Tablename, [{sale_id,"in",IdList}]);
							log_sale_dir -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_shop -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_stren -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_suitmerge -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_throw -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_trade -> db_mongo:delete(Tablename, [{donor_id,"in",IdList}]),db_mongo:delete(Tablename, [{gainer_id,"in",IdList}]);
							log_uplevel -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_use -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_warehouse_flowdir -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							log_wash -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							mail -> db_mongo:delete(Tablename, [{uid,"in",IdList}]);
							master_apprentice -> db_mongo:delete(Tablename, [{apprentenice_id,"in",IdList}]),db_mongo:delete(Tablename, [{master_id,"in",IdList}]);
							master_charts -> db_mongo:delete(Tablename, [{master_id,"in",IdList}]);
							meridian -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							mon_drop_analytics -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							offline_award -> db_mongo:delete(Tablename, [{pid,"in",IdList}]);
							online_award -> db_mongo:delete(Tablename, [{pid,"in",IdList}]);
							online_gift -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							pet -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							player -> db_mongo:delete(Tablename, [{id,"in",IdList}]);
							player_buff -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							player_donttalk -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							player_hook_setting -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							player_sys_setting -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							relationship -> db_mongo:delete(Tablename, [{idA,"in",IdList}]),db_mongo:delete(Tablename, [{idB,"in",IdList}]);
							sale_goods -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							skill -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							target_gift -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							task_bag -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							task_consign -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							task_log -> db_mongo:delete(Tablename, [{player_id,"in",IdList}]);
							_ -> skip
						end
				end,
			[F(Tablename) || Tablename <- TableList],
			io:format("delete data finished!")
	end;

%%更新角色名和帮派名，分别加上服号
start(3) ->
	TableList = lib_player_rw:get_all_tables(),
	F = fun(Tablename) ->
				case Tablename of
					arena -> update_name(Tablename,nickname,id);
					arena_week -> update_name(Tablename,nickname,id);
					feedback -> update_name(Tablename,player_name,id);
					fst_god -> update_name(Tablename,g_name,id),update_name(Tablename,nick,id);
					guild -> update_name(Tablename,name,id),update_name(Tablename,chief_name,id),update_name(Tablename,deputy_chief1_name,id),update_name(Tablename,deputy_chief2_name,id);
					guild_invite -> update_name(Tablename,recommander_name,id);
					guild_member -> update_name(Tablename,guild_name,id),update_name(Tablename,player_name,id);
					log_backout -> update_name(Tablename,nickname,id);
					log_box_open -> update_name(Tablename,player_name,id);
					log_compose -> update_name(Tablename,nickname,id);
					log_guild -> update_name(Tablename,guild_name,id);
					log_hole -> update_name(Tablename,nickname,id);
					log_icompose -> update_name(Tablename,nickname,id);
					log_idecompose -> update_name(Tablename,nickname,id);
					log_identify -> update_name(Tablename,nickname,id);
					log_inlay -> update_name(Tablename,nickname,id);
					log_mail -> update_name(Tablename,sname,id);
					log_merge -> update_name(Tablename,nickname,id);
					log_pay -> update_name(Tablename,nickname,id);
					log_practise -> update_name(Tablename,nickname,id);
					log_quality_out -> update_name(Tablename,nickname,id);
					log_quality_up -> update_name(Tablename,nickname,id);
					log_refine -> update_name(Tablename,nickname,id);
					log_sale -> update_name(Tablename,buyer_name,id),update_name(Tablename,saler_name,id);
					log_shop -> update_name(Tablename,nickname,id);
					log_stren -> update_name(Tablename,nickname,id);
					log_suitmerge -> update_name(Tablename,nickname,id);
					log_throw -> update_name(Tablename,nickname,id);
					log_trade -> update_name(Tablename,donor_name,id),update_name(Tablename,gainer_name,id);
					log_use -> update_name(Tablename,nickname,id);
					log_wash -> update_name(Tablename,nickname,id);
					mail -> update_name(Tablename,sname,id);
					master_apprentice -> update_name(Tablename,apprentenice_name,id);
					master_charts -> update_name(Tablename,master_name,id);
					mon_drop_analytics -> update_name(Tablename,player_name,id);
					player -> update_name(Tablename,nickname,id),update_name(Tablename,guild_name,id);
					sale_goods -> update_name(Tablename,player_name,id);
					_ -> skip
				end
		end,
	[F(Tablename) || Tablename <- TableList],
	io:format("change name finished!");

%%更新表所有id,保证id唯一
start(4) ->
	%%先查出另服的ID最大值
	%%查询有记录的表及最大主键
	L = search_another_max_id(),
	TableList = lib_player_rw:get_all_tables(),
 	F1 = fun(Tablename) ->
						case Tablename of
							arena -> update_id(Tablename,[{arena,id},{player,player_id}],0,L);
							arena_week -> update_id(Tablename,[{arena_week,id},{player,player_id}],0,L);
							box_scene -> update_id(Tablename,[{box_scene,id},{player,player_id}],0,L);
							cards -> update_id(Tablename,[{cards,id},{player,player_id}],0,L);
							carry -> update_id(Tablename,[{carry,id},{player,pid}],0,L);
							consign_player -> update_id(Tablename,[{consign_player,id},{player,pid}],0,L);
							consign_task -> update_id(Tablename,[{consign_task,id},{player,pid}],0,L);
							daily_bless -> update_id(Tablename,[{daily_bless,id},{player,player_id}],0,L);
							exc -> update_id(Tablename,[{exc,id},{player,player_id}],0,L);
							feedback -> update_id(Tablename,[{feedback,id},{player,player_id}],0,L);
							fst_god -> update_id(Tablename,[{fst_god,id},{player,uid}],0,L);
							goods -> update_id(Tablename,[{goods,id},{player,player_id}],0,L);
							goods_attribute -> update_id(Tablename,[{goods_attribute,id},{player,player_id},{goods,gid}],0,L);
							goods_buff -> update_id(Tablename,[{goods_buff,id},{player,player_id}],0,L);
							goods_cd -> update_id(Tablename,[{goods_cd,id},{player,player_id}],0,L);
							guild -> update_id(Tablename,[{guild,id},{player,chief_id},{player,deputy_chief1_id},{player,deputy_chief2_id}],1,L);
							guild_apply -> update_id(Tablename,[{guild_apply,id},{guild,guild_id},{player,player_id}],0,L);
							guild_invite -> update_id(Tablename,[{guild_invite,id},{guild,guild_id},{player,player_id},{player,recommander_id}],1,L);
							guild_manor_cd -> update_id(Tablename,[{guild_manor_cd,id},{player,player_id}],0,L);
							guild_member -> update_id(Tablename,[{guild_member,id},{guild,guild_id},{player,player_id}],0,L);
							guild_skills_attribute -> update_id(Tablename,[{guild_skills_attribute,id},{guild,guild_id}],0,L);
							infant_ctrl_byuser -> update_id(Tablename,[{infant_ctrl_byuser,id}],0,L);
							log_backout -> update_id(Tablename,[{log_backout,id},{player,player_id},{goods,gid}],0,L);
							log_box_open -> update_id(Tablename,[{log_box_open,id},{player,player_id},{goods,gid}],1,L);
							log_box_player -> update_id(Tablename,[{log_box_player,id},{player,player_id}],0,L);
							log_box_throw -> update_id(Tablename,[{log_box_throw,id},{player,player_id},{goods,gid}],0,L);
							log_compose -> update_id(Tablename,[{log_compose,id},{player,player_id}],0,L);
							log_consume -> update_id(Tablename,[{log_consume,id},{player,pid}],0,L);
							log_dungeon -> update_id(Tablename,[{log_dungeon,id},{player,player_id}],0,L);
							log_employ -> update_id(Tablename,[{log_employ,id},{player,pid}],0,L);
							log_exc -> update_id(Tablename,[{log_exc,id},{player,player_id}],0,L);
							log_exc_exp -> update_id(Tablename,[{log_exc_exp,id},{player,player_id}],0,L);
							log_free_pet -> update_id(Tablename,[{log_free_pet,id},{player,pid}],0,L);
							log_fst -> update_id(Tablename,[{log_fst,id},{player,uid}],0,L);
							log_fst_mail -> update_id(Tablename,[{log_fst_mail,id},{player,uid}],0,L);
							log_guild -> update_id(Tablename,[{log_guild,id},{guild,guild_id}],0,L);
							log_hole -> update_id(Tablename,[{log_hole,id},{player,player_id},{goods,gid}],0,L);
							log_icompose -> update_id(Tablename,[{log_icompose,id},{player,player_id}],0,L);
							log_idecompose -> update_id(Tablename,[{log_idecompose,id},{player,player_id},{goods,gid}],0,L);
							log_identify -> update_id(Tablename,[{log_identify,id},{player,player_id},{goods,gid}],0,L);
							log_inlay -> update_id(Tablename,[{log_inlay,id},{player,player_id},{goods,gid}],0,L);
							log_linggen -> update_id(Tablename,[{log_linggen,id},{player,pid}],0,L);
							log_mail -> update_id(Tablename,[{log_mail,id},{player,uid},{goods,gid}],1,L);
							log_merge -> update_id(Tablename,[{log_merge,id},{player,player_id},{goods,gid_1},{goods,gid_2}],0,L);
							log_meridian -> update_id(Tablename,[{log_meridian,id},{player,player_id}],0,L);
							log_pay -> update_id(Tablename,[{log_pay,id},{player,player_id}],0,L);
							log_practise -> update_id(Tablename,[{log_practise,id},{player,player_id},{goods,gid}],0,L);
							log_quality_out -> update_id(Tablename,[{log_quality_out,id},{player,player_id},{goods,gid}],0,L);
							log_quality_up -> update_id(Tablename,[{log_quality_up,id},{player,player_id},{goods,gid}],0,L);
							log_refine -> update_id(Tablename,[{log_refine,id},{player,player_id},{goods,gid}],0,L);
							log_sale -> update_id(Tablename,[{log_sale,id},{sale_goods,sale_id},{player,player_id},{goods,gid}],1,L);
							log_sale_dir -> update_id(Tablename,[{log_sale_dir,id},{sale_goods,sale_id},{player,player_id},{goods,gid}],1,L);
							log_shop -> update_id(Tablename,[{log_shop,id},{player,player_id}],0,L);
							log_stren -> update_id(Tablename,[{log_stren,id},{player,player_id},{goods,gid}],0,L);
							log_suitmerge -> update_id(Tablename,[{log_suitmerge,id},{player,player_id},{goods,gid1},{goods,gid2},{goods,gid3}],0,L);
							log_throw -> update_id(Tablename,[{log_throw,id},{player,player_id},{goods,gid}],0,L);
							log_trade -> update_id(Tablename,[{log_trade,id},{player,donor_id},{player,gainer_id},{goods,gid}],1,L);
							log_uplevel -> update_id(Tablename,[{log_uplevel,id},{player,player_id}],0,L);
							log_use -> update_id(Tablename,[{log_use,id},{player,player_id},{goods,gid}],0,L);
							log_warehouse_flowdir -> update_id(Tablename,[{log_warehouse_flowdir,id},{player,player_id},{goods,gid}],0,L);
							log_wash -> update_id(Tablename,[{log_wash,id},{player,player_id},{goods,gid}],0,L);
							login_prize -> update_id(Tablename,[{login_prize,id}],0,L);
							mail -> update_id(Tablename,[{mail,id},{player,uid},{goods,gid}],1,L);
							master_apprentice -> update_id(Tablename,[{master_apprentice,id},{player,apprentenice_id},{player,master_id}],1,L);
							master_charts -> update_id(Tablename,[{master_charts,id},{player,master_id}],0,L);
							meridian -> update_id(Tablename,[{meridian,id},{player,player_id}],0,L);
							mon_drop_analytics -> update_id(Tablename,[{mon_drop_analytics,id},{player,player_id}],0,L);
							offline_award -> update_id(Tablename,[{offline_award,id},{player,pid}],0,L);
							online_award -> update_id(Tablename,[{online_award,id},{player,pid}],0,L);
							online_gift -> update_id(Tablename,[{online_gift,id},{player,player_id}],0,L);
							pet -> update_id(Tablename,[{pet,id},{player,player_id}],0,L);
							player -> update_id(Tablename,[{player,id},{guild,guild_id}],1,L);
							player_buff -> update_id(Tablename,[{player_buff,id},{player,player_id}],0,L);
							player_donttalk -> update_id(Tablename,[{player,player_id}],0,L);
							player_hook_setting -> update_id(Tablename,[{player_hook_setting,id},{player,player_id}],0,L);
							player_sys_setting -> update_id(Tablename,[{player_sys_setting,id},{player,player_id}],0,L);
							relationship -> update_id(Tablename,[{relationship,id},{player,idA},{player,idB}],0,L);
							sale_goods -> update_id(Tablename,[{sale_goods,id},{goods,gid},{player,player_id}],0,L);
							skill -> update_id(Tablename,[{skill,id},{player,player_id}],0,L);
							target_gift -> update_id(Tablename,[{target_gift,id},{player,player_id}],0,L);
							task_bag -> update_id(Tablename,[{task_bag,id},{player,player_id}],0,L);
							task_consign -> update_id(Tablename,[{task_consign,id},{player,player_id}],0,L);
							task_log -> update_id(Tablename,[{task_log,id},{player,player_id}],0,L);
							user -> update_id(Tablename,[{user,id}],0,L);
							_ -> skip
						end
				end,
	[F1(Tablename)|| Tablename <- TableList];
	

%%批处理导入数据
start(5) ->
	Master_mongo1 = 
	case init_mongo(gateway) of
		{ok,Master_mongo} -> Master_mongo;
		_ -> []
	end,
	Slave_mongo1 = 
	case init_slave_mongo(gateway) of
		{ok,Slave_mongo} -> Slave_mongo;
		_ -> []
	end,
	if (Master_mongo1 =/= [] andalso Slave_mongo1 =/= []) ->
%% 	   TableList = lib_player_rw:get_all_tables(),
		   TableList = 
			   [
					arena,	
					arena_week,	
					box_scene,	
					cards,	
					carry,	
					consign_player,	
					consign_task,	
					daily_bless,	
					exc,	
					feedback,	
					fst_god,	
					goods,	
					goods_attribute,	
					goods_buff,	
					goods_cd,	
					guild,	
					guild_apply,	
					guild_invite,	
					guild_manor_cd,	
					guild_member,	
					guild_skills_attribute,	
					infant_ctrl_byuser,	
					log_backout,	
					log_box_open,	
					log_box_player,	
					log_box_throw,	
					log_compose,	
					log_consume,	
					log_dungeon,	
					log_employ,	
					log_exc,	
					log_exc_exp,	
					log_free_pet,	
					log_fst,	
					log_fst_mail,	
					log_guild,	
					log_hole,	
					log_icompose,	
					log_idecompose,	
					log_identify,	
					log_inlay,	
					log_linggen,	
					log_mail,	
					log_merge,	
					log_meridian,	
					log_pay,	
					log_practise,	
					log_quality_out,	
					log_quality_up,	
					log_refine,	
					log_sale,	
					log_sale_dir,	
					log_shop,	
					log_stren,	
					log_suitmerge,	
					log_throw,	
					log_trade,	
					log_uplevel,	
					log_use,	
					log_warehouse_flowdir,	
					log_wash,	
					login_prize,	
					mail,	
					master_apprentice,	
					master_charts,	
					meridian,	
					mon_drop_analytics,	
					offline_award,	
					online_award,	
					online_gift,	
					pet,	
					player,	
					player_buff,	
					player_donttalk,	
					player_hook_setting,	
					player_sys_setting,	
					relationship,	
					sale_goods,	
					skill,	
 					target_gift,	
					task_bag,	
					task_consign,	
					task_log,	
					user
			   ],
		   F = fun(Tablename) ->
						 ResultList = emongo:find_all(tool:to_list(Slave_mongo1),tool:to_list(Tablename),[],[]),
						 F = fun(R) ->
									 R1 = [({Key,Value}) || {Key,Value} <- R,Key =/= <<"_id">>],
									 Opertion = db_mongoutil:make_insert_opertion(R1),
									 emongo:insert(tool:to_list(Master_mongo1),tool:to_list(Tablename),Opertion) 
							 end,
						 [F(R) || R <- ResultList]
			   end,
		   [F(Tablename) || Tablename<- lists:reverse(TableList)];
	   true ->
		   skip
	end;


%%最后更新audo_ids的对应的id
start(6) ->
	update_ids();

%%合服后根据条件删除数据
start(7) ->
	ok.

%%更新角色名
update_name(Tablename, Field, WhereField) ->
	[Size] = db_mongo:select_count(Tablename, []),
	TotalPage = 
		if (Size div ?PageSize == 0) ->
			   Size div ?PageSize;
		   true ->
			   Size div ?PageSize +1
		end,	
	if (TotalPage =< 1) ->
		   NameList = db_mongo:select_all(Tablename, tool:to_list(WhereField)++","++tool:to_list(Field)),
		   F = fun(Name) ->
					   Name1 = tool:to_list(lists:nth(2,Name)),
					   case length(Name1) > 0 andalso Name1 =/= "[]" of
						   false -> skip;
						   true ->
							   Id1 = lists:nth(1,Name),
							   NewName = "【"++integer_to_list(?SN)++"】"++Name1,
							   db_mongo:update(Tablename, [{Field,NewName}], [{WhereField,Id1}])
					   end
			   end,
		   [F(Name) || Name <- NameList];
	   true ->
		   F = fun(Page) ->
					   Result = db_mongo:select_all(Tablename,tool:to_list(WhereField)++","++tool:to_list(Field), [],[{tool:to_list(WhereField),asc},{tool:to_list(Field),asc}],[?PageSize,(Page-1)*?PageSize]),
					   F = fun(Name) ->
								   Name1 = tool:to_list(lists:nth(2,Name)),
								   case length(Name1) > 0 andalso Name1 =/= "[]" of
									   false -> skip;
									   true ->
										   Id1 = lists:nth(1,Name),
										   NewName = "【"++integer_to_list(?SN)++"】"++Name1,
										   db_mongo:update(Tablename, [{Field,NewName}], [{WhereField,Id1}])
								   end
						   end,
					   [F(Name) || Name <- Result]					   
			   end,  
		   lists:foreach(F, lists:seq(1,TotalPage))
	end.


search_another_max_id() -> 
	%%先查出另服的ID最大值
	TableList = lib_player_rw:get_all_tables(),
	F = fun(Tablename) ->
						case Tablename of
							arena -> search_id(Tablename,[id]);
							arena_week -> search_id(Tablename,[id]);
							box_scene -> search_id(Tablename,[id]);
							cards -> search_id(Tablename,[id]);
							carry -> search_id(Tablename,[id]);
							consign_player -> search_id(Tablename,[id]);
							consign_task -> search_id(Tablename,[id]);
							daily_bless -> search_id(Tablename,[id]);
							exc -> search_id(Tablename,[id]);
							feedback -> search_id(Tablename,[id]);
							fst_god -> search_id(Tablename,[id]);
							goods -> search_id(Tablename,[id]);
							goods_attribute -> search_id(Tablename,[id]);
							goods_buff -> search_id(Tablename,[id]);
							goods_cd -> search_id(Tablename,[id]);
							guild -> search_id(Tablename,[id]);
							guild_apply -> search_id(Tablename,[id]);
							guild_invite -> search_id(Tablename,[id]);
							guild_manor_cd -> search_id(Tablename,[id]);
							guild_member -> search_id(Tablename,[id]);
							guild_skills_attribute -> search_id(Tablename,[id]);
							infant_ctrl_byuser -> search_id(Tablename,[id]);
							log_backout -> search_id(Tablename,[id]);
							log_box_open -> search_id(Tablename,[id]);
							log_box_player -> search_id(Tablename,[id]);
							log_box_throw -> search_id(Tablename,[id]);
							log_compose -> search_id(Tablename,[id]);
							log_consume -> search_id(Tablename,[id]);
							log_dungeon -> search_id(Tablename,[id]);
							log_employ -> search_id(Tablename,[id]);
							log_exc -> search_id(Tablename,[id]);
							log_exc_exp -> search_id(Tablename,[id]);
							log_free_pet -> search_id(Tablename,[id]);
							log_fst -> search_id(Tablename,[id]);
							log_fst_mail -> search_id(Tablename,[id]);
							log_guild -> search_id(Tablename,[id]);
							log_hole -> search_id(Tablename,[id]);
							log_icompose -> search_id(Tablename,[id]);
							log_idecompose -> search_id(Tablename,[id]);
							log_identify -> search_id(Tablename,[id]);
							log_inlay -> search_id(Tablename,[id]);
							log_linggen -> search_id(Tablename,[id]);
							log_mail -> search_id(Tablename,[id]);
							log_merge -> search_id(Tablename,[id]);
							log_meridian -> search_id(Tablename,[id]);
							log_pay -> search_id(Tablename,[id]);
							log_practise -> search_id(Tablename,[id]);
							log_quality_out -> search_id(Tablename,[id]);
							log_quality_up -> search_id(Tablename,[id]);
							log_refine -> search_id(Tablename,[id]);
							log_sale -> search_id(Tablename,[id]);
							log_sale_dir -> search_id(Tablename,[id]);
							log_shop -> search_id(Tablename,[id]);
							log_stren -> search_id(Tablename,[id]);
							log_suitmerge -> search_id(Tablename,[id]);
							log_throw -> search_id(Tablename,[id]);
							log_trade -> search_id(Tablename,[id]);
							log_uplevel -> search_id(Tablename,[id]);
							log_use -> search_id(Tablename,[id]);
							log_warehouse_flowdir -> search_id(Tablename,[id]);
							log_wash -> search_id(Tablename,[id]);
							login_prize -> search_id(Tablename,[id]);
							mail -> search_id(Tablename,[id]);
							master_apprentice -> search_id(Tablename,[id]);
							master_charts -> search_id(Tablename,[id]);
							meridian -> search_id(Tablename,[id]);
							mon_drop_analytics -> search_id(Tablename,[id]);
							offline_award -> search_id(Tablename,[id]);
							online_award -> search_id(Tablename,[id]);
							online_gift -> search_id(Tablename,[id]);
							pet -> search_id(Tablename,[id]);
							player -> search_id(Tablename,[id]);
							player_buff -> search_id(Tablename,[id]);
							player_donttalk -> search_id(Tablename,[player_id]);
							player_hook_setting -> search_id(Tablename,[id]);
							player_sys_setting -> search_id(Tablename,[id]);
							relationship -> search_id(Tablename,[id]);
							sale_goods -> search_id(Tablename,[id]);
							skill -> search_id(Tablename,[id]);
							target_gift -> search_id(Tablename,[id]);
							task_bag -> search_id(Tablename,[id]);
							task_consign -> search_id(Tablename,[id]);
							task_log -> search_id(Tablename,[id]);
							user -> search_id(Tablename,[id]);
							_ -> search_id([],[])
						end
				end,
	L = 	[F(Tablename)|| Tablename <- TableList],
	%% 查询有记录的表及主键
	[R|| R <- L,R =/= {}].

%%查询表最大的主键
search_id(Tablename, FieldList) ->
	case Tablename =/= [] of
		false -> {};
		_ ->
			FieldString = util:list_to_string(FieldList),
			MaxId = db_mongo:select_one_new(tool:to_list(?SLAVE_POOLID), Tablename, FieldString,[],[{FieldString,desc}],[1]),
			case MaxId of
				undefined -> {};
				null -> {};
				_ -> {Tablename,MaxId+1}
			end
	end.
	
update_id(Tablename, FieldList, CheckExist, TablesMaxIdList) ->
%% FieldString = util:list_to_string(FieldList),
	case CheckExist of
		0 ->
			F = fun(AnotherTable,Field) ->
						case lists:keysearch(AnotherTable,1,TablesMaxIdList) of
							false -> {};
							{value,{AnotherTable,MaxId}} ->
								{Field,MaxId,add}
						end
				end,			
			FieldList1 = [F(AnotherTable,Field) || {AnotherTable,Field} <- FieldList],
			FieldList2 = [FieldValue || FieldValue <- FieldList1,FieldValue =/= {}],
			db_mongo:update(Tablename, FieldList2, []);
		1 ->
			FieldList1 =  [(Field) || {_AnotherTable,Field} <- FieldList],
			FieldList2 =  util:list_to_string(FieldList1),
			ResultList = db_mongo:select_all(Tablename,FieldList2),
			F = fun(Record) -> 
						FieldTh = [N1||N1 <- lists:seq(1, length(Record)),lists:nth(N1, Record) > 0,lists:nth(N1, Record) =/= undefined],
						F1 = fun(N2) ->
									 OldValue1 = lists:nth(N2,Record),
									 Field1 = lists:nth(N2,FieldList1),
									 F2 = fun() ->
												  [AnotherTableName2] = [AnotherTable2 || {AnotherTable2,Field2} <- FieldList,Field1 == Field2],
												  case lists:keyfind(AnotherTableName2,1,TablesMaxIdList) of
													  false -> 0;
													  {_,MaxId} -> MaxId
												  end										  
										  end,
									 AnotherValue = F2,
									 {Field1,AnotherValue+OldValue1}
							 end,
						FieldString1 = [F1(N2) || N2 <- FieldTh],
						Where1 = [{lists:nth(1,FieldList1),lists:nth(1,Record)}],
						db_mongo:update(Tablename, FieldString1, Where1)
				end,			
			[F(Record) || Record <- ResultList];
		_ -> skip
	end.

update_ids() ->
	AutoIdsList = emongo:find_all(tool:to_list(?MASTER_POOLID),tool:to_list(auto_ids),[],["id,name,mid,counter,kid,gid,uid,num,level"]),
	F = fun(Result) ->
				{_E1,Value1} = lists:nth(1, Result),
				{_E2,Value2} = lists:nth(2, Result),
				case tool:to_atom(tool:to_list(Value1)) of
					master_apprentice -> update_ids(master_apprentice,[id]);
					mon_drop_analytics -> update_ids(mon_drop_analytics,[id]);
					online_gift -> update_ids(online_gift,[id]);
					player_buff -> update_ids(player_buff,[id]);
					player_hook_setting -> update_ids(player_hook_setting,[id]);
					relationship -> update_ids(relationship,[id]);
					sale_goods -> update_ids(sale_goods,[id]);
					stc_create_page -> update_ids(stc_create_page,[id]);
					system_config -> update_ids(system_config,[id]);
					target_gift -> update_ids(target_gift,[id]);
					user -> update_ids(user,[id]);
					task_bag -> update_ids(task_bag,[id]);
					task_log -> update_ids(task_log,[id]);
					skill -> update_ids(skill,[id]);
					player_sys_setting -> update_ids(player_sys_setting,[id]);
					realm_1 -> update_realm(player,[1]);
					realm_2 -> update_realm(player,[2]);
					realm_3 -> update_realm(player,[3]);
					log_box_player -> update_ids(log_box_player,[id]);
					dungeon_id -> update_dungeon_id(log_dungeon,[dungeon_id]);
					log_dungeon -> update_ids(log_dungeon,[id]);
					exc -> update_ids(exc,[id]);
					daily_bless -> update_ids(daily_bless,[id]);
					log_exc_exp -> update_ids(log_exc_exp,[id]);
					arena -> update_ids(arena,[id]);
					cards -> update_ids(cards,[id]);
					feedback -> update_ids(feedback,[id]);
					goods -> update_ids(goods,[id]);
					goods_attribute -> update_ids(goods_attribute,[id]);
					goods_buff -> update_ids(goods_buff,[id]);
					goods_cd -> update_ids(goods_cd,[id]);
					guild -> update_ids(guild,[id]);
					guild_apply -> update_ids(guild_apply,[id]);
					guild_invite -> update_ids(guild_invite,[id]);
					guild_member -> update_ids(guild_member,[id]);
					guild_skills_attribute -> update_ids(guild_skills_attribute,[id]);
					log_backout -> update_ids(log_backout,[id]);
					log_box_open -> update_ids(log_box_open,[id]);
					log_compose -> update_ids(log_compose,[id]);
					log_consume -> update_ids(log_consume,[id]);
					log_exc -> update_ids(log_exc,[id]);
					log_guild -> update_ids(log_guild,[id]);
					log_hole -> update_ids(log_hole,[id]);
					log_identify -> update_ids(log_identify,[id]);
					log_inlay -> update_ids(log_inlay,[id]);
					log_merge -> update_ids(log_merge,[id]);
					log_meridian -> update_ids(log_meridian,[id]);
					log_pay -> update_ids(log_pay,[id]);
					log_practise -> update_ids(log_practise,[id]);
					log_quality_out -> update_ids(log_quality_out,[id]);
					log_quality_up -> update_ids(log_quality_up,[id]);
					log_sale -> update_ids(log_sale,[id]);
					log_shop -> update_ids(log_shop,[id]);
					log_stren -> update_ids(log_stren,[id]);
					log_trade -> update_ids(log_trade,[id]);
					log_uplevel -> update_ids(log_uplevel,[id]);
					log_use -> update_ids(log_use,[id]);
					log_wash -> update_ids(log_wash,[id]);
					login_prize -> update_ids(login_prize,[id]);
					mail -> update_ids(mail,[id]);
					master_charts -> update_ids(master_charts,[id]);
					meridian -> update_ids(meridian,[id]);
					pet -> update_ids(pet,[id]);
					player -> update_ids(player,[id]);
					stc_min -> update_ids(stc_min,[id]);
					sys_acm -> update_ids(sys_acm,[id]);
					test -> update_ids(test,[id]);
					log_suitmerge -> update_ids(log_suitmerge,[id]);
					infant_ctrl_byuser -> update_ids(infant_ctrl_byuser,[id]);
					log_mail -> update_ids(log_mail,[id]);
					log_throw -> update_ids(log_throw,[id]);
					task_consign -> update_ids(task_consign,[id]);
					log_free_pet -> update_ids(log_free_pet,[id]);
					guild_manor_cd -> update_ids(guild_manor_cd,[id]);
					log_sale_dir -> update_ids(log_sale_dir,[id]);
					log_warehouse_flowdir -> update_ids(log_warehouse_flowdir,[id]);
					arena_week -> update_ids(arena_week,[id]);
					carry -> update_ids(carry,[id]);
					consign_player -> update_ids(consign_player,[id]);
					log_linggen -> update_ids(log_linggen,[id]);
					_ ->skip
				end,
				case tool:to_atom(tool:to_list(Value2)) of
					master_apprentice -> update_ids(master_apprentice,[id]);
					mon_drop_analytics -> update_ids(mon_drop_analytics,[id]);
					online_gift -> update_ids(online_gift,[id]);
					player_buff -> update_ids(player_buff,[id]);
					player_hook_setting -> update_ids(player_hook_setting,[id]);
					relationship -> update_ids(relationship,[id]);
					sale_goods -> update_ids(sale_goods,[id]);
					stc_create_page -> update_ids(stc_create_page,[id]);
					system_config -> update_ids(system_config,[id]);
					target_gift -> update_ids(target_gift,[id]);
					user -> update_ids(user,[id]);
					task_bag -> update_ids(task_bag,[id]);
					task_log -> update_ids(task_log,[id]);
					skill -> update_ids(skill,[id]);
					player_sys_setting -> update_ids(player_sys_setting,[id]);
					realm_1 -> update_realm(player,[1]);
					realm_2 -> update_realm(player,[2]);
					realm_3 -> update_realm(player,[3]);
					log_box_player -> update_ids(log_box_player,[id]);
					dungeon_id -> update_dungeon_id(log_dungeon,[dungeon_id]);
					log_dungeon -> update_ids(log_dungeon,[id]);
					exc -> update_ids(exc,[id]);
					daily_bless -> update_ids(daily_bless,[id]);
					log_exc_exp -> update_ids(log_exc_exp,[id]);
					arena -> update_ids(arena,[id]);
					cards -> update_ids(cards,[id]);
					feedback -> update_ids(feedback,[id]);
					goods -> update_ids(goods,[id]);
					goods_attribute -> update_ids(goods_attribute,[id]);
					goods_buff -> update_ids(goods_buff,[id]);
					goods_cd -> update_ids(goods_cd,[id]);
					guild -> update_ids(guild,[id]);
					guild_apply -> update_ids(guild_apply,[id]);
					guild_invite -> update_ids(guild_invite,[id]);
					guild_member -> update_ids(guild_member,[id]);
					guild_skills_attribute -> update_ids(guild_skills_attribute,[id]);
					log_backout -> update_ids(log_backout,[id]);
					log_box_open -> update_ids(log_box_open,[id]);
					log_compose -> update_ids(log_compose,[id]);
					log_consume -> update_ids(log_consume,[id]);
					log_exc -> update_ids(log_exc,[id]);
					log_guild -> update_ids(log_guild,[id]);
					log_hole -> update_ids(log_hole,[id]);
					log_identify -> update_ids(log_identify,[id]);
					log_inlay -> update_ids(log_inlay,[id]);
					log_merge -> update_ids(log_merge,[id]);
					log_meridian -> update_ids(log_meridian,[id]);
					log_pay -> update_ids(log_pay,[id]);
					log_practise -> update_ids(log_practise,[id]);
					log_quality_out -> update_ids(log_quality_out,[id]);
					log_quality_up -> update_ids(log_quality_up,[id]);
					log_sale -> update_ids(log_sale,[id]);
					log_shop -> update_ids(log_shop,[id]);
					log_stren -> update_ids(log_stren,[id]);
					log_trade -> update_ids(log_trade,[id]);
					log_uplevel -> update_ids(log_uplevel,[id]);
					log_use -> update_ids(log_use,[id]);
					log_wash -> update_ids(log_wash,[id]);
					login_prize -> update_ids(login_prize,[id]);
					mail -> update_ids(mail,[id]);
					master_charts -> update_ids(master_charts,[id]);
					meridian -> update_ids(meridian,[id]);
					pet -> update_ids(pet,[id]);
					player -> update_ids(player,[id]);
					stc_min -> update_ids(stc_min,[id]);
					sys_acm -> update_ids(sys_acm,[id]);
					test -> update_ids(test,[id]);
					log_suitmerge -> update_ids(log_suitmerge,[id]);
					infant_ctrl_byuser -> update_ids(infant_ctrl_byuser,[id]);
					log_mail -> update_ids(log_mail,[id]);
					log_throw -> update_ids(log_throw,[id]);
					task_consign -> update_ids(task_consign,[id]);
					log_free_pet -> update_ids(log_free_pet,[id]);
					guild_manor_cd -> update_ids(guild_manor_cd,[id]);
					log_sale_dir -> update_ids(log_sale_dir,[id]);
					log_warehouse_flowdir -> update_ids(log_warehouse_flowdir,[id]);
					arena_week -> update_ids(arena_week,[id]);
					carry -> update_ids(carry,[id]);
					consign_player -> update_ids(consign_player,[id]);
					log_linggen -> update_ids(log_linggen,[id]);
					_ ->skip
				end
		end,
	[F(lists:nthtail(1,AutoIds)) ||AutoIds <- AutoIdsList].

update_ids(Tablename, FieldList) ->
	FieldString = util:list_to_string(FieldList),
	MaxId = db_mongo:select_one(Tablename, FieldString,[],[{FieldString,desc}],[1]),
	MaxId1 = 
		case MaxId of
			null -> 0;
			_ -> MaxId
		end,
	MaxId2 = 
	case Tablename of
		user -> 
			[UserCount] = db_mongo:select_count(Tablename, []),
			if UserCount > MaxId1 ->
				   UserCount;
			   true -> 
				   MaxId1
			end;
		_ -> 
			MaxId1
	end,
	db_mongo:update("auto_ids", [{FieldString,MaxId2}], [{name,Tablename}]).

update_realm(Tablename,NumList) ->
	Realm = lists:nth(1,NumList),
	[Total] = db_mongo:select_count(Tablename, [{realm,Realm}]),
	Realm_Num = lists:concat(["realm_",Realm]),
	db_mongo:update("auto_ids", [{num,Total}], [{name,Realm_Num}]).

update_dungeon_id(_Tablename,FieldList) ->
	FieldString = util:list_to_string(FieldList),
	Total = db_agent:sum(log_dungeon,"dungeon_counter",[]),
	db_mongo:update("auto_ids", [{counter,Total}], [{name,FieldString}]).


%%角色更名(相同角色名，等级高的保持不变，等级低的前面加上服号)
updata_player_name() ->
	AllNameData1 = db_mongo:select_all(player, "nickname", [{id,">",0}]),
	%%除重
	AllNameData2 = lists:usort(AllNameData1),
	%%得到重复角色名列表
	Data = 
		case AllNameData1 == AllNameData2 of
			true -> [];
			false ->
				AllNameData1 -- AllNameData2
		end,
	if 
		Data == [] ->
			skip;
		%%重复角色名不为空
		true ->
			F = fun(Nickname0) ->
					Data1 = db_mongo:select_all(player, "id,nickname,lv,sn", [{id,">",0},{nickname,Nickname0}],[{lv,desc}],[]),
					%%除去等级最大的一个角色名
					F1 = fun(Id, Nickname, _Lv, Sn) ->
								 Nickname2 = lists:concat(["【",Sn,"】",binary_to_list(Nickname)]),
								 %%更新角色名
								 db_mongo:update(player, [{nickname,Nickname2}], [{id,Id}]),
								 %%更新帮派角色名
								 db_mongo:update(guild, [{chief_name,Nickname2}], [{chief_id,Id}]),
								 %%更新帮派角色名
								 db_mongo:update(guild, [{deputy_chief1_name,Nickname2}], [{deputy_chief1_id,Id}]),
								 %%更新帮派角色名
								 db_mongo:update(guild, [{deputy_chief2_name,Nickname2}], [{deputy_chief2_id,Id}]),
								 %%更新帮派成员角色名
								 db_mongo:update(guild_member, [{player_nam,Nickname2}], [{player_id,Id}]),
								 %%更新充值角色名
								 db_mongo:update(log_pay, [{nickname,Nickname2}], [{player_id,Id}]),
								 %%更新邮件角色名(sname是发件人名字,如系统,uid是收件人id)
								 %%db_mongo:update(mail, [{sname,Nickname2}], [{uid,Id}]),
								 %%更新师徒关系角色名
								 db_mongo:update(master_apprentice, [{apprentenice_name,Nickname2}], [{apprentenice_id,Id}]),
								 %%更新伯乐榜角色名
								 db_mongo:update(master_charts, [{master_name,Nickname2}], [{master_id,Id}]),
								 %%记录改名日志
								 Nowtime = util:unixtime(),
								 ?DB_MODULE:insert(log_change_name,[pid, nickname, type, send, ct], [Id, Nickname2, 1, 0, Nowtime])
						 end,
					[F1(Id1, Nickname1, Lv1, Sn1)|| [Id1, Nickname1, Lv1, Sn1] <- lists:sublist(Data1, 2, length(Data1)-1)]
				end,					
			[F(Nickname0) || Nickname0 <- lists:usort(Data)]
	end,
	%%处理合服玩家称号的问题
	update_titles(),
	ok.

%%帮派更名(相同帮派名，等级高的保持不变，等级低的前面加上服号)
updata_guild_name() ->
	AllNameData1 = db_mongo:select_all(guild, "name", [{id,">",0}]),
	%%除重
	AllNameData2 = lists:usort(AllNameData1),
	%%得到重复帮派名列表
	Data = 
		case AllNameData1 == AllNameData2 of
			true -> [];
			false ->
				AllNameData1 -- AllNameData2
		end,
	if 
		Data == [] ->
			skip;
		%%重复角色名不为空
		true ->
			F = fun(Name0) ->
						Data1 = db_mongo:select_all(guild, "id,chief_id,name,level", [{id,">",0},{name,Name0}],[{level,desc}],[]),
						%%除去等级最大的一个角色名
						F1 = fun(Id, Chief_id, Name, _Level) ->
								 SnAndNickname = ?DB_MODULE:select_row(player, "sn,nickname", [{id, Chief_id}]),	
								 if SnAndNickname =/= [] ->
										[Sn,Nickname] = SnAndNickname,
										Name2 = lists:concat(["【",Sn,"】",binary_to_list(Name)]),
										%%更新角色帮派名
										db_mongo:update(guild, [{name,Name2}], [{id,Id}]),
										%%更新帮派成员帮派名
										db_mongo:update(guild_member, [{guild_name,Name2}], [{guild_id,Id}]),
										%%更新角色的帮派名
										db_mongo:update(player, [{guild_name,Name2}], [{guild_id,Id}]),
										%%更新帮派联盟名
										db_mongo:update(guild_alliance, [{bname,Name2}], [{bgid,Id}]),
										%%记录改名日志
										Nowtime = util:unixtime(),
										db_mongo:insert(log_change_name,[pid, nickname, type, send, ct], [Chief_id, binary_to_list(Nickname), 2, 0, Nowtime]);
									true ->
										io:format("Id, Chief_id is ~p/~p/~n",[Id, Chief_id]),
										skip
								 end
								 end,
					[F1(Id1, Chief_id1, Name1, Level1)|| [Id1, Chief_id1, Name1, Level1] <- lists:sublist(Data1, 2, length(Data1)-1)]
				end,			
			[F(Name0) || Name0 <- lists:usort(Data)]
	end,	
	ok.

%%帮派更名(相同帮派名，等级高的保持不变，等级低的前面加上服号)
updata_guild_id() ->
	AllNameData = db_mongo:select_all(guild, "id,name,chief_id,chief_name", [{id,">",0}],[{id,desc}],[]),
	F = fun(Guild_Id,GuildName,OldPlayer_Id,Nickname) ->
				NewGuildIdList = ?DB_MODULE:select_row(player, "id,guild_id", [{nickname, Nickname}]),
				if NewGuildIdList == [] ->
					   io:format("Guild_Id player is not found is ~p/~p~n",[Guild_Id,Nickname]);
				   true ->
					   [PlayerId,NewGuildId] = NewGuildIdList,
					   if NewGuildId == Guild_Id ->
							  skip;
						  true ->
							  io:format("Guild_Id,NewGuildId,OldPlayer_Id,PlayerId UPDATE  is ~p/~p/~p/~p~n",[Guild_Id,NewGuildId,OldPlayer_Id,PlayerId]),
							  db_mongo:update(guild, [{id,NewGuildId}], [{name,GuildName}])
					   end
				end
		end,
	[F(Guild_Id,GuildName,OldPlayer_Id,Nickname) ||[Guild_Id,GuildName,OldPlayer_Id,Nickname] <- AllNameData],
	ok.

%%合服后更新帮派人数
updata_guild_member_sum() ->
	AllData = db_mongo:distinct(guild_member,"guild_id"),
	F = fun(Guild_Id) ->
				[Sum] = db_mongo:select_count(guild_member,[{guild_id,Guild_Id}]),
				db_mongo:update(guild, [{member_num,Sum}], [{id,Guild_Id}])
		end,
	[F(Guild_Id) ||Guild_Id <- AllData],
	ok.

%%合服后系统启动10分钟再操作,一次发放所有的角色更名符和帮派天地符
send_change_name_symbol() ->
	Data = db_mongo:select_all(log_change_name, "id, pid, nickname, type, send, ct", [{id,">",0}],[],[]),
	F =  fun(Id, _Pid, Nickname, Type, Send, _Ct) ->
				 case Send of
					 %%未发邮件
					 0 ->
						 case Type of
							 1 ->
								 Content = "【角色更名符】",
 								 lib_goods:add_new_goods_by_mail(tool:to_list(Nickname),28040,1,1,"系统信件",Content),
								 db_mongo:update(log_change_name,[{send,1}],[{id,Id}]);
							 2 ->
								 Content = "【氏族更名符】",
 								 lib_goods:add_new_goods_by_mail(tool:to_list(Nickname),28304,1,1,"系统信件",Content),
								 db_mongo:update(log_change_name,[{send,1}],[{id,Id}]);
							 _ -> 
								 skip
						 end;
					 _ ->
						 skip
				 end		 
		 end,
	[F(Id, Pid, Nickname, Type, Send, Ct) || [Id, Pid, Nickname, Type, Send, Ct] <- Data].
	

%%合服后市场挂售物品没有下架处理,此方法用来发放邮件物品
send_sale_back_goods() ->
	Type = 1,
	Content = io_lib:format("合服前您挂售的物品，系统已退回,请取回附件!",[]),
	SName = "系统",
    Title = "退回附件",
	Timestamp = util:unixtime(),
	%%插入新信件
	AllGoods = [
				[ {"id" , 191624}, {"sale_type" , 1}, {"goods_id" , 15007}, {"player_id" , 118812}, {"player_name" , "泪无痕丶"}, {"num" , 1}],
				[ {"id" , 191626}, {"sale_type" , 1}, {"goods_id" , 25304}, {"player_id" , 102279}, {"player_name" , "婉然"} , {"num" , 1}] ,
				[ {"id" , 191631}, {"sale_type" , 1}, {"goods_id" , 11170}, {"player_id" , 102279}, {"player_name" , "婉然"}, {"num" , 1}],
				[ {"id" , 191643}, {"sale_type" , 1}, {"goods_id" , 10048}, {"player_id" , 118466}, {"player_name" , "轩辕芷天"}, {"num" , 1}],
				[ {"id" , 191654}, {"sale_type" , 1}, {"goods_id" , 11180}, {"player_id" , 122125}, {"player_name" , "淡忘yi切"}, {"num" , 1}],
				[ {"id" , 191692}, {"sale_type" , 1}, {"goods_id" , 11157}, {"player_id" , 122831}, {"player_name" , "姬武明"}, {"num" , 1 }],
				[ {"id" , 191695}, {"sale_type" , 1}, {"goods_id" , 12140}, {"player_id" , 40484},  {"player_name" , "姬夜雪"}, {"num" , 1}],
				[ {"id" , 191700}, {"sale_type" , 1}, {"goods_id" , 14134}, {"player_id" , 122831}, {"player_name" , "姬武明"}, {"num" , 1}],
				[ {"id" , 191713}, {"sale_type" , 1}, {"goods_id" , 14133}, {"player_id" , 122831}, {"player_name" , "姬武明"}, {"num" , 1}],
				[ {"id" , 191716}, {"sale_type" , 1}, {"goods_id" , 11007}, {"player_id" , 40484},  {"player_name" , "姬夜雪"}, {"num" , 1}],
				[ {"id" , 191718}, {"sale_type" , 1}, {"goods_id" , 12007}, {"player_id" , 40484},  {"player_name" , "姬夜雪"} , {"num" , 1}],
				[ {"id" , 191719}, {"sale_type" , 1}, {"goods_id" , 11139}, {"player_id" , 40484},  {"player_name" , "姬夜雪"} , {"num" , 1}],
				[ {"id" , 191720}, {"sale_type" , 1}, {"goods_id" , 13151}, {"player_id" , 122831}, {"player_name" , "姬武明"}, {"num" , 1}],
				[ {"id" , 191722}, {"sale_type" , 1}, {"goods_id" , 25304}, {"player_id" , 122831}, {"player_name" , "姬武明"}, {"num" , 1}],
				[ {"id" , 191725}, {"sale_type" , 1}, {"goods_id" , 26000}, {"player_id" , 118851}, {"player_name" , "轩辕寒天"}, {"num" , 99}],
				[ {"id" , 191726}, {"sale_type" , 1}, {"goods_id" , 11156}, {"player_id" , 40484},  {"player_name" , "姬夜雪"}, {"num" , 1}],
				[ {"id" , 191728}, {"sale_type" , 1}, {"goods_id" , 13131}, {"player_id" , 40484},  {"player_name" , "姬夜雪"} , {"num" , 1}],
				[ {"id" , 191763}, {"sale_type" , 1}, {"goods_id" , 15132}, {"player_id" , 122831}, {"player_name" , "姬武明"}, {"num" , 1}],
				[ {"id" , 191765}, {"sale_type" , 1}, {"goods_id" , 12132}, {"player_id" , 122831}, {"player_name" , "姬武明"}, {"num" , 1}]
				],
	F =  fun(Player_id,Sale_type,Goods_id,Num) ->
				 case Sale_type of
					 1 ->
						 lib_mail:insert_mail(Type, Timestamp, SName, Player_id, Title, Content, 0, Goods_id, Num, 0, 0);
					 _ -> skip
				end						 
		 end,
	[F(Player_id,Sale_type,Goods_id,Num) || [{_,_},{_,Sale_type},{_,Goods_id},{_,Player_id},{_,_},{_,Num}] <- AllGoods],
	ok.

%%恢复镇妖台的功勋
restore_td()  ->
	List = db_mongo:select_all(td_single1,"*",[],[],[]),
	case List of
		[] ->
			skip;
		_ ->
			F = fun(Td_single) ->
						[Att_num,_Id,G_name,Nick,Career,Realm,_Uid,Hor_td,Mgc_td,Hor_ttl] = Td_single,
						List2 = db_mongo:select_all(player,"id",[{nickname,Nick}]),
						case List2 of
							[] ->
								%%此用户名不存在
								skip;
							_ ->
								[Player_id] = lists:nth(1, List2),
								List3 = db_agent:get_td_single(Player_id),
								case List3 of
									[] ->
										%%在td_single中没有该角色的数据,插入处理
										db_agent:add_td_single(Att_num, G_name, Nick, Career, Realm, Player_id, Hor_td, Mgc_td, Hor_ttl),
										ok;
									_ ->
										%%在td_single中有该角色的数据,更新处理
										[Att_num1, Hor_td1, Mgc_td1, Hor_ttl1] = List3,
										Att_num2 =
											case Att_num >= Att_num1 of
												true ->
													Att_num;
												_ ->
													Att_num1
											end,
										Hor_td2 = 
											case (Hor_td+Hor_td1) >= 16156 of
												true -> 16156;
												_ -> (Hor_td+Hor_td1)
											end,
										db_agent:update_td_single(Att_num2, G_name, Hor_td2, (Mgc_td+Mgc_td1), (Hor_ttl+Hor_ttl1), Player_id)
								end
						end
				end,						
			[F(Td_single) || Td_single <- List]
	end.


%%发放氏族仓库合服2服丢失物品
send_guild_goods(Sn) ->
	Type = 1,
	Content = io_lib:format("合服前您氏族仓库的物品，系统已退回,请取回附件!",[]),
	SName = "系统",
    Title = "退回附件",
	Timestamp = util:unixtime(),
	GuildList = db_mongo:select_all(lists:concat([goods,Sn]),"equip_type,goods_id",[{equip_type,">",0},{location,8}]),
	case GuildList of
		[] ->
			io:format("guild goods is empty"),
			skip;
		_ ->
			F = fun(GuildGood) ->
						[Guild_Id,Goods_Id] = GuildGood,
						GuildName = db_mongo:select_one(lists:concat([guild,Sn]),"name",[{id,Guild_Id}]),
						case GuildName of
							null ->
								skip;
							_ ->
								GuildInfoList = db_mongo:select_row(guild,"id,chief_id",[{name,GuildName}]),
								case GuildInfoList of
									[] ->
										skip;
									_ ->
										[_NewGuild_Id,Chief_id] = GuildInfoList,
										lib_mail:insert_mail(Type, Timestamp, SName, Chief_id, Title, Content, 0, Goods_Id, 1, 0, 0)
								end
						end
				end,			
			[F(GuildGood) || GuildGood <- GuildList]
	end,
	ok.


%%统计两个时间段内玩家的升级级差和角色id
%%8月1日等级大于29级的玩家，9月1日算出这些玩家的升级级差
%%返回数据写入到文件result.txt
get_player_lv_diff(Time1,Time2) ->
	Result1 = db_mongo:select_all(log_mongo,log_uplevel,"player_id,lv",[{time,"<=",Time1}],[],[]),
	Result2 = loop_result(Result1,[]),
	Idlist2 = [Player_Id2 || {Player_Id2,_Lv2} <- Result2], 
	NicknameList1 = db_mongo:select_all(player,"id,nickname",[{id,"in",Idlist2}],[],[]),
	NicknameList2 = [{Player_Id3,Nickname3} || [Player_Id3,Nickname3] <- NicknameList1],
	Result3 = db_mongo:select_all(log_mongo,log_uplevel,"player_id,lv",[{player_id,"in",Idlist2},{time,"<=",Time2}],[],[]),
	Result4 = loop_result(Result3,[]),
	F = fun(Player_Id,Level) ->
				case lists:keyfind(Player_Id, 1, NicknameList2) of
					false -> 
						Nickname = <<>>;
					{Player_Id,Nickname} ->
						Nickname
				end,					
				case lists:keyfind(Player_Id, 1, Result4) of
					false -> 
						{Player_Id,0,0,0,Nickname};
					{Player_Id,NewLevel} ->
						{Player_Id,abs(NewLevel- Level),NewLevel,Level,Nickname}
				end
		end,
	Result = [F(Player_Id,Level) || {Player_Id,Level} <- Result2],
	Result5 = [{Player_Id5,LevelDiff5,NewLevel5,Level5,Nickname5}||{Player_Id5,LevelDiff5,NewLevel5,Level5,Nickname5}  <- Result,LevelDiff5 > 0],
	write(Result5).

%%查询所有角色的id,lv,nickname
get_player_id_nickname() ->
	Result1 = db_mongo:select_all(player,"id,lv,nickname",[{id,">",0}],[],[]),
	Result2 = [{Player_Id,Lv,Lv,Lv,Nickname} || [Player_Id,Lv,Nickname] <- Result1],
	write(Result2).
	
%%除重并取等级最大值
loop_result([] ,ResultList) ->
	ResultList;
loop_result([H | Rest] ,ResultList) ->
	[PlayerId ,Lv] = H,
	case lists:keyfind(PlayerId, 1, ResultList) of
		false ->
			loop_result(Rest, [{PlayerId ,Lv} | ResultList]);
		{PlayerId1 ,Lv1} ->
			if 
				Lv > Lv1 ->
					loop_result(Rest, lists:keyreplace(PlayerId1, 1, ResultList, {PlayerId ,Lv}));
				true ->
					loop_result(Rest,ResultList)
			end
	end.
	
%%写结果到文件
write(Result) ->
	case Result of
		[] -> skip;
		_ ->
			File = lists:concat(["../logs/result",".txt"]),
			file:write_file(File, ""),
			file:write_file(File, ""),
			file:write_file(File, "角色Id----等级差--- 最高等级----最低等级----角色名----------\t\n",[append]),
			lists:foreach(fun({Player_Id,LevelDiff,HighLevel,LowLevel,Nickname}) ->
					Bytes = io_lib:format("~p	  ~p	 ~p, ~p  ~s \t\n",[Player_Id,LevelDiff,HighLevel,LowLevel,tool:to_list(Nickname)]),
					file:write_file(File, Bytes,[append])			  
				  end, 
				  Result)
	end.

%%更新一个表的id,按时间从小到大产生id
update_id() ->
	Result1 = db_mongo:select_all(log_pay,"id,insert_time,pay_num,",[{id,">=",0}],[{insert_time,asc}],[]),
	case Result1 of
		[] -> skip;
		_ ->
			F = fun(IdNum) ->
						[_OldId,Insert_time,Pay_num] = lists:nth(IdNum, Result1),
						?DB_MODULE:update(log_pay, [{id, IdNum}], [{insert_time,Insert_time},{pay_num, Pay_num}])
				end,						
			[F(IdNum) || IdNum <- lists:seq(1, length(Result1))]
	end.

update_player_id(TableName) ->
	Result1 = db_mongo:select_all(TableName,"nickname",[{id,">=",0}],[{insert_time,asc}],[]),
	case Result1 of
		[] -> skip;
		_ ->
			F = fun(Nickname) ->
						PlayerIdList = db_mongo:select_row(player,"id",[{nickname,Nickname}],[],[]),
						if
							PlayerIdList == [] ->
								skip;
							true ->
								[Player_Id|_] = PlayerIdList, 
								?DB_MODULE:update(TableName, [{player_id, Player_Id}], [{nickname, Nickname}])
						end
				end,						
			[F(Nickname) || [Nickname] <- Result1]
	end.

%%获取感恩节活动的 玩家数据
thanksgiving_data(Sn) ->
	Name1 = lists:concat(["jingmaibaohufu_", Sn]),
	get_thanksgiving_data(Name1, 4, "经脉保护符领取数量 "),
	Name2 = lists:concat(["Pumpkin_", Sn]),
	get_thanksgiving_data(Name2, 5, "南瓜馅饼领取数量").

get_thanksgiving_data(SnName, Type, TypeName) ->
	%%获取数据
	Result1 = db_mongo:select_all(mid_award, "pid, got", [{id, ">", 0}, {got, ">", 0}, {type, Type}], [], []),
	case Result1 of
		[] ->
			skip;
		_ ->
			%%获取人名
			Result2 = lists:foldl(fun([EId, EGot], AccIn) ->
										  case db_mongo:select_one(player, "nickname", [{id,EId}], [],[1]) of
											  null ->
												  AccIn;
											  ENickName ->
												  [{ENickName, EId, EGot}|AccIn]
										  end
								  end, [], Result1),
			%%写文件
			File = lists:concat(["../logs/", SnName, ".txt"]),
			file:write_file(File, ""),
			file:write_file(File, ""),
			file:write_file(File, "角色名----角色Id----",[append]),
			file:write_file(File, TypeName,[append]),
			file:write_file(File, "\t\n",[append]),
			lists:foreach(fun({Nickname, PlayerId, GotNum}) ->
					Bytes = io_lib:format("~s	  ~p	 ~p\t\n",[tool:to_list(Nickname), PlayerId, GotNum]),
					file:write_file(File, Bytes,[append])			  
				  end, 
				  Result2)
	end.

%%清除合服造成玩家称号多个的数据
update_titles() ->
	List = db_mongo:select_all(server_titles, "type, pid", [{type, ">", 0}], [], []),
	lists:foreach(fun(Elem) ->
						  [TNum, Pid] = Elem,
						  FieldList = "ptitle, ptitles",
						  WhereList = [{pid, Pid}],
						  case db_mongo:select_row(player_other, FieldList, WhereList, [], [1]) of
							  [] ->%%没这个人，没劲
								  skip;
							  [UTStr, GTStr] ->
								  OGTitles = util:string_to_term(tool:to_list(GTStr)),
								  if 
									  is_list(OGTitles) ->
										  GT = OGTitles;
									  true ->
										  GT = []
								  end,
								  UT = 
									  if
										  is_integer(UTStr) ->
											  case UTStr =:= 0 of
												  true ->
													  [];
												  false ->
													  [UTStr]
											  end;
										  true ->
											  OUTitle = util:string_to_term(tool:to_list(UTStr)),
											  if
												  is_list(OUTitle) ->
													  OUTitle;
												  true ->
													  []
											  end
									  end,
								  NGT = lists:keydelete(TNum, 2, GT),
								  NUT = lists:delete(TNum, UT),
								  case NGT =:= GT andalso NUT =:= UT of
									  true ->%%没变过，不用改数据库了
										  skip;
									  false ->
										  NUTStr = util:term_to_string(NUT),
										  NGTStr = util:term_to_string(NGT),
										  ValueList = [{ptitle, NUTStr}, {ptitles, NGTStr}],
										  db_mongo:update(player_other, ValueList, WhereList)
								  end
						  end
				  end, List),
	 db_mongo:delete(server_titles, []).

delete_td_single() ->
	List = db_mongo:select_all(td_single, "uid", [{uid, ">", 0}], [], []),
	if List == [] ->
		   skip;
	   true ->
		   F = fun(Uid) ->
					Res = db_mongo:select_one(player, "id", [{id, Uid}], [], []),  
					if Res == null ->
						   db_mongo:delete(td_single, [{uid, Uid}]), 
						   io:format("id == ~p~n is empty",[Uid]);
					   true ->
						   skip
					end
			   end,
		   [F(Uid) || [Uid]  <- List]
	end.
%% reload_guild_info(GuildId) ->
%% 	gen_server:cast(mod_guild:get_mod_guild_pid(), 
%% 					{apply_cast, lib_skyrush, reload_guild_info_inner, 
%% 					 [GuildId]}).
%% reload_guild_info_inner(GuildId) ->
%% 	%%删除氏族升级的记录
%% 	lib_guild_inner:delete_ets_guild_upgrade(GuildId),	
%% 	%%删除氏族技能信息表
%% 	lib_guild_inner:delete_guild_skills_attribute(GuildId),
%% 	%%删除氏族信息
%% 	lib_guild_inner:delete_guild(GuildId),
%% 	case db_mongo:select_all(guild, "*", [{id, GuildId}], [], [1]) of
%% 		[] ->
%% 			skip;
%% 		GuildStr ->
%% 			Guild = list_to_tuple([ets_guild] ++ GuildStr),
	
	
	
test() ->
	io:format("*q4444444444444*").
			 
pet_apt_reset()->
	apt_reset(),
	apt_reset2(),
	ok.

apt_reset()->
	PetIdBag = emongo:distinct(tool:to_list(?LOG_POOLID),tool:to_list(log_pet_aptitude),tool:to_list(petid)),
	io:format("PetIdBag>>~p~n",[PetIdBag]),
	if PetIdBag ==[]->skip;
	   true->
		   F = fun(Id)->
					   NewApt = db_mongo:select_one(?LOG_POOLID,log_pet_aptitude,"new", [{petid,Id}],[{id,desc}],[1]),
					   io:format("NewApt>>~p~n",[NewApt]),
					   if NewApt == null->skip;
						  true->
					    	db_mongo:update(pet, [{aptitude,NewApt}], [{id,Id}])
					   end
			   end,
		   [F(Id)||Id<-PetIdBag]
	end.

apt_reset2()->
	PetBag  = db_mongo:select_all(pet, "id,chenge",[{aptitude,">=",100}],[],[]),
	if PetBag ==[]->skip;
	   true->
		   F = fun([Id,Chenge])->
					   if Chenge == 2->skip;
						  Chenge == 1->
							  db_mongo:update(pet, [{aptitude,80}], [{id,Id}]);
						  true->
					    	db_mongo:update(pet, [{aptitude,60}], [{id,Id}])
					   end
			   end,
		   [F([Id,Chenge])||[Id,Chenge]<-PetBag]
	end,
	ok.

pet_apt_count()->
	PetBag  = db_mongo:select_all(pet, "player_id",[{aptitude,">=",60}],[],[]),
	NewPetBag = util:filter_replicat([PId||[PId]<-PetBag],[]), 
	if PetBag == []->skip;
	   true->
		   F = fun(PlayerId)->
					   NewApt = db_mongo:select_one(?LOG_POOLID,log_pet_aptitude,"new", [{pid,PlayerId}],[{new,asc}],[1]),
					   if NewApt == null ->skip;
						  true->
							  Msg = io_lib:format("玩家id：~p，灵兽资质：~p",[PlayerId,NewApt]),
							  {ok,S} = file:open("pet.txt",[append]),
							  io:format(S,"~s~n",[Msg]),
							  file:close(S)
					   end
			   end,
		   [F(PlayerId)||PlayerId<-NewPetBag]
	end,
	ok.

%%update hook config
update_hook_config()->
	HookConfBag = db_mongo:select_all(player_hook_setting, "player_id,hook_config",[],[],[]),
	if HookConfBag == []->skip;
	   true->
		   F = fun(PlayerId,Config)->
					   NewConfig = util:string_to_term(tool:to_list(Config)),
					   case length(NewConfig) =< 20 of
						   true->
							   NewConfig1 = NewConfig++[1],
							   db_mongo:update(player_hook_setting, [{hook_config,util:term_to_string(NewConfig1)}], [{player_id,PlayerId}]);
						   false->
%% 							   [0,[0,0,0,0,0], 0,0, [0,0,0,0], [0,0,0,0], 0,0,0,0,0,0,0,0,0,0,0,0,0,0,[0,0,0,0,0]]
								[_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,MatchData]= NewConfig,
								case erlang:is_list(MatchData) of
									false->skip;
									true->
										HookConfig1 = tuple_to_list(#hook_config{}),
										[_EtsKey | HookConfig2] = HookConfig1,
										NewHookConfig = util:term_to_string(HookConfig2),
										 db_mongo:update(player_hook_setting, [{hook_config,NewHookConfig}], [{player_id,PlayerId}])
								end
					   end
			   end,
		   [F(PlayerId,HookConfig)||[PlayerId,HookConfig]<-HookConfBag]
	end,
	ok.


update() ->
	Data = db_mongo:select_all(cards, "id,key",[],[],[]),
	if  Data == [] ->
			skip;
		true ->
			F = fun(Id,_Key) ->
						db_mongo:update(player_hook_setting, [{key,2}], [{id,Id}])
				end,
			[F(Id,Key)||[Id,Key]<-Data]
	end.

%%更新cmwebgamegm02帐号的角色数据，灵兽数据
batch_updata_gm_data(Accname) ->
	IdList = db_mongo:select_all(player, "id",[{accname,tool:to_list(Accname)}],[],[]), 
	if IdList == [] ->
		   io:format("No Gm data....."),
		   skip;
	   true ->
		   F = fun(Id) ->
					   db_mongo:update(player, [{lv,35}], [{id,Id}]),
					   PetIdList = db_mongo:select_all(pet, "id",[{player_id,Id}],[],[]), 
					   F1 = fun(PetId) ->
									db_mongo:update(pet, [{level,10},{grow,20},{aptitude,20},{goods_id,24619},{chenge,2}], [{id,PetId}])
							end,
					   [F1(PetId) || [PetId] <- PetIdList]					   
			   end,
		   [F(Id) || [Id] <- IdList]
	end.
	
%%统计一段时间的元宝消费情况
count_player_consume(Time1,Time2) -> 
	IdList = db_mongo:distinct(log_mongo,log_consume,"pid"),
	F = fun(Id) ->
				PitList = [1561,1571,2802,1575,1576,1577,1578,1579,1580,1581,1582,1584,1585,1586,1587,1588,1588,1605,1606,2503,4107,4108,4109,4106,1604,3315],
				Sum = ?DB_MODULE:sum(?LOG_POOLID,log_consume, "num", [{pid,Id},{type,"gold"},{ct,">",Time1},{ct,"<",Time2},{pit, "in", PitList}]),
				case db_mongo:select_one(player, "nickname", [{id,Id}], [],[1]) of
					null ->	[Id,<<>>,Sum];
					Nickname -> [Id,Nickname,Sum]
				end
		end,
	ResultList = [F(Id) || Id <- IdList],
	ResultList1 = [[NewId,NewNickname,NewSum] ||[NewId,NewNickname,NewSum] <- ResultList,NewSum >= 1000],
	io:format("ResultList1 length is ~p~n", [length(ResultList1)]),
	File = lists:concat(["../logs/consume",".txt"]),
			file:write_file(File, ""),
			file:write_file(File, ""),
			file:write_file(File, "角色Id========角色名=======消费数============\t\n",[append]),
			lists:foreach(fun([Player_Id,_Nickname,Num]) ->
					Bytes = io_lib:format("~p	      ~s	     ~p \t\n",[Player_Id,tool:to_list(_Nickname),Num]),
					file:write_file(File, Bytes,[append])			  
				  end, 
				  ResultList1).
get_player_buff_info(PlayerId) ->
	case lib_player:get_online_info_fields(PlayerId, [node, pid]) of
		[Node, Pid] ->
			io:format("Node :~p", [Node]),
			gen_server:cast(Pid, {cast, {union_to_emongo, get_buff_dict, []}});
		_ ->
			io:format("can not find the player")
	end.
get_buff_dict(_Player) ->
	R = lib_goods:get_player_goodsbuffs(),
	io:format("Buff :~p", [R]).
